package com.esce.emoti

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

class ScreenCaptureService : Service() {

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        android.util.Log.e("ScreenCaptureService", "onStartCommand called with action: $action")

        if (action == "NOTIFY_STOP") {
            android.util.Log.e("ScreenCaptureChannel", "!!! Notification Stop Button Pressed (NOTIFY_STOP) !!!")
            val stopIntent = Intent("com.esce.emoti.STOP_SCREEN_SHARE")
            stopIntent.setPackage(packageName) // Ensure it only targets our app
            sendBroadcast(stopIntent)
            android.util.Log.e("ScreenCaptureChannel", "Broadcast com.esce.emoti.STOP_SCREEN_SHARE sent")
            return START_NOT_STICKY
        }

        if (action == "STOP") {
            android.util.Log.e("ScreenCaptureService", "Actual STOP requested from app. Cleaning up.")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        createNotificationChannel()

        val stopIntent = Intent(this, ScreenCaptureService::class.java).apply {
            this.action = "NOTIFY_STOP"
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ekran Paylaşımı")
            .setContentText("Ekranınız şu anda paylaşılıyor.")
            .setSmallIcon(R.mipmap.launcher_icon) 
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Paylaşımı Durdur", stopPendingIntent)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val type = if (action == "PROJECTION_READY") {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            }
            
            try {
                if (action == "PROJECTION_READY") {
                     android.util.Log.e("ScreenCaptureService", "Upgrading FGS to MEDIA_PROJECTION | MICROPHONE. Type=$type")
                } else {
                     android.util.Log.e("ScreenCaptureService", "Starting FGS as MICROPHONE. Type=$type")
                }
                
                ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
                android.util.Log.e("ScreenCaptureService", "startForeground success")
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    android.util.Log.e("ScreenCaptureService", "Verified FGS Type: ${getForegroundServiceType()}")
                }
            } catch (e: Exception) {
                android.util.Log.e("ScreenCaptureService", "startForeground FAILED: $e")
                e.printStackTrace()
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Screen Capture Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    companion object {
        const val CHANNEL_ID = "ScreenCaptureChannel"
        const val NOTIFICATION_ID = 12345
    }
}
