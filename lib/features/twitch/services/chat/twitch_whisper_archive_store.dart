import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../models/chat/twitch_whisper_conversation.dart';
import '../../models/chat/twitch_whisper_remote_history.dart';
import '../../models/chat/twitch_whisper_recovery_checkpoint.dart';

/// Inject persistence so storage can be tested without platform plugins.
/// Contains private message history, never OAuth credentials.
class TwitchWhisperArchiveStore {
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final int maxBackupBytes;
  Future<void> _queue = Future<void>.value();
  final Set<String> _loadedOwners = {};
  String? _cachedOwner;
  String? _cachedRaw;
  List<TwitchWhisperConversation>? _cachedConversations;

  List<TwitchWhisperConversation> _remember(
    String owner,
    String raw,
    List<TwitchWhisperConversation> conversations,
  ) {
    _cachedOwner = owner;
    _cachedRaw = raw;
    _cachedConversations = List.unmodifiable(conversations);
    return _cachedConversations!;
  }

  TwitchWhisperArchiveStore({
    required this.read,
    required this.write,
    this.maxBackupBytes = 32 * 1024 * 1024,
  }) {
    if (maxBackupBytes <= 0) {
      throw ArgumentError.value(maxBackupBytes, 'maxBackupBytes');
    }
  }

  void _checkBackupCapacity(String raw) {
    if (raw.length > maxBackupBytes ||
        utf8.encode(raw).length > maxBackupBytes) {
      throw TwitchWhisperArchiveException(
        '私訊備份超過 $maxBackupBytes 位元組的 UTF-8 容量上限；原本歷史已保留。',
      );
    }
  }

  // Observation identity is independent of wall-clock changes. This is not a
  // credential, message ID, or encryption key.
  static String newReceiveGapObservationId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _key(String ownerId) {
    if (!RegExp(r'^\d+$').hasMatch(ownerId)) {
      throw ArgumentError.value(
        ownerId,
        'ownerId',
        'Expected a Twitch user ID',
      );
    }
    return 'vioclass_twitch_whispers_v1_$ownerId';
  }

  Future<List<TwitchWhisperConversation>> load(String ownerId) =>
      _serialized(() => _load(ownerId));

  Future<List<TwitchWhisperConversation>> _load(String ownerId) async {
    final raw = await read(_key(ownerId));
    if (raw == null) {
      _cachedOwner = null;
      _cachedRaw = null;
      _cachedConversations = null;
      _loadedOwners.add(ownerId);
      return const [];
    }
    // Always read the source first. Cache only a validated, immutable snapshot,
    // and retain at most one owner so account switching cannot grow this cache.
    if (_loadedOwners.contains(ownerId) &&
        _cachedOwner == ownerId &&
        _cachedRaw == raw &&
        _cachedConversations != null) {
      return _cachedConversations!;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1 || json['ownerId'] != ownerId) {
        throw const FormatException(
          'Unsupported or mismatched whisper archive',
        );
      }
      final cursor = json['remoteThreadsCursor'];
      final complete = json['remoteThreadsComplete'];
      final gap = json['receiveGapSince'];
      final observed = json['receiveGapObservedAt'];
      final observationId = json['receiveGapObservationId'];
      if (observationId != null &&
          (observationId is! String ||
              !RegExp(r'^[0-9a-f]{32}$').hasMatch(observationId))) {
        throw const FormatException('Invalid receive gap observation identity');
      }
      if (observed != null &&
          (observed is! String ||
              DateTime.tryParse(observed)?.toUtc().toIso8601String() !=
                  observed)) {
        throw const FormatException('Invalid receive gap observation');
      }
      final sessionStarted = json['receiveSessionStartedAt'];
      if (sessionStarted != null &&
          (sessionStarted is! String ||
              DateTime.tryParse(sessionStarted)?.toUtc().toIso8601String() !=
                  sessionStarted)) {
        throw const FormatException('Invalid receive session checkpoint');
      }
      final recovery = json['receiveRecovery'];
      if (recovery != null) {
        final checkpoint = TwitchWhisperRecoveryCheckpoint.fromJson(
          Map<String, dynamic>.from(recovery as Map),
        );
        if (checkpoint.peerIds.contains(ownerId)) {
          throw const FormatException('Recovery contains its owner');
        }
      }
      if (gap != null &&
          (gap is! String ||
              DateTime.tryParse(gap)?.toUtc().toIso8601String() != gap)) {
        throw const FormatException('Invalid receive gap checkpoint');
      }
      if ((cursor != null &&
              (cursor is! String || cursor.isEmpty || cursor.length > 4096)) ||
          (complete != null && complete is! bool) ||
          (complete == true && cursor != null)) {
        throw const FormatException('Invalid remote inbox checkpoint');
      }
      final conversations = (json['conversations'] as List)
          .map(
            (item) => TwitchWhisperConversation.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      _validate(ownerId, conversations);
      // Recover interrupted requests once per session, not on every draft save.
      if (!_loadedOwners.contains(ownerId)) {
        final recovered = List<TwitchWhisperConversation>.unmodifiable(
          conversations.map(
            (conversation) => conversation.copyWith(
              messages: conversation.messages.map(
                (message) => message.state == TwitchWhisperMessageState.sending
                    ? message.copyWith(
                        state: TwitchWhisperMessageState.unconfirmed,
                      )
                    : message,
              ),
            ),
          ),
        );
        final interrupted = conversations.any(
          (peer) => peer.messages.any(
            (message) => message.state == TwitchWhisperMessageState.sending,
          ),
        );
        if (interrupted) {
          await _save(ownerId, recovered);
        }
        // Only finish recovery after its checkpoint is safely written. A failed
        // write must not allow the next load to expose stale sending records.
        _loadedOwners.add(ownerId);
        return interrupted ? recovered : _remember(ownerId, raw, recovered);
      }
      return _remember(ownerId, raw, conversations);
    } catch (_) {
      // Do not overwrite an unreadable archive with an empty one.
      throw const TwitchWhisperArchiveException(
        'Private message history could not be read. Original data was preserved.',
      );
    }
  }

