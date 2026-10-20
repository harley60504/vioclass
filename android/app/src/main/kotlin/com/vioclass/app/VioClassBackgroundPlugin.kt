package com.vioclass.app

import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Application-context bridge; survives Activity detachment without leaking it. */
class VioClassBackgroundPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null
    private val snapshots = Executors.newSingleThreadExecutor()
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "vio_class/background_receiving").apply {
            setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "startWhispers" -> {
                            if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
                                result.success(false)
                            } else {
                                ContextCompat.startForegroundService(context,
                                    Intent(context, VioClassWhisperService::class.java))
                                Handler(Looper.getMainLooper()).postDelayed({
                                    result.success(VioClassWhisperService.running)
                                }, 250)
                            }
                        }
                        "stopWhispers" -> {
                            context.stopService(Intent(context, VioClassWhisperService::class.java))
                            result.success(true)
                        }
                        "whispersRunning" -> result.success(VioClassWhisperService.running)
                        "followedLiveSnapshot" -> {
                            val owner = call.argument<String>("owner")
                            if (owner.isNullOrBlank()) result.success(null)
                            else snapshots.execute {
                                val snapshot = try {
                                    VioClassLiveWorker.requestSnapshot(context, owner)
                                } catch (_: Exception) { null }
                                Log.i("VioClassLiveCheck", "snapshot delivered=${snapshot != null}")
                                Handler(Looper.getMainLooper()).post { result.success(snapshot) }
                            }
                        }
                        "openReceivingNotificationSettings" -> {
                            if (Build.VERSION.SDK_INT < 26) {
                                result.success(false)
                            } else {
                                // Only create a missing channel; preserve user preferences.
                                val manager = context.getSystemService(NotificationManager::class.java)
                                if (manager.getNotificationChannel(VioClassWhisperService.CHANNEL) == null) {
                                    manager.createNotificationChannel(NotificationChannel(
                                        VioClassWhisperService.CHANNEL, "私訊背景收件",
                                        NotificationManager.IMPORTANCE_LOW,
                                    ).apply { setShowBadge(false) })
                                }
                                context.startActivity(Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                                    putExtra(Settings.EXTRA_CHANNEL_ID, VioClassWhisperService.CHANNEL)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                })
                                result.success(true)
                            }
                        }
                        "configureLive" -> {
                            val owner = call.argument<String>("owner")
                            val channels = call.argument<List<String>>("channels") ?: emptyList()
                            val enabled = call.argument<Boolean>("enabled") == true
                            val clientId = call.argument<String>("clientId") ?: ""
                            VioClassLiveWorker.configure(context, owner, channels, enabled, clientId,
                                call.argument<Boolean>("preserveExisting") == true)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("background_unavailable", "背景收件設定未完成。", null)
                }
            }
        }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        snapshots.shutdownNow()
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
