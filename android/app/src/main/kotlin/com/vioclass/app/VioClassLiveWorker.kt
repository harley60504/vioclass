package com.vioclass.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.*
import org.json.JSONObject
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.CountDownLatch
import androidx.work.ListenableWorker.Result

/** Scheduled independently of the App task. Contains no OAuth token or cookie. */
class VioClassLiveWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    companion object {
        internal const val STORE = "vioclass_live_notifications"
        private const val WORK = "vioclass_followed_live"
        internal const val CHANNEL = "vioclass_followed_live"
        internal val lock = Any()
        private val checking = AtomicBoolean(false)
        private val gate = Any()
        private var finished = CountDownLatch(0)

        internal fun readSnapshot(context: Context, owner: String): String? = synchronized(lock) {
            val prefs = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
            if (prefs.getString("owner", null) != owner || !prefs.getBoolean("enabled", false)) return@synchronized null
            val age = System.currentTimeMillis() - prefs.getLong("snapshotAt", 0)
            if (age < 0 || age >= 60_000) return@synchronized null
            prefs.getString("snapshot", null)
        }

        internal fun requestSnapshot(context: Context, owner: String): String? {
            readSnapshot(context, owner)?.let { return it }
            synchronized(lock) {
                val prefs = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
                if (prefs.getString("owner", null) != owner || !prefs.getBoolean("enabled", false)) return null
            }
            runCheck(context, { false })
            val pending = synchronized(gate) { finished }
            if (!pending.await(95, TimeUnit.SECONDS)) return null
            return readSnapshot(context, owner)
        }

        /** Service and scheduled worker share a baseline and never race requests. */
        internal fun runCheck(context: Context, stopped: () -> Boolean, attempt: Int = 0): Result = runExclusive {
            VioClassLiveCheck(context, stopped, attempt).run()
        }

        internal fun runExclusive(check: () -> Result): Result {
            synchronized(gate) {
                if (!checking.compareAndSet(false, true)) return Result.success()
                finished = CountDownLatch(1)
            }
            return try {
                check()
            } finally {
                synchronized(gate) {
                    checking.set(false)
                    finished.countDown()
                }
            }
        }

        fun configure(context: Context, owner: String?, channels: List<String>, enabled: Boolean, clientId: String, preserveExisting: Boolean = false) {
            synchronized(lock) {
                val prefs = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
                val sameOwner = prefs.getString("owner", null) == owner
                val logins = VioClassLiveState.configuredChannels(channels,
                    prefs.getStringSet("channels", emptySet())!!, sameOwner, preserveExisting)
                val active = enabled && !owner.isNullOrBlank() && logins.isNotEmpty()
                if (!sameOwner || !active) {
                    val notifications = context.getSystemService(NotificationManager::class.java)
                    notifications.activeNotifications.filter { it.tag == "vioclass_live" }
                        .forEach { notifications.cancel(it.tag, it.id) }
                }
                val changed = !sameOwner || prefs.getStringSet("channels", emptySet()) != logins ||
                    prefs.getBoolean("enabled", false) != active || prefs.getString("clientId", "") != clientId
                if (changed) {
                    val editor = prefs.edit().putString("owner", owner).putStringSet("channels", logins)
                        .putBoolean("enabled", active).putString("clientId", clientId)
                        .putString("revision", UUID.randomUUID().toString())
                    // Any account/list/opt-in change gets a silent fresh baseline.
                    editor.remove("live")
                    editor.remove("snapshot").remove("snapshotAt")
                    check(editor.commit())
                }
                val manager = WorkManager.getInstance(context)
                if (active) {
                    manager.enqueueUniquePeriodicWork(WORK, ExistingPeriodicWorkPolicy.KEEP,
                        PeriodicWorkRequestBuilder<VioClassLiveWorker>(15, TimeUnit.MINUTES)
                            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES).build())
                } else {
                    manager.cancelUniqueWork(WORK)
                }
            }
        }
    }

    override fun doWork(): Result = runCheck(applicationContext, { isStopped }, runAttemptCount)
}