  void _validate(
    String ownerId,
    Iterable<TwitchWhisperConversation> conversations,
  ) {
    final peers = <String>{};
    for (final conversation in conversations) {
      if (!RegExp(r'^\d+$').hasMatch(conversation.userId) ||
          conversation.userId == ownerId ||
          !peers.add(conversation.userId)) {
        throw const FormatException('Invalid whisper peer');
      }
      for (final message in conversation.messages) {
        final incoming =
            message.fromUserId == conversation.userId &&
            message.toUserId == ownerId;
        final outgoing =
            message.fromUserId == ownerId &&
            message.toUserId == conversation.userId;
        if (!incoming && !outgoing) {
          throw const FormatException('Whisper belongs to another account');
        }
      }
    }
  }

  Future<void> _save(
    String ownerId,
    List<TwitchWhisperConversation> conversations, {
    String? remoteThreadsCursor,
    bool? remoteThreadsComplete,
    DateTime? receiveGapSince,
    DateTime? receiveGapObservedAt,
    String? receiveGapObservationId,
    DateTime? receiveSessionStartedAt,
    TwitchWhisperRecoveryCheckpoint? receiveRecovery,
  }) async {
    _validate(ownerId, conversations);
    final previous = await read(_key(ownerId));
    final metadata = previous == null
        ? <String, dynamic>{}
        : jsonDecode(previous) as Map<String, dynamic>;
    await write(
      _key(ownerId),
      jsonEncode({
        'version': 1,
        'ownerId': ownerId,
        'conversations': conversations.map((c) => c.toJson()).toList(),
        'remoteThreadsCursor': remoteThreadsComplete == null
            ? metadata['remoteThreadsCursor']
            : remoteThreadsCursor,
        'remoteThreadsComplete':
            remoteThreadsComplete ?? metadata['remoteThreadsComplete'] ?? false,
        'receiveGapSince':
            receiveGapSince?.toUtc().toIso8601String() ??
            metadata['receiveGapSince'],
        'receiveGapObservedAt':
            receiveGapObservedAt?.toUtc().toIso8601String() ??
            metadata['receiveGapObservedAt'],
        'receiveGapObservationId':
            receiveGapObservationId ?? metadata['receiveGapObservationId'],
        'receiveRecovery':
            receiveRecovery?.toJson() ?? metadata['receiveRecovery'],
        'receiveSessionStartedAt':
            receiveSessionStartedAt?.toUtc().toIso8601String() ??
            metadata['receiveSessionStartedAt'],
      }),
    );
  }

