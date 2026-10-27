package com.vioclass.app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class VioClassPlaybackPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context: Context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "vio_class/playback_service").apply {
            setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "setActive" -> {
                            val intent = Intent(context, VioClassPlaybackService::class.java)
                                .putExtra("playing", call.argument<Boolean>("playing") == true)
                            call.argument<Map<String, Any?>>("media")?.let { media ->
                                intent.putExtra("media", Bundle().apply {
                                    for (key in listOf("id", "title", "artist", "artworkUrl"))
                                        putString(key, media[key] as? String ?: "")
                                    for (key in listOf("position", "duration"))
                                        putLong(key, (media[key] as? Number)?.toLong() ?: 0L)
                                    putFloat("rate", (media["rate"] as? Number)?.toFloat() ?: 1f)
                                    putBoolean("seekable", media["seekable"] == true)
                                    putBoolean("buffering", media["buffering"] == true)
                                })
                            }
                            if (call.argument<Boolean>("active") == true) {
                                if (VioClassPlaybackService.running) context.startService(intent)
                                else ContextCompat.startForegroundService(context, intent)
                            } else context.stopService(intent)
                            result.success(null)
                        }
                        "isRunning" -> result.success(VioClassPlaybackService.running)
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("playback_service_unavailable", error.javaClass.simpleName, null)
                }
            }
        }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.applicationContext.stopService(Intent(binding.applicationContext, VioClassPlaybackService::class.java))
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