/** Same bounded public query for both fast receiving and periodic fallback. */
internal class VioClassLiveCheck(
    private val context: Context,
    private val stopped: () -> Boolean,
    private val attempt: Int,
) {
    fun run(): Result {
        val prefs = context.getSharedPreferences(VioClassLiveWorker.STORE, Context.MODE_PRIVATE)
        val revision: String
        val channels: List<String>
        val clientId: String
        synchronized(VioClassLiveWorker.lock) {
            if (!prefs.getBoolean("enabled", false)) return Result.success()
            val age = System.currentTimeMillis() - prefs.getLong("snapshotAt", 0)
            if (prefs.contains("snapshot") && age >= 0 && age < 60_000) return Result.success()
            revision = prefs.getString("revision", "")!!
            channels = prefs.getStringSet("channels", emptySet())!!.sorted()
            clientId = prefs.getString("clientId", "")!!
        }
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return Result.success()
        if (clientId.isBlank()) return Result.failure()
        var stage = "start"
        if (stopped()) return Result.success()
        Log.i("VioClassLiveCheck", "start channels=${channels.size} attempt=$attempt")
        try {
            val live = linkedMapOf<String, Pair<String, String>>()
            val streams = mutableListOf<JSONObject>()
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(90)
            for (batch in VioClassLiveState.batches(channels)) {
                if (stopped() || System.nanoTime() > deadline) {
                    Log.w("VioClassLiveCheck", "retry stage=deadline checked=${live.size}")
                    return Result.retry()
                }
                stage = "request"
                val connection = URL("https://gql.twitch.tv/gql").openConnection() as HttpURLConnection
                val response = try {
                    connection.requestMethod = "POST"
                    connection.connectTimeout = 8000
                    connection.readTimeout = 8000
                    connection.instanceFollowRedirects = false
                    connection.setRequestProperty("Client-ID", clientId)
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("Origin", "https://www.twitch.tv")
                    connection.doOutput = true
                    connection.outputStream.use {
                        it.write(JSONObject().put("query", VioClassLiveState.query(batch)).toString().toByteArray(Charsets.UTF_8))
                    }
                    if (connection.responseCode != 200) {
                        val raw = connection.errorStream?.bufferedReader()?.use { it.readText().take(4096) } ?: ""
                        var message = try {
                            val error = JSONObject(raw)
                            error.optString("message").ifBlank { error.optJSONArray("errors")?.optJSONObject(0)?.optString("message") ?: "" }
                        } catch (_: Exception) { "non_json_error" }
                        batch.forEach { login -> message = message.replace(Regex("(?i)\\b${Regex.escape(login)}\\b"), "<channel>") }
                        message = message.replace(Regex("[\\r\\n]"), " ").take(180)
                        Log.w("VioClassLiveCheck", "retry stage=http status=${connection.responseCode} detail=$message")
                        return Result.retry()
                    }
                    stage = "decode"
                    connection.inputStream.bufferedReader().use { JSONObject(it.readText()) }
                } finally { connection.disconnect() }
                if (response.optJSONArray("errors")?.length()?.let { it > 0 } == true) {
                    Log.w("VioClassLiveCheck", "retry stage=gql errors=${response.getJSONArray("errors").length()}")
                    return Result.retry()
                }
                stage = "snapshot"
                val data = response.getJSONObject("data")
                batch.forEachIndexed { index, login ->
                    // Missing keys are a partial/invalid response, never an offline snapshot.
                    check(data.has("u$index"))
                    val user = data.optJSONObject("u$index")
                    if (user != null) check(user.has("stream") && user.optString("login") == login)
                    val stream = user?.optJSONObject("stream")
                    if (stream != null) {
                        live[login] = Pair(user.optString("displayName", login), stream.optString("title"))
                        check(user.optString("id").isNotBlank())
                        val game = stream.optJSONObject("game")
                        val tags = JSONArray()
                        val freeform = stream.optJSONArray("freeformTags")
                        for (tag in 0 until (freeform?.length() ?: 0)) {
                            freeform?.optJSONObject(tag)?.optString("name")?.let { tags.put(it) }
                        }
                        streams.add(JSONObject()
                            .put("id", stream.getString("id")).put("user_id", user.getString("id"))
                            .put("user_login", login).put("user_name", user.optString("displayName", login))
                            .put("game_id", game?.optString("id") ?: "").put("game_name", game?.optString("name") ?: "")
                            .put("title", stream.optString("title")).put("viewer_count", stream.optInt("viewersCount"))
                            .put("started_at", stream.optString("createdAt")).put("language", stream.optString("language"))
                            .put("thumbnail_url", stream.optString("previewImageURL")).put("tags", tags)
                            .put("is_mature", stream.optBoolean("isMature"))
                            .put("profile_image_url", user.optString("profileImageURL")))
                    }
                }
            }
            synchronized(VioClassLiveWorker.lock) {
                if (stopped() || revision != prefs.getString("revision", null) || !prefs.getBoolean("enabled", false)) {
                    return Result.success()
                }
                val previous = if (prefs.contains("live")) prefs.getStringSet("live", emptySet()) else null
                val fresh = VioClassLiveState.newlyLive(previous, live.keys)
                stage = "notify"
                showLiveNotifications(fresh.mapNotNull { login -> live[login]?.let { Triple(login, it.first, it.second) } })
                val now = System.currentTimeMillis()
                val snapshot = JSONObject().put("owner", prefs.getString("owner", ""))
                    .put("revision", revision).put("updatedAt", now)
                    .put("streams", JSONArray(streams.sortedByDescending { it.optInt("viewer_count") }))
                check(prefs.edit().putStringSet("live", live.keys.toSet())
                    .putString("snapshot", snapshot.toString()).putLong("snapshotAt", now).commit())
                Log.i("VioClassLiveCheck", "success live=${live.size} new=${fresh.size} baseline=${previous == null}")
            }
            return Result.success()
        } catch (error: Exception) {
            // No token, network payload or account data is logged.
            Log.w("VioClassLiveCheck", "retry stage=$stage type=${error.javaClass.simpleName} cause=${error.cause?.javaClass?.simpleName}")
            return Result.retry()
        }
    }

    private fun showLiveNotifications(streams: List<Triple<String, String, String>>) {
        if (streams.isEmpty()) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (android.os.Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(VioClassLiveWorker.CHANNEL, "追隨頻道開台", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)!!
        val pending = PendingIntent.getActivity(context, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        if (streams.size > 3) {
            manager.notify("vioclass_live", 100, NotificationCompat.Builder(context, VioClassLiveWorker.CHANNEL)
                .setSmallIcon(R.drawable.vio_notification_icon).setContentTitle("${streams.size} 個追隨頻道開台了")
                .setContentText(streams.joinToString("、") { it.second }).setAutoCancel(true).setContentIntent(pending).build())
        } else streams.forEach { (login, name, title) ->
            manager.notify("vioclass_live", login.hashCode(), NotificationCompat.Builder(context, VioClassLiveWorker.CHANNEL)
                .setSmallIcon(R.drawable.vio_notification_icon).setContentTitle("$name 開台了")
                .setContentText(title).setAutoCancel(true).setContentIntent(pending).build())
        }
    }
}
