package com.sakinime.app

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.sukinime/pip"
    private var isPiPSupported = false
    private var methodChannel: MethodChannel? = null
    private var shouldEnterPiP = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        isPiPSupported = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        } else {
            false
        }

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPiP" -> {
                    shouldEnterPiP = true
                    val success = enterPiPModeNow()
                    result.success(success)
                }
                "enableAutoPiP" -> {
                    shouldEnterPiP = true
                    result.success(true)
                }
                "disableAutoPiP" -> {
                    shouldEnterPiP = false
                    result.success(true)
                }
                "isPiPSupported" -> {
                    result.success(isPiPSupported)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun enterPiPModeNow(): Boolean {
        if (!isPiPSupported) {
            return false
        }
        
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val aspectRatio = Rational(16, 9)
                val pipParams = PictureInPictureParams.Builder()
                    .setAspectRatio(aspectRatio)
                    .build()
                enterPictureInPictureMode(pipParams)
                true
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                @Suppress("DEPRECATION")
                enterPictureInPictureMode()
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (shouldEnterPiP) {
            enterPiPModeNow()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod(
            "onPiPModeChanged", 
            mapOf("isInPiP" to isInPictureInPictureMode)
        )
        if (!isInPictureInPictureMode) {
            shouldEnterPiP = false
        }
    }
}