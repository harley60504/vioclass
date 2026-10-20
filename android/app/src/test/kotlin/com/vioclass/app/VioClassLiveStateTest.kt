package com.vioclass.app

import org.junit.Assert.*
import org.junit.Test

class VioClassLiveStateTest {
    @Test fun reopeningSameAccountKeepsPersistedChannels() {
        assertEquals(setOf("a", "b"), VioClassLiveState.configuredChannels(
            emptyList(), setOf("a", "b"), true, true))
    }
    @Test fun logoutOrCompleteEmptyFollowsDoesNotKeepOldChannels() {
        assertTrue(VioClassLiveState.configuredChannels(emptyList(), setOf("a"), false, true).isEmpty())
        assertTrue(VioClassLiveState.configuredChannels(emptyList(), setOf("a"), true, false).isEmpty())
    }
    @Test fun manyFollowsStayBelowTwitchRootAliasLimit() {
        val channels = (0 until 126).map { "channel_$it" }
        val batches = VioClassLiveState.batches(channels)
        assertEquals(9, batches.size)
        assertTrue(batches.all { it.size <= 15 })
        assertEquals(channels.toSet(), batches.flatten().toSet())
        batches.forEach { batch ->
            val query = VioClassLiveState.query(batch)
            assertEquals(batch.size, query.split(":user(").size - 1)
        }
    }

    @Test fun initialSnapshotIsSilent() {
        assertTrue(VioClassLiveState.newlyLive(null, setOf("a", "b")).isEmpty())
    }
    @Test fun onlyOfflineToLiveIsNew() {
        assertEquals(setOf("b"), VioClassLiveState.newlyLive(setOf("a"), setOf("a", "b")))
        assertTrue(VioClassLiveState.newlyLive(setOf("a"), setOf("a")).isEmpty())
    }
    @Test fun emptyBaselineCanDetectNextLive() {
        assertEquals(setOf("a"), VioClassLiveState.newlyLive(emptySet(), setOf("a")))
        assertTrue(VioClassLiveState.newlyLive(setOf("a"), emptySet()).isEmpty())
    }
    @Test fun loginsAreSafeSortedAndUnique() {
        assertEquals(listOf("a", "b_1"), VioClassLiveState.validLogins(listOf("B_1", "a", "a", "x\") { bad", "")))
    }
    @Test fun queryDoesNotContainAuthorizationAndUsesStableAliases() {
        val query = VioClassLiveState.query(listOf("b", "a"))
        assertTrue(query.contains("u0:user(login:\"a\")"))
        assertTrue(query.contains("u1:user(login:\"b\")"))
        assertFalse(query.contains("token"))
        assertFalse(query.contains("sha256Hash"))
        assertTrue(query.contains("viewersCount"))
        assertTrue(query.contains("profileImageURL"))
        assertTrue(query.contains("previewImageURL"))
        assertTrue(query.contains("game { id name }"))
    }
}
