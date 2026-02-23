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

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.emotional/screen_share"
    private var methodChannel: MethodChannel? = null

    private val stopReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            android.util.Log.e("MainActivity", "Received STOP_SCREEN_SHARE broadcast action: ${intent?.action}")
            if (methodChannel == null) {
                android.util.Log.e("MainActivity", "ERROR: methodChannel is NULL, cannot notify Flutter")
            } else {
                android.util.Log.e("MainActivity", "Invoking onStopPressed on MethodChannel")
                methodChannel?.invokeMethod("onStopPressed", null)
            }
        }
    }

    private var isScreenSharingActive = false
    private var isVoiceCallActive = false


    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, IntentFilter("com.esce.emoti.STOP_SCREEN_SHARE"), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(stopReceiver, IntentFilter("com.esce.emoti.STOP_SCREEN_SHARE"))
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
                "enterPiP" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        val params = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            android.app.PictureInPictureParams.Builder().build()
                        } else {
                            null
                        }
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                enterPictureInPictureMode(params!!)
                            } else {
                                @Suppress("DEPRECATION")
                                enterPictureInPictureMode()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PIP_ERROR", e.message, null)
                        }
                    } else {
                        result.error("NOT_SUPPORTED", "PiP is not supported on this device", null)
                    }
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

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        val shouldEnterPiP = isScreenSharingActive || isVoiceCallActive
        
        if (shouldEnterPiP && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Check if device actually supports PiP before attempting
            if (!packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
                return
            }
            try {
                val builder = android.app.PictureInPictureParams.Builder()
                // Set a default aspect ratio if needed (e.g., 16:9 for screen share, 1:1 for headshot)
                // For now, use current window bounds or standard 16:9
                val aspectRatio = if (isScreenSharingActive) {
                    android.util.Rational(16, 9)
                } else {
                    android.util.Rational(1, 1) // Voice/Video call typically more square
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    builder.setAspectRatio(aspectRatio)
                    builder.setAutoEnterEnabled(true)
                } else {
                    builder.setAspectRatio(aspectRatio)
                }
                
                enterPictureInPictureMode(builder.build())
                android.util.Log.d("MainActivity", "Entered PiP mode successfully. ScreenShare=$isScreenSharingActive, Voice=$isVoiceCallActive")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Failed to enter PiP mode: $e")
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: android.content.res.Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod("onPiPModeChanged", isInPictureInPictureMode)
    }

}
