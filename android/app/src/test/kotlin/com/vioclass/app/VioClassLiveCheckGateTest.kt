package com.vioclass.app

import androidx.work.ListenableWorker.Result
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class VioClassLiveCheckGateTest {
    @Test fun scheduledAndServiceChecksCannotOverlap() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val calls = AtomicInteger(0)
        val executor = Executors.newSingleThreadExecutor()
        try {
            val first = executor.submit<Result> {
                VioClassLiveWorker.runExclusive {
                    calls.incrementAndGet()
                    entered.countDown()
                    check(release.await(5, TimeUnit.SECONDS))
                    Result.success()
                }
            }
            assertTrue(entered.await(5, TimeUnit.SECONDS))
            VioClassLiveWorker.runExclusive {
                calls.incrementAndGet()
                Result.success()
            }
            assertEquals(1, calls.get())
            release.countDown()
            first.get(5, TimeUnit.SECONDS)
            VioClassLiveWorker.runExclusive {
                calls.incrementAndGet()
                Result.success()
            }
            assertEquals(2, calls.get())
        } finally {
            release.countDown()
            executor.shutdownNow()
        }
    }

    @Test fun thrownCheckReleasesGateForNextPoll() {
        try {
            VioClassLiveWorker.runExclusive { throw IllegalStateException("fixture") }
            fail("Expected fixture error")
        } catch (_: IllegalStateException) { }
        var ran = false
        VioClassLiveWorker.runExclusive {
            ran = true
            Result.success()
        }
        assertTrue(ran)
    }
}