  TwitchWhisperRecoveryCheckpoint? _recovery(Map metadata) {
    final raw = metadata['receiveRecovery'];
    return raw == null
        ? null
        : TwitchWhisperRecoveryCheckpoint.fromJson(
            Map<String, dynamic>.from(raw as Map),
          );
  }

  void _checkRecovery(Map metadata, TwitchWhisperRecoveryCheckpoint expected) {
    if (jsonEncode(_recovery(metadata)?.toJson()) !=
        jsonEncode(expected.toJson())) {
      throw const FormatException('Stale whisper recovery work');
    }
  }

  Future<TwitchWhisperRecoveryCheckpoint?> recoveryCheckpoint(String ownerId) =>
      _serialized(() async {
        await _load(ownerId);
        final raw = await read(_key(ownerId));
        return raw == null ? null : _recovery(jsonDecode(raw) as Map);
      });

  Future<TwitchWhisperRecoveryCheckpoint> beginRecovery(
    String ownerId, {
    bool Function()? canApply,
  }) => _serialized(() async {
    final conversations = await _load(ownerId);
    final raw = await read(_key(ownerId));
    final metadata = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map;
    final existing = _recovery(metadata);
    final observedRaw = metadata['receiveGapObservedAt'];
    final observed = observedRaw == null
        ? null
        : DateTime.parse(observedRaw as String);
    if (existing != null &&
        !existing.complete &&
        existing.gapObservationId == metadata['receiveGapObservationId'] &&
        existing.gapObservedAt == observed) {
      return existing;
    }
    final gap = metadata['receiveGapSince'];
    final work = TwitchWhisperRecoveryCheckpoint(
      since: gap == null ? DateTime.utc(1970) : DateTime.parse(gap as String),
      gapObservedAt: observed,
      gapObservationId: metadata['receiveGapObservationId'] as String?,
      phase: 'threads',
      peerIds: conversations.map((p) => p.userId),
    );
    if (canApply?.call() != false) {
      await _save(ownerId, conversations, receiveRecovery: work);
    }
    return work;
  });

  /// A new observed interruption requires a fresh enumeration, not continuation
  /// past peers/pages that were read before that interruption.
  Future<bool> recoveryNeedsRestart(
    String ownerId,
    TwitchWhisperRecoveryCheckpoint work,
  ) => _serialized(() async {
    await _load(ownerId);
    final raw = await read(_key(ownerId));
    final metadata = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map;
    return work.gapObservedAt?.toUtc().toIso8601String() !=
            metadata['receiveGapObservedAt'] ||
        work.gapObservationId != metadata['receiveGapObservationId'];
  });

  /// Start a new app/account receiving lifetime. The previous lifetime's start
  /// is a conservative lower bound for offline uncertainty, not a last-message
  /// receipt or evidence that any specific message was missed.
  Future<DateTime?> beginReceiveSession(
    String ownerId,
    DateTime startedAt, {
    bool Function()? canApply,
  }) => _serialized(() async {
    final conversations = await _load(ownerId);
    final raw = await read(_key(ownerId));
    final metadata = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map;
    final priorRaw = metadata['receiveSessionStartedAt'];
    final gapRaw = metadata['receiveGapSince'];
    final previous = priorRaw == null
        ? null
        : DateTime.parse(priorRaw as String);
    var gap = gapRaw == null ? null : DateTime.parse(gapRaw as String);
    if (previous != null && (gap == null || previous.isBefore(gap))) {
      gap = previous;
    }
    if (canApply?.call() != false) {
      await _save(
        ownerId,
        conversations,
        receiveGapSince: gap,
        receiveGapObservedAt: previous == null ? null : startedAt,
        receiveGapObservationId: previous == null
            ? null
            : newReceiveGapObservationId(),
        receiveSessionStartedAt: startedAt,
      );
    }
    return gap;
  });

  Future<DateTime?> receiveGapSince(String ownerId) => _serialized(() async {
    await _load(ownerId);
    final raw = await read(_key(ownerId));
    if (raw == null) return null;
    final value = (jsonDecode(raw) as Map)['receiveGapSince'];
    return value == null ? null : DateTime.parse(value as String);
  });

