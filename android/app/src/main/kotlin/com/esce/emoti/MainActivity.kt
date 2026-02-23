package com.esce.emoti

import android.content.Intent
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import cl.puntito.simple_pip_mode.PipCallbackHelperActivityWrapper

class MainActivity: PipCallbackHelperActivityWrapper() {
    private val CHANNEL = "com.example.emotional/screen_share"
    private var methodChannel: MethodChannel? = null

    private val stopReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            android.util.Log.e("MainActivity", "Received broadcast action: ${intent?.action}")
            if (methodChannel == null) {
                android.util.Log.e("MainActivity", "ERROR: methodChannel is NULL, cannot notify Flutter")
            } else {
                when (intent?.action) {
                    "com.esce.emoti.STOP_SCREEN_SHARE" -> {
                        android.util.Log.e("MainActivity", "Invoking onStopPressed on MethodChannel")
                        methodChannel?.invokeMethod("onStopPressed", null)
                    }
                    "com.esce.emoti.LEAVE_ROOM" -> {
                        android.util.Log.e("MainActivity", "Invoking onLeaveRoomPressed on MethodChannel")
                        methodChannel?.invokeMethod("onLeaveRoomPressed", null)
                    }
                    "com.esce.emoti.TOGGLE_MUTE" -> {
                        android.util.Log.e("MainActivity", "Invoking onToggleMutePressed on MethodChannel")
                        methodChannel?.invokeMethod("onToggleMutePressed", null)
                    }
                }
            }
        }
    }

    private var isScreenSharingActive = false
    private var isVoiceCallActive = false


    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        val filter = IntentFilter().apply {
            addAction("com.esce.emoti.STOP_SCREEN_SHARE")
            addAction("com.esce.emoti.LEAVE_ROOM")
            addAction("com.esce.emoti.TOGGLE_MUTE")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(stopReceiver, filter)
        }

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    isScreenSharingActive = true
                    val action = call.argument<String>("action")
                    val intent = Intent(this, ScreenCaptureService::class.java)
                    if (action != null) {
                        intent.action = action
                    }
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopService" -> {
                    isScreenSharingActive = false
                    val intent = Intent(this, ScreenCaptureService::class.java)
                    intent.action = "STOP"
                    // Use startService (NOT startForegroundService) for STOP action
                    // to avoid creating a new FGS obligation that crashes on Android 8+
                    startService(intent)
                    result.success(null)
                }

                "startVoiceService" -> {
                    isVoiceCallActive = true
                    val intent = Intent(this, VoiceCallService::class.java).apply {
                        action = "START"
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopVoiceService" -> {
                    isVoiceCallActive = false
                    val intent = Intent(this, VoiceCallService::class.java).apply {
                        action = "STOP"
                    }
                    startService(intent)
                    result.success(null)
                }
                "isInPiPMode" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        result.success(isInPictureInPictureMode)
                    } else {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
