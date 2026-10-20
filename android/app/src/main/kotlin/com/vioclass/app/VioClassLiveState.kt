package com.vioclass.app

/** Public channel state only; independent of Activities, Flutter and OAuth storage. */
internal object VioClassLiveState {
    // Twitch rejects a single query with more than 15 root field aliases.
    const val MAX_ROOT_FIELDS = 15

    fun batches(channels: List<String>): List<List<String>> =
        validLogins(channels).chunked(MAX_ROOT_FIELDS)

    fun configuredChannels(requested: List<String>, previous: Set<String>, sameOwner: Boolean, preparing: Boolean): Set<String> =
        if (preparing && sameOwner) previous.toSet() else validLogins(requested).toSet()

    fun newlyLive(previous: Set<String>?, current: Set<String>): Set<String> =
        if (previous == null) emptySet() else current - previous

    fun validLogins(channels: List<String>): List<String> = channels
        .map { it.lowercase() }.filter { it.matches(Regex("[a-z0-9_]{1,25}")) }
        .distinct().sorted()

    fun query(channels: List<String>): String = "query VioClassBackgroundLive { " +
        validLogins(channels).mapIndexed { index, login ->
            "u$index:user(login:\"$login\") { id login displayName profileImageURL(width:70) " +
                "stream { id title viewersCount createdAt language previewImageURL(width:440,height:248) " +
                "isMature game { id name } freeformTags { name } } }"
        }.joinToString(" ") + " }"
}
