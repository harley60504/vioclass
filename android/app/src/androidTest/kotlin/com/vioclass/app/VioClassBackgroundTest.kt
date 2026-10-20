package com.vioclass.app

import android.content.Intent
import android.os.SystemClock
import androidx.core.content.ContextCompat
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.work.WorkManager
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.TimeUnit

/** Lifecycle/engine test only: does not send a whisper or use a real account. */
@RunWith(AndroidJUnit4::class)
class VioClassBackgroundTest {
    private fun waitUntil(label: String, condition: () -> Boolean) {
        val until = SystemClock.elapsedRealtime() + 10000
        while (!condition() && SystemClock.elapsedRealtime() < until) SystemClock.sleep(100)
        assertTrue(label, condition())
    }

    @Test fun receiverSurvivesTaskRemovalAndReusesEngineOnReopen() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val launch = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        instrumentation.uiAutomation.executeShellCommand(
            "pm grant ${context.packageName} android.permission.POST_NOTIFICATIONS"
        ).close()
        val activity = instrumentation.startActivitySync(launch) as MainActivity
        waitUntil("Flutter engine starts") { VioClassReceivingEngine.engine?.dartExecutor?.isExecutingDart == true }
        val engine = VioClassReceivingEngine.engine
        try {
            instrumentation.runOnMainSync {
                ContextCompat.startForegroundService(context, Intent(context, VioClassWhisperService::class.java))
            }
            waitUntil("Receiving service starts") { VioClassWhisperService.running }
            instrumentation.runOnMainSync { activity.finishAndRemoveTask() }
            waitUntil("Activity is destroyed") { activity.isDestroyed }
            assertTrue("Task removal must not stop receiving", VioClassWhisperService.running)
            assertSame(engine, VioClassReceivingEngine.engine)
            assertTrue("Dart still executes without its screen", engine!!.dartExecutor.isExecutingDart)
            val reopened = instrumentation.startActivitySync(launch) as MainActivity
            assertSame("Do not create another inbox on reopen", engine, VioClassReceivingEngine.engine)
            instrumentation.runOnMainSync {
                context.stopService(Intent(context, VioClassWhisperService::class.java))
            }
            waitUntil("Explicit opt-out stops receiving") { !VioClassWhisperService.running }
            instrumentation.runOnMainSync { reopened.finishAndRemoveTask() }
            waitUntil("No engine retained after opt-out") { VioClassReceivingEngine.engine == null }
        } finally {
            instrumentation.runOnMainSync { context.stopService(Intent(context, VioClassWhisperService::class.java)) }
        }
    }

    @Test fun liveScheduleCanBeCreatedWithoutAFlutterEngine() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val prefs = context.getSharedPreferences("vioclass_live_notifications", 0)
        val before = prefs.all.toMap()
        try {
            VioClassLiveWorker.configure(context, "instrumentation-fixture", listOf("monstercat"), true, "fixture-client-id")
            val jobs = WorkManager.getInstance(context).getWorkInfosForUniqueWork("vioclass_followed_live").get(10, TimeUnit.SECONDS)
            assertTrue(jobs.any { !it.state.isFinished })
            assertEquals(setOf("monstercat"), prefs.getStringSet("channels", emptySet()))
            VioClassLiveWorker.configure(context, null, emptyList(), false, "fixture-client-id")
            val cancelled = WorkManager.getInstance(context).getWorkInfosForUniqueWork("vioclass_followed_live").get(10, TimeUnit.SECONDS)
            assertTrue(cancelled.all { it.state.isFinished })
        } finally {
            val editor = prefs.edit().clear()
            before.forEach { (key, value) ->
                when (value) {
                    is String -> editor.putString(key, value)
                    is Boolean -> editor.putBoolean(key, value)
                    is Set<*> -> editor.putStringSet(key, value.filterIsInstance<String>().toSet())
                }
            }
            editor.commit()
            VioClassLiveWorker.configure(context, before["owner"] as? String,
                (before["channels"] as? Set<*>)?.filterIsInstance<String>() ?: emptyList(),
                before["enabled"] == true, before["clientId"] as? String ?: "")
        }
    }
}
