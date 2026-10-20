package com.vioclass.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

/** One UI/receiver engine is retained only while the user opted into receiving. */
internal object VioClassReceivingEngine {
    var engine: FlutterEngine? = null
    var host: MainActivity? = null
    fun releaseWithoutHost() {
        if (host == null) {
            val previous = engine
            engine = null
            previous?.destroy()
        }
    }
}

class VioClassWhisperService : Service() {
    companion object {
        @Volatile var running = false
        const val CHANNEL = "vioclass_whisper_receiving"
    }
    private var wakeLock: PowerManager.WakeLock? = null
    private var liveChecks: ScheduledExecutorService? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        try {
            val manager = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(
                CHANNEL, "私訊背景收件", NotificationManager.IMPORTANCE_LOW,
            ).apply { setShowBadge(false) })
            val launch = packageManager.getLaunchIntentForPackage(packageName)!!
            val notification = NotificationCompat.Builder(this, CHANNEL)
                .setSmallIcon(R.drawable.vio_notification_icon)
                .setContentTitle("VioClass 私訊收件中")
                .setContentText("滑掉 App 後仍接收私訊，可在 App 設定關閉。")
                .setOngoing(true).setSilent(true)
                .setContentIntent(PendingIntent.getActivity(this, 0, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                .build()
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else startForeground(1, notification)
            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "VioClass:WhisperReceiving")
                .apply { setReferenceCounted(false); acquire() }
            running = true
            liveChecks = Executors.newSingleThreadScheduledExecutor().also { executor ->
                executor.scheduleWithFixedDelay({
                    try {
                        VioClassLiveWorker.runCheck(applicationContext, { !running || Thread.currentThread().isInterrupted })
                    } catch (error: Exception) {
                        // A failed poll must not cancel future checks; no payloads logged.
                        Log.w("VioClassLiveCheck", "service retry type=${error.javaClass.simpleName}")
                    }
                }, 0, 60, TimeUnit.SECONDS)
            }
        } catch (error: Exception) {
            running = false
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // No blind restart with no authenticated Dart receiver after process death.
        if (VioClassReceivingEngine.engine == null) stopSelf()
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Closing a screen is not opting out of receiving. Do not stop the service.
    }

    override fun onDestroy() {
        running = false
        liveChecks?.shutdownNow()
        liveChecks = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        VioClassReceivingEngine.releaseWithoutHost()
        super.onDestroy()
    }
}