  /// Retain the earliest unfinished gap. No single history page clears it.
  Future<bool> recordReceiveGap(
    String ownerId,
    DateTime since, {
    DateTime? observedAt,
    String? observationId,
    bool Function()? canApply,
  }) => _serialized(() async {
    if (observationId != null &&
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(observationId)) {
      throw const FormatException('Invalid receive gap observation identity');
    }
    final conversations = await _load(ownerId);
    if (canApply?.call() == false) return false;
    final raw = await read(_key(ownerId));
    final metadata = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map;
    final value = metadata['receiveGapSince'];
    final prior = value == null ? null : DateTime.parse(value as String);
    final observedRaw = metadata['receiveGapObservedAt'];
    final previousObservation = observedRaw == null
        ? null
        : DateTime.parse(observedRaw as String);
    final observation = (observedAt ?? since).toUtc();
    final newerObservation = observationId != null
        ? observationId != metadata['receiveGapObservationId']
        : previousObservation == null ||
              observation.isAfter(previousObservation);
    final earlierGap = prior == null || since.isBefore(prior);
    if (!earlierGap && !newerObservation) return true;
    await _save(
      ownerId,
      conversations,
      receiveGapSince: earlierGap ? since : prior,
      receiveGapObservedAt: newerObservation
          ? observation
          : previousObservation,
      receiveGapObservationId: newerObservation ? observationId : null,
    );
    return true;
  });

  Future<({String? cursor, bool complete})> threadsCheckpoint(String ownerId) =>
      _serialized(() async {
        await _load(ownerId);
        final raw = await read(_key(ownerId));
        if (raw == null) return (cursor: null, complete: false);
        final json = jsonDecode(raw) as Map;
        return (
          cursor: json['remoteThreadsCursor'] as String?,
          complete: json['remoteThreadsComplete'] == true,
        );
      });

  void _checkRemoteAccountCapacity(
    List<TwitchWhisperConversation> conversations,
  ) {
    if (conversations.length > 500 ||
        utf8
                .encode(
                  jsonEncode(
                    conversations.map((peer) => peer.toJson()).toList(),
                  ),
                )
                .length >
            20 * 1024 * 1024) {
      throw const TwitchWhisperArchiveException(
        '帳號對話超過五百個或二十 MiB 上限，原資料與同步進度已保留。',
      );
    }
  }

  /// Merge inbox discovery and its checkpoint in one write. An empty remote page
  /// never deletes local conversations or marks local unread messages as read.
  Future<List<TwitchWhisperConversation>> mergeThreadsPage(
    String ownerId,
    TwitchWhisperThreadsPage page, {
    bool Function()? canApply,
    bool refreshOnly = false,
    DateTime? requestedAt,
    TwitchWhisperRecoveryCheckpoint? recovery,
  }) => _serialized(() async {
    if (page.ownerId != ownerId) {
      throw const FormatException('Foreign remote inbox');
    }
    final current = (await _load(ownerId)).toList();
    if (canApply?.call() == false) return List.unmodifiable(current);
    final raw = await read(_key(ownerId));
    final metadata = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    if (recovery != null) {
      _checkRecovery(metadata, recovery);
      if ({
            ...recovery.peerIds,
            ...page.conversations.map((peer) => peer.userId),
          }.length >
          500) {
        throw const TwitchWhisperArchiveException('恢復對話超過五百個上限，原資料與同步進度已保留。');
      }
    }
    final nextRecovery = recovery?.afterThreads(page);
    if (recovery == null &&
        page.requestedCursor != null &&
        page.requestedCursor != metadata['remoteThreadsCursor']) {
      throw const FormatException('Stale remote inbox cursor');
    }
    final peers = <String>{};
    for (final remote in page.conversations) {
      if (!peers.add(remote.userId)) {
        throw const FormatException('Duplicate remote peer');
      }
      _validate(ownerId, [remote]);
      final index = current.indexWhere((peer) => peer.userId == remote.userId);
      final existing = index < 0
          ? remote.copyWith(messages: const [])
          : current[index];
      final messages = {
        for (final message in existing.messages) message.id: message,
      };
      for (final message in remote.messages) {
        final prior = messages[message.id];
        if (prior != null &&
            (prior.fromUserId != message.fromUserId ||
                prior.toUserId != message.toUserId ||
                prior.text != message.text)) {
          throw const FormatException('Conflicting inbox message');
        }
        messages.putIfAbsent(
          message.id,
          () => message.copyWith(historicalOnly: true),
        );
      }
      final merged = existing.copyWith(
        login:
            requestedAt != null &&
                existing.profileObservedAt?.isAfter(requestedAt) == true
            ? existing.login
            : remote.login,
        displayName:
            requestedAt != null &&
                existing.profileObservedAt?.isAfter(requestedAt) == true
            ? existing.displayName
            : remote.displayName,
        avatarUrl:
            requestedAt != null &&
                existing.profileObservedAt?.isAfter(requestedAt) == true
            ? existing.avatarUrl
            : remote.avatarUrl,
        replaceAvatar: true,
        remoteUnreadCount: remote.remoteUnreadCount,
        messages: messages.values,
      );
      if (merged.messages.length > 10000 ||
          utf8.encode(jsonEncode(merged.toJson())).length > 4 * 1024 * 1024) {
        throw const TwitchWhisperArchiveException('遠端對話超過保存上限，原資料已保留。');
      }
      if (index < 0) {
        current.add(merged);
      } else {
        current[index] = merged;
      }
    }
    _checkRemoteAccountCapacity(current);
    if (canApply?.call() != false) {
      await _save(
        ownerId,
        current,
        remoteThreadsCursor: refreshOnly || recovery != null
            ? metadata['remoteThreadsCursor'] as String?
            : page.nextCursor,
        remoteThreadsComplete: refreshOnly || recovery != null
            ? metadata['remoteThreadsComplete'] == true
            : page.nextCursor == null,
        receiveRecovery: nextRecovery,
      );
    }
    return List.unmodifiable(current);
  });

