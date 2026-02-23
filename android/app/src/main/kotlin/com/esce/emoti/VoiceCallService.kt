package com.esce.emoti

import com.esce.emoti.R


import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import android.app.PendingIntent

class VoiceCallService : Service() {

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        android.util.Log.d("VoiceCallService", "onStartCommand called with action: $action")

        if (action == "STOP") {
            android.util.Log.d("VoiceCallService", "Stopping VoiceCallService foreground.")
            // Safety: If started via startForegroundService, we MUST call startForeground
            // before stopping, otherwise Android 8+ crashes with RemoteServiceException.
            try {
                createNotificationChannel()
                val stopNotification = NotificationCompat.Builder(this, CHANNEL_ID)
                    .setContentTitle("Görüşme Durduruluyor")
                    .setSmallIcon(R.mipmap.launcher_icon)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .build()
                startForeground(NOTIFICATION_ID, stopNotification)
            } catch (e: Exception) {
                android.util.Log.e("VoiceCallService", "Safety startForeground failed: $e")
            }
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        createNotificationChannel()

        val intentLaunch = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntentLaunch = PendingIntent.getActivity(
            this, 0, intentLaunch,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Sesli Görüşme Aktif")
            .setContentText("Görüşme arka planda devam ediyor.")
            .setSmallIcon(R.mipmap.launcher_icon) 
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_CALL)
            .setContentIntent(pendingIntentLaunch)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val type = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            try {
                ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
                android.util.Log.d("VoiceCallService", "startForeground success with type MICROPHONE")
            } catch (e: Exception) {
                android.util.Log.e("VoiceCallService", "startForeground FAILED: $e")
                e.printStackTrace()
                // Fallback for older versions or if type fails
                startForeground(NOTIFICATION_ID, notification)
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        android.util.Log.d("VoiceCallService", "App removed from recents. Stopping voice service.")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }


    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Voice Call Service Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    companion object {
        const val CHANNEL_ID = "VoiceCallChannel"
        const val NOTIFICATION_ID = 54321
    }
}
