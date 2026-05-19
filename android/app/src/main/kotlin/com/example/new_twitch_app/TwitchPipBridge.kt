package com.example.new_twitch_app

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.graphics.Rect
import android.os.Build
import android.util.Rational
import io.flutter.plugin.common.MethodChannel

class TwitchPipBridge(
    private val activity: MainActivity,
) {
    private var channel: MethodChannel? = null
    private var sourceRectHint: Rect? = null

    fun attach(methodChannel: MethodChannel) {
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPipAvailable" -> result.success(isPipAvailable())
                "setSourceRectHint" -> {
                    val left = call.argument<Int>("left") ?: 0
                    val top = call.argument<Int>("top") ?: 0
                    val right = call.argument<Int>("right") ?: 0
                    val bottom = call.argument<Int>("bottom") ?: 0
                    setSourceRectHint(left, top, right, bottom)
                    result.success(null)
                }
                "enterPip" -> {
                    val width = call.argument<Int>("aspectRatioWidth") ?: 16
                    val height = call.argument<Int>("aspectRatioHeight") ?: 9
                    result.success(enterPip(width, height))
                }
                else -> result.notImplemented()
            }
        }

        updatePictureInPictureParams(16, 9)
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    fun enterPipFromUserLeaveHint(): Boolean {
        channel?.invokeMethod("onAutoPipRequested", null)
        return enterPip(16, 9)
    }

    fun notifyPipModeChanged(isInPip: Boolean) {
        channel?.invokeMethod(
            "onPipModeChanged",
            mapOf("isInPip" to isInPip),
        )
    }

    private fun setSourceRectHint(left: Int, top: Int, right: Int, bottom: Int) {
        if (right <= left || bottom <= top) return
        sourceRectHint = Rect(left, top, right, bottom)
        updatePictureInPictureParams(16, 9)
    }

    private fun isPipAvailable(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun enterPip(width: Int, height: Int): Boolean {
        if (!isPipAvailable()) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && activity.isInPictureInPictureMode) return true

        updatePictureInPictureParams(width, height)
        return activity.enterPictureInPictureMode(buildPictureInPictureParams(width, height))
    }

    private fun updatePictureInPictureParams(width: Int, height: Int) {
        if (!isPipAvailable()) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        activity.setPictureInPictureParams(buildPictureInPictureParams(width, height))
    }

    private fun buildPictureInPictureParams(width: Int, height: Int): PictureInPictureParams {
        val safeWidth = width.coerceIn(1, 100)
        val safeHeight = height.coerceIn(1, 100)
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(safeWidth, safeHeight))

        val hint = sourceRectHint
        if (hint != null) {
            builder.setSourceRectHint(hint)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(true)
        }

        return builder.build()
    }
}