  /// Messages and pagination checkpoint commit in the same account archive write.
  /// Historical rows never create unread alerts or unlock live-receipt send limits.
  Future<TwitchWhisperConversation> mergeRemotePage(
    String ownerId,
    TwitchWhisperConversation peer,
    TwitchWhisperRemotePage page, {
    bool refreshOnly = false,
    bool Function()? canApply,
    TwitchWhisperRecoveryCheckpoint? recovery,
  }) => _serialized(() async {
    if (page.ownerId != ownerId || page.peerId != peer.userId) {
      throw const FormatException('Remote whisper page account mismatch');
    }
    final conversations = (await _load(ownerId)).toList();
    final index = conversations.indexWhere(
      (value) => value.userId == peer.userId,
    );
    final current = index < 0 ? peer : conversations[index];
    if (canApply?.call() == false) return current;
    final nextRecovery = recovery?.afterHistory(page);
    if (recovery != null) {
      final raw = await read(_key(ownerId));
      _checkRecovery(raw == null ? const {} : jsonDecode(raw) as Map, recovery);
      if (index < 0) throw const FormatException('Recovery peer was removed');
    }
    if (recovery == null &&
        page.requestedCursor != null &&
        page.requestedCursor != current.remoteHistoryCursor) {
      throw const FormatException('Stale remote whisper cursor');
    }
    final byId = {for (final message in current.messages) message.id: message};
    for (final message in page.messages) {
      final incoming =
          message.fromUserId == peer.userId && message.toUserId == ownerId;
      final outgoing =
          message.fromUserId == ownerId && message.toUserId == peer.userId;
      if ((!incoming && !outgoing) ||
          message.id.isEmpty ||
          (message.state != TwitchWhisperMessageState.received &&
              message.state != TwitchWhisperMessageState.submitted)) {
        throw const FormatException('Invalid remote whisper participant');
      }
      final existing = byId[message.id];
      if (existing != null &&
          (existing.fromUserId != message.fromUserId ||
              existing.toUserId != message.toUserId ||
              existing.text != message.text)) {
        throw const FormatException('Conflicting remote whisper identity');
      }
      byId.putIfAbsent(
        message.id,
        () => message.copyWith(historicalOnly: true),
      );
    }
    // Reject oversized synchronization atomically, rather than deleting drafts or
    // silently evicting previously saved local messages to fit the remote page.
    if (byId.length > 10000) {
      throw const TwitchWhisperArchiveException('此對話超過一萬則保存上限，原始資料已保留。');
    }
    final updated = current.copyWith(
      messages: byId.values,
      remoteHistoryCursor: page.nextCursor,
      replaceRemoteHistoryCursor: !refreshOnly && recovery == null,
      remoteHistoryComplete: refreshOnly || recovery != null
          ? current.remoteHistoryComplete
          : page.exhausted,
    );
    if (index < 0) {
      conversations.add(updated);
    } else {
      conversations[index] = updated;
    }
    final encodedSize = utf8.encode(jsonEncode(updated.toJson())).length;
    if (encodedSize > 4 * 1024 * 1024) {
      throw const TwitchWhisperArchiveException('此對話超過四 MiB 保存上限，原始資料已保留。');
    }
    _checkRemoteAccountCapacity(conversations);
    if (canApply?.call() != false) {
      await _save(ownerId, conversations, receiveRecovery: nextRecovery);
    }
    return updated;
  });

