package com.example.new_twitch_app

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import io.flutter.plugin.common.MethodChannel

class TwitchPipBridge(
    private val activity: MainActivity,
) {
    private var channel: MethodChannel? = null

    fun attach(methodChannel: MethodChannel) {
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPipAvailable" -> result.success(isPipAvailable())
                "enterPip" -> {
                    val width = call.argument<Int>("aspectRatioWidth") ?: 16
                    val height = call.argument<Int>("aspectRatioHeight") ?: 9
                    result.success(enterPip(width, height))
                }
                else -> result.notImplemented()
            }
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    fun enterPipFromUserLeaveHint(): Boolean {
        return enterPip(16, 9)
    }

    fun notifyPipModeChanged(isInPip: Boolean) {
        channel?.invokeMethod(
            "onPipModeChanged",
            mapOf("isInPip" to isInPip),
        )
    }

    private fun isPipAvailable(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun enterPip(width: Int, height: Int): Boolean {
        if (!isPipAvailable()) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && activity.isInPictureInPictureMode) return true

        val safeWidth = width.coerceIn(1, 100)
        val safeHeight = height.coerceIn(1, 100)
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(safeWidth, safeHeight))
            .build()

        return activity.enterPictureInPictureMode(params)
    }
}
