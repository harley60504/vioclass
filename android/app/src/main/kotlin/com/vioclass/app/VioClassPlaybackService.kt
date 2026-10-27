package com.vioclass.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.util.Log
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URI
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** Keeps user-requested playback eligible for Android background networking. */
class VioClassPlaybackService : Service() {
    companion object {
        @Volatile var running = false
        private const val CHANNEL = "vioclass_playback"
        const val STOP = "com.vioclass.app.STOP_PLAYBACK"
        const val PLAY = "com.vioclass.app.PLAY_PLAYBACK"
        const val PAUSE = "com.vioclass.app.PAUSE_PLAYBACK"
        const val REWIND = "com.vioclass.app.REWIND_PLAYBACK"
        const val FORWARD = "com.vioclass.app.FORWARD_PLAYBACK"
    }
    private lateinit var session: MediaSession
    private var playing = true
    private var media = Bundle()
    private var artwork: Bitmap? = null
    private var fallbackArtwork: Bitmap? = null
    private var artworkUrl = ""
    private val artworkExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var destroyed = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(
            CHANNEL, getString(R.string.playback_channel), NotificationManager.IMPORTANCE_LOW,
        ).apply { setShowBadge(false) })
        session = MediaSession(this, "VioClassPlayback").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    ContextCompat.startForegroundService(this@VioClassPlaybackService,
                        Intent(this@VioClassPlaybackService, VioClassPlaybackService::class.java).setAction(PLAY))
                }
                override fun onPause() = dispatch("pausePlayback")
                override fun onStop() = stopPlayback()
                override fun onSeekTo(pos: Long) {
                    seek(pos)
                }
                override fun onRewind() = seekBy(-10000L)
                override fun onFastForward() = seekBy(10000L)
                override fun onCustomAction(action: String, extras: Bundle?) {
                    if (action == REWIND) seekBy(-10000L)
                    if (action == FORWARD) seekBy(10000L)
                }
            })
            setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS)
            isActive = true
        }
        val icon = applicationInfo.loadIcon(packageManager)
        artwork = Bitmap.createBitmap(256, 256, Bitmap.Config.ARGB_8888).also {
            icon.setBounds(0, 0, 256, 256)
            icon.draw(Canvas(it))
        }
        fallbackArtwork = artwork
        updatePlayback(true)
        running = true
        Log.i("VioClassPlayback", "foreground playback started")
    }

    private fun action(action: String, code: Int): PendingIntent {
        val intent = Intent(this, VioClassPlaybackService::class.java).setAction(action)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return if (action == PLAY && Build.VERSION.SDK_INT >= 26)
            PendingIntent.getForegroundService(this, code, intent, flags)
        else PendingIntent.getService(this, code, intent, flags)
    }

    private fun updatePlayback(value: Boolean) {
        playing = value
        val seekable = media.getBoolean("seekable") && media.getLong("duration") > 0
        val buffering = media.getBoolean("buffering")
        val metadata = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, media.getString("title").orEmpty().ifBlank { "VioClass" })
            .putString(MediaMetadata.METADATA_KEY_ARTIST, media.getString("artist").orEmpty())
            .putString(MediaMetadata.METADATA_KEY_MEDIA_ID, media.getString("id").orEmpty())
        if (seekable) metadata.putLong(MediaMetadata.METADATA_KEY_DURATION, media.getLong("duration"))
        artwork?.let {
            metadata.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, it)
                .putBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON, it)
        }
        session.setMetadata(metadata.build())
        val state = PlaybackState.Builder()
            .setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or
                PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_STOP or
                (if (seekable) PlaybackState.ACTION_SEEK_TO or PlaybackState.ACTION_REWIND or
                    PlaybackState.ACTION_FAST_FORWARD else 0L))
            .setState(if (!playing) PlaybackState.STATE_PAUSED
                else if (buffering) PlaybackState.STATE_BUFFERING else PlaybackState.STATE_PLAYING,
                if (seekable) media.getLong("position").coerceIn(0L, media.getLong("duration"))
                else PlaybackState.PLAYBACK_POSITION_UNKNOWN,
                if (playing && !buffering) media.getFloat("rate", 1f) else 0f)
        if (seekable) {
            state.addCustomAction(REWIND, getString(R.string.playback_rewind), android.R.drawable.ic_media_rew)
            state.addCustomAction(FORWARD, getString(R.string.playback_forward), android.R.drawable.ic_media_ff)
        }
        session.setPlaybackState(state.build())
        val launch = packageManager.getLaunchIntentForPackage(packageName)!!
        session.setSessionActivity(PendingIntent.getActivity(this, 70, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
            else Notification.Builder(this)
        if (Build.VERSION.SDK_INT >= 26) builder.setColorized(true)
        builder
            .setSmallIcon(R.drawable.vio_notification_icon)
            .setLargeIcon(artwork)
            .setColor(0xFF8866DD.toInt())
            .setContentTitle(media.getString("title").orEmpty().ifBlank { "VioClass" })
            .setContentText(media.getString("artist").orEmpty().ifBlank {
                getString(if (playing) R.string.playback_active else R.string.playback_paused) })
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setOngoing(playing).setOnlyAlertOnce(true)
            .setStyle(Notification.MediaStyle().setMediaSession(session.sessionToken)
                .setShowActionsInCompactView(*(if (seekable) intArrayOf(0, 1, 2) else intArrayOf(0))))
            .setContentIntent(PendingIntent.getActivity(this, 70, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        if (seekable) builder.addAction(Notification.Action.Builder(android.R.drawable.ic_media_rew,
            getString(R.string.playback_rewind), action(REWIND, 73)).build())
        builder.addAction(Notification.Action.Builder(
                if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                getString(if (playing) R.string.playback_pause else R.string.playback_play),
                action(if (playing) PAUSE else PLAY, 72)).build())
        if (seekable) builder.addAction(Notification.Action.Builder(android.R.drawable.ic_media_ff,
            getString(R.string.playback_forward), action(FORWARD, 74)).build())
        val notification = builder.addAction(Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel,
                getString(R.string.playback_stop), action(STOP, 71)).build())
            .build()
        if (playing) {
            if (Build.VERSION.SDK_INT >= 29) startForeground(71, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            else startForeground(71, notification)
        } else {
            stopForeground(STOP_FOREGROUND_DETACH)
            getSystemService(NotificationManager::class.java).notify(71, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getBundleExtra("media")?.let {
            media = it
            loadArtwork(it.getString("artworkUrl").orEmpty())
        }
        when {
            intent?.action == STOP || VioClassReceivingEngine.engine == null -> stopPlayback()
            intent?.action == PLAY -> { updatePlayback(true); dispatch("playPlayback") }
            intent?.action == PAUSE -> dispatch("pausePlayback")
            intent?.action == REWIND -> seekBy(-10000L)
            intent?.action == FORWARD -> seekBy(10000L)
            else -> updatePlayback(intent?.getBooleanExtra("playing", true) ?: true)
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) = stopPlayback()

    private fun stopPlayback() {
        dispatch("stopPlayback")
        stopSelf()
    }

    private fun seek(pos: Long) {
        val duration = media.getLong("duration")
        if (!media.getBoolean("seekable") || duration <= 0) return
        val target = pos.coerceIn(0L, duration)
        dispatch("seekPlayback", mapOf("id" to media.getString("id"), "position" to target))
    }

    private fun seekBy(delta: Long) {
        val state = session.controller.playbackState
        val elapsed = if (playing && !media.getBoolean("buffering") && state != null)
            ((android.os.SystemClock.elapsedRealtime() - state.lastPositionUpdateTime) * state.playbackSpeed).toLong()
            else 0L
        seek(media.getLong("position") + elapsed + delta)
    }

    private fun dispatch(method: String, arguments: Any? = null) {
        VioClassReceivingEngine.engine?.let {
            MethodChannel(it.dartExecutor.binaryMessenger, "vio_class/playback_service")
                .invokeMethod(method, arguments)
        }
    }

    override fun onDestroy() {
        destroyed = true
        artworkExecutor.shutdownNow()
        running = false
        session.release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        getSystemService(NotificationManager::class.java).cancel(71)
        VioClassReceivingEngine.releaseWithoutHost()
        Log.i("VioClassPlayback", "foreground playback stopped")
        super.onDestroy()
    }

    /** Artwork is public Twitch CDN content; no credentials are sent. */
    private fun loadArtwork(url: String) {
        if (url == artworkUrl) return
        artworkUrl = url
        artwork = fallbackArtwork
        val uri = runCatching { URI(url) }.getOrNull() ?: return
        val host = uri.host ?: return
        if (uri.scheme != "https" || !(host.endsWith(".jtvnw.net") ||
                host.endsWith(".twitchcdn.net"))) return
        artworkExecutor.execute {
            val bitmap = runCatching {
                val connection = uri.toURL().openConnection() as HttpURLConnection
                try {
                    connection.connectTimeout = 4000
                    connection.readTimeout = 4000
                    connection.instanceFollowRedirects = false
                    if (connection.responseCode != 200) return@runCatching null
                    val bytes = connection.inputStream.use { input ->
                        val output = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (output.size() <= 2 * 1024 * 1024) {
                            val count = input.read(buffer, 0,
                                minOf(buffer.size, 2 * 1024 * 1024 + 1 - output.size()))
                            if (count < 0) break
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    }
                    if (bytes.size > 2 * 1024 * 1024) return@runCatching null
                    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                    var sample = 1
                    while (bounds.outWidth / sample > 512 || bounds.outHeight / sample > 512) sample *= 2
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
                        BitmapFactory.Options().apply { inSampleSize = sample })
                } finally { connection.disconnect() }
            }.getOrNull()
            mainHandler.post {
                if (!destroyed && artworkUrl == url && bitmap != null) {
                    artwork = bitmap
                    updatePlayback(playing)
                }
            }
        }
    }
}