  Future<void> saveDraft(
    String ownerId,
    TwitchWhisperConversation peer,
    String draft,
  ) => _serialized(() async {
    final conversations = (await _load(ownerId)).toList();
    final index = conversations.indexWhere((c) => c.userId == peer.userId);
    if (index < 0) {
      conversations.add(peer.copyWith(draft: draft));
    } else {
      if (conversations[index].draft == draft) return;
      conversations[index] = conversations[index].copyWith(draft: draft);
    }
    await _save(ownerId, conversations);
  });

  /// Save a known API acceptance only onto its existing local message. Never
  /// recreate a removed conversation or correlate by content/time.
  Future<bool> saveSubmittedReceipt(
    String ownerId,
    TwitchWhisperMessage message,
  ) => _serialized(() async {
    if (message.fromUserId != ownerId ||
        message.state != TwitchWhisperMessageState.submitted) {
      throw const FormatException('Invalid submitted whisper receipt');
    }
    final conversations = (await _load(ownerId)).toList();
    final index = conversations.indexWhere((c) => c.userId == message.toUserId);
    if (index < 0) return false;
    final peer = conversations[index];
    final matches = peer.messages.where((m) => m.id == message.id);
    if (matches.isEmpty) return false;
    final prior = matches.single;
    if (prior.fromUserId != message.fromUserId ||
        prior.toUserId != message.toUserId ||
        prior.text != message.text) {
      throw const FormatException('Conflicting submitted whisper receipt');
    }
    if (prior.state == TwitchWhisperMessageState.submitted) return true;
    conversations[index] = peer.copyWith(
      messages: peer.messages.map((m) => m.id == message.id ? message : m),
    );
    await _save(ownerId, conversations);
    return true;
  });

  Future<bool> append(
    String ownerId,
    TwitchWhisperConversation peer,
    TwitchWhisperMessage message, {
    bool reading = false,
    String? peerLogin,
    String? peerDisplayName,
  }) => _serialized(() async {
    final conversations = (await _load(ownerId)).toList();
    final index = conversations.indexWhere((c) => c.userId == peer.userId);
    final current = index < 0 ? peer : conversations[index];
    final prior = current.messages.where((m) => m.id == message.id).firstOrNull;
    if (prior != null &&
        (prior.fromUserId != message.fromUserId ||
            prior.toUserId != message.toUserId ||
            prior.text != message.text)) {
      throw const FormatException('Conflicting live whisper identity');
    }
    final incoming =
        message.fromUserId == peer.userId && message.toUserId == ownerId;
    final promoted =
        prior?.historicalOnly == true &&
        incoming &&
        message.state == TwitchWhisperMessageState.received &&
        !message.historicalOnly;
    final duplicate = prior != null && !promoted;
    final validLogin =
        peerLogin != null && RegExp(r'^[a-z0-9_]{1,25}$').hasMatch(peerLogin);
    final validName =
        peerDisplayName != null && peerDisplayName.trim().isNotEmpty;
    final updateProfile =
        incoming &&
        !duplicate &&
        message.state == TwitchWhisperMessageState.received &&
        (validLogin || validName) &&
        (current.profileObservedAt == null ||
            message.timestamp.isAfter(current.profileObservedAt!));
    final updated = current.copyWith(
      login: updateProfile && validLogin ? peerLogin : null,
      displayName: updateProfile && validName ? peerDisplayName.trim() : null,
      profileObservedAt: updateProfile ? message.timestamp.toUtc() : null,
      hasReceivedWhisper:
          current.hasReceivedWhisper ||
          (incoming && message.state == TwitchWhisperMessageState.received),
      messages: [...current.messages, message],
      unreadCount: reading
          ? 0
          : current.unreadCount + (incoming && !duplicate ? 1 : 0),
    );
    if (index < 0) {
      conversations.add(updated);
    } else {
      conversations[index] = updated;
    }
    await _save(ownerId, conversations);
    return !duplicate;
  });

