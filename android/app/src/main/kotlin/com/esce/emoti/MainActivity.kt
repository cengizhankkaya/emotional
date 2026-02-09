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
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
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
        if (isScreenSharingActive && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = android.app.PictureInPictureParams.Builder().build()
            enterPictureInPictureMode(params)
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: android.content.res.Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod("onPiPModeChanged", isInPictureInPictureMode)
    }

}