  Future<void> updateProfile(
    String ownerId,
    TwitchWhisperConversation profile,
    DateTime observedAt, {
    required bool Function() canApply,
  }) => _serialized(() async {
    final conversations = (await _load(ownerId)).toList();
    if (!canApply()) return;
    final index = conversations.indexWhere(
      (peer) => peer.userId == profile.userId,
    );
    if (index < 0) return;
    final current = conversations[index];
    final newer =
        current.profileObservedAt == null ||
        !observedAt.isBefore(current.profileObservedAt!);
    conversations[index] = current.copyWith(
      login: newer ? profile.login : null,
      displayName: newer ? profile.displayName : null,
      profileObservedAt: newer ? observedAt.toUtc() : null,
      avatarUrl: profile.avatarUrl,
      replaceAvatar: true,
    );
    if (canApply()) await _save(ownerId, conversations);
  });

  Future<void> markRead(String ownerId, String peerId) => _serialized(() async {
    final conversations = (await _load(ownerId)).toList();
    final index = conversations.indexWhere((c) => c.userId == peerId);
    if (index < 0 || conversations[index].unreadCount == 0) return;
    conversations[index] = conversations[index].copyWith(unreadCount: 0);
    await _save(ownerId, conversations);
  });

  Future<bool> removeConversation(
    String ownerId,
    String peerId, {
    bool Function()? canApply,
  }) => _serialized(() async {
    if (canApply?.call() == false) return false;
    final conversations = (await _load(ownerId)).toList();
    if (canApply?.call() == false) return false;
    conversations.removeWhere((peer) => peer.userId == peerId);
    await _save(ownerId, conversations);
    return true;
  });

  Future<String> exportBackup(String ownerId) => _serialized(() async {
    final conversations = await _load(ownerId);
    final raw = jsonEncode({
      'version': 1,
      'ownerId': ownerId,
      'conversations': conversations.map((peer) => peer.toJson()).toList(),
    });
    _checkBackupCapacity(raw);
    return raw;
  });

  /// Atomic same-account merge. Imported history never generates unread alerts.
  Future<int> importBackup(String ownerId, String raw) => _serialized(() async {
    _checkBackupCapacity(raw);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['ownerId'] != ownerId || json['version'] != 1) {
      throw const FormatException('Whisper backup belongs to another account');
    }
    final imported = (json['conversations'] as List)
        .map(
          (value) => TwitchWhisperConversation.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
    _validate(ownerId, imported);
    final conversations = (await _load(ownerId)).toList();
    var added = 0;
    for (final peer in imported) {
      final index = conversations.indexWhere(
        (item) => item.userId == peer.userId,
      );
      final current = index < 0
          ? peer.copyWith(
              messages: const [],
              unreadCount: 0,
              remoteUnreadCount: 0,
              hasReceivedWhisper: false,
              resetProfileObservedAt: true,
              // Backup restores content, not another session's remote state.
              replaceRemoteHistoryCursor: true,
              remoteHistoryComplete: false,
            )
          : conversations[index];
      final ids = current.messages.map((message) => message.id).toSet();
      final existingById = {
        for (final message in current.messages) message.id: message,
      };
      for (final message in peer.messages) {
        final prior = existingById[message.id];
        if (prior != null &&
            (prior.fromUserId != message.fromUserId ||
                prior.toUserId != message.toUserId ||
                prior.text != message.text)) {
          throw const FormatException('Conflicting imported whisper identity');
        }
      }
      final newMessages = peer.messages
          .where((message) => !ids.contains(message.id))
          .map(
            (message) => message.copyWith(
              historicalOnly: true,
              state: message.state == TwitchWhisperMessageState.sending
                  ? TwitchWhisperMessageState.unconfirmed
                  : message.state,
            ),
          )
          .toList();
      added += newMessages.length;
      final merged = current.copyWith(
        messages: [...current.messages, ...newMessages],
      );
      if (index < 0) {
        conversations.add(merged);
      } else {
        conversations[index] = merged;
      }
    }
    await _save(ownerId, conversations);
    return added;
  });
}

class TwitchWhisperArchiveException implements Exception {
  final String message;
  const TwitchWhisperArchiveException(this.message);
}
