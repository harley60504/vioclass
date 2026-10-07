import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/chat/twitch_whisper_api_service.dart';
import '../../api/chat/twitch_whisper_history_api_service.dart';
import '../../api/chat/twitch_whisper_threads_api_service.dart';
import '../../models/chat/twitch_whisper_conversation.dart';
import '../../models/chat/twitch_whisper_emote_catalog.dart';
import '../../models/chat/twitch_whisper_remote_history.dart';
import '../../models/chat/twitch_whisper_recovery_checkpoint.dart';
import 'twitch_whisper_archive_store.dart';
import 'twitch_whisper_eventsub_service.dart';
import 'twitch_whisper_recovery_service.dart';

class _PendingWhisperIncoming {
  final TwitchWhisperConversation peer;
  final TwitchWhisperMessage message;
  final bool reading;
  final String? login;
  final String? displayName;
  const _PendingWhisperIncoming(
    this.peer,
    this.message,
    this.reading,
    this.login,
    this.displayName,
  );
}

/// Owned by the app's home lifetime, not by the private-message panel.
class TwitchWhisperInboxController extends ChangeNotifier {
  final TwitchWhisperApiService api;
  final TwitchWhisperHistoryApiService? historyApi;
  late final TwitchWhisperThreadsApiService? threadsApi;
  bool syncingThreads = false;
  final Duration threadsSyncTimeout;
  int _threadsRequest = 0;
  bool _threadsRetryMore = false;
  Completer<TwitchWhisperThreadsPage>? _threadsCancellation;
  bool get canCancelThreadsSync =>
      syncingThreads && _threadsCancellation != null;
  String? threadsError;
  String? threadsStatus;
  String? _threadsCursor;
  bool threadsComplete = false;
  bool syncingHistory = false;
  final Duration historySyncTimeout;
  final Duration recoverySyncTimeout;
  int _historyRequest = 0;
  bool _historyRetryOlder = false;
  Completer<TwitchWhisperRemotePage>? _historyCancellation;
  bool get canCancelHistorySync =>
      syncingHistory && _historyCancellation != null;
  String? historyPeerId;
  String? historyError;
  String? historyStatus;
  final _historicalIds = <String>{};
  bool isHistoricalMessage(String id) => _historicalIds.contains(id);
  void _refreshHistoricalIds() {
    _historicalIds
      ..clear()
      ..addAll(
        _conversations
            .expand((peer) => peer.messages)
            .where((message) => message.historicalOnly)
            .map((message) => message.id),
      );
  }

  late final TwitchWhisperArchiveStore archive;
  TwitchWhisperEventSubService? _receiver;
  final void Function(TwitchWhisperConversation peer)? onIncomingNotification;
  String receiveStatus = '私訊收件尚未連線';
  final _receiveGaps = <String, DateTime>{};
  final _receiveGapObservations = <String, DateTime>{};
  final _receiveGapObservationIds = <String, String>{};
  String? _activeReceiveOwner;
  bool get historyRecoveryNeeded => _receiveGaps.containsKey(_ownerId);
  // Typed connection signal, not inferred from localized status strings.
  void recordReceiveGap(String owner) {
    if (_disposed || _ownerId != owner) return;
    final now = DateTime.now().toUtc();
    _receiveGaps.putIfAbsent(owner, () => now);
    _receiveGapObservations[owner] = now;
    _receiveGapObservationIds[owner] =
        TwitchWhisperArchiveStore.newReceiveGapObservationId();
    unawaited(_saveReceiveGap(owner, _generation));
    _notify();
  }

  Future<void> _saveReceiveGap(
    String owner,
    int generation, {
    bool requireSaved = false,
  }) async {
    final since = _receiveGaps[owner];
    if (since == null || !_current(generation, owner)) return;
    final observedAt = _receiveGapObservations[owner];
    final observationId = _receiveGapObservationIds[owner];
    try {
      final saved = await archive.recordReceiveGap(
        owner,
        since,
        observedAt: observedAt ?? since,
        observationId: observationId,
        canApply: () => _current(generation, owner),
      );
      // A completed owner-scoped commit may be acknowledged after navigation.
      // Never acknowledge a cancelled write or erase a newer pending signal.
      if (saved && _receiveGapObservationIds[owner] == observationId) {
        _receiveGapObservationIds.remove(owner);
        _receiveGapObservations.remove(owner);
      }
    } catch (_) {
      if (_current(generation, owner)) {
        errorText = '收件缺口紀錄尚未保存，退出 App 可能遺失；請恢復儲存後重新載入。';
        _notify();
      }
      if (requireSaved) rethrow;
    }
  }

  Future<void> _incomingQueue = Future<void>.value();
  List<TwitchWhisperConversation> _conversations = const [];
  String? _ownerId;
  String? _activePeerId;
  String ownerName = '';
  String? errorText;
  bool loading = false;
  bool sessionReady = false;
  bool searching = false;
  bool refreshingProfile = false;
  bool loadingEmotes = false;
  TwitchWhisperEmoteCatalog emoteCatalog =
      const TwitchWhisperEmoteCatalog.empty();
  String? emoteError;
  bool sending = false;
  bool panelVisible = false;
  bool _managingHistory = false;
  bool get managingHistory => _managingHistory || recoveringHistory;
  set managingHistory(bool value) => _managingHistory = value;
  TwitchWhisperRecoveryService? _recovery;
  int? _recoveryGeneration;
  bool get recoveringHistory =>
      _recoveryGeneration != null || (_recovery?.running ?? false);
  bool get canCancelRecovery => _recovery?.canCancel ?? false;
  bool get savingRecovery => _recovery?.committing ?? false;
  TwitchWhisperRecoveryCheckpoint? recoveryProgress;
  String? recoveryError;
  String? recoveryStatus;
  bool get canRecoverHistory => _recovery != null;
  void cancelRecovery() => _recovery?.cancel();

  Future<void> recoverHistory() async {
    final owner = _ownerId;
    final recovery = _recovery;
    if (owner == null ||
        recovery == null ||
        recoveringHistory ||
        loading ||
        sending ||
        _managingHistory ||
        syncingThreads ||
        syncingHistory) {
      return;
    }
    final generation = _generation;
    _recoveryGeneration = generation;
    recoveryError = null;
    recoveryStatus = null;
    try {
      await flushDrafts();
      await _saveReceiveGap(owner, generation, requireSaved: true);
      if (!_current(generation, owner)) return;
      await recovery.run(
        owner,
        canApply: () => _current(generation, owner),
        // Refresh the current UI's busy flag even after an account change,
        // without copying any previous owner's progress or data.
        onState: _notify,
        onProgress: (work) {
          if (!_current(generation, owner)) return;
          recoveryProgress = work;
          _notify();
        },
      );
      if (_current(generation, owner)) {
        recoveryStatus = '已讀取本次可取得的對話歷史；不保證 Twitch 全部保留資料，收件缺口仍保留。';
      }
    } catch (error) {
      if (_current(generation, owner)) {
        recoveryError = error is TwitchWhisperException
            ? error.message
            : error is TwitchWhisperArchiveException
            ? error.message
            : error is TimeoutException
            ? '歷史恢復讀取逾時；已保存進度保留，可續接原頁。'
            : '歷史恢復未完成；已保存進度保留，可續接原頁。';
      }
    } finally {
      if (_recoveryGeneration == generation) _recoveryGeneration = null;
      if (_current(generation, owner)) {
        try {
          await _reload(owner, generation);
        } catch (_) {
          recoveryError = '歷史恢復資料無法載入；已保存進度未清除。';
        }
        _notify();
      }
    }
  }

  bool appForeground = true;
  bool _readingLatest = true;
  bool get readingLatest => _readingLatest;
  bool _disposed = false;
  int _generation = 0;
  int _messageSerial = 0;
  int _selectionSerial = 0;
  Future<void>? _sessionRefresh;
  final Map<String, Timer> _draftTimers = {};
  final Map<String, String> _pendingDrafts = {};
  // API acceptance known only in this controller lifetime. Owner keys prevent
  // another account from displaying or persisting these unsaved receipts.
  final _pendingSubmitted = <String, Map<String, TwitchWhisperMessage>>{};
  final _pendingIncoming = <String, Map<String, _PendingWhisperIncoming>>{};
  // Only the selected peer is paused until its local deletion commits/fails.
  final _deletingIncomingPeers = <(String, String), Object>{};
  int get pendingIncomingCount => _pendingIncoming[_ownerId]?.length ?? 0;

  Future<void> _flushIncoming(String owner, int generation) async {
    final pending = _pendingIncoming[owner];
    if (pending == null) return;
    for (final item in pending.values.toList()) {
      if (!_current(generation, owner)) return;
      if (_deletingIncomingPeers.containsKey((owner, item.peer.userId)) ||
          !identical(pending[item.message.id], item)) {
        continue;
      }
      final added = await archive.append(
        owner,
        item.peer,
        item.message,
        reading:
            item.reading ||
            (appForeground &&
                panelVisible &&
                _activePeerId == item.peer.userId &&
                _readingLatest),
        peerLogin: item.login,
        peerDisplayName: item.displayName,
      );
      if (identical(pending[item.message.id], item)) {
        pending.remove(item.message.id);
      }
      final viewing =
          appForeground && panelVisible && _activePeerId == item.peer.userId;
      if (added && !viewing && _current(generation, owner)) {
        var notificationPeer = item.peer;
        try {
          final saved = await archive.load(owner);
          notificationPeer =
              saved
                  .where((peer) => peer.userId == item.peer.userId)
                  .firstOrNull ??
              item.peer;
        } catch (_) {
          final existing = _conversations
              .where((peer) => peer.userId == item.peer.userId)
              .firstOrNull;
          if (existing?.profileObservedAt != null &&
              existing!.profileObservedAt!.isAfter(item.message.timestamp)) {
            notificationPeer = existing;
          }
        }
        if (!_current(generation, owner)) return;
        // Notification failures must not turn a saved message into a pending
        // write or prevent later inbox messages from being processed.
        try {
          onIncomingNotification?.call(notificationPeer);
        } catch (_) {
          errorText = '私訊已保存，但通知顯示失敗。';
        }
      }
    }
  }

  bool hasUnsavedSubmission(TwitchWhisperMessage message) {
    final receipt = _pendingSubmitted[_ownerId]?[message.id];
    return receipt != null &&
        receipt.fromUserId == message.fromUserId &&
        receipt.toUserId == message.toUserId &&
        receipt.text == message.text;
  }

  void _overlaySubmitted(String owner) {
    final receipts = _pendingSubmitted[owner];
    if (receipts == null || receipts.isEmpty) return;
    _conversations = _conversations
        .map(
          (peer) => peer.copyWith(
            messages: peer.messages.map((message) {
              final receipt = receipts[message.id];
              return receipt != null &&
                      receipt.fromUserId == owner &&
                      receipt.toUserId == peer.userId &&
                      receipt.text == message.text &&
                      message.fromUserId == owner &&
                      message.toUserId == peer.userId
                  ? receipt
                  : message;
            }),
          ),
        )
        .toList();
  }

  TwitchWhisperInboxController({
    required this.api,
    this.historyApi,
    TwitchWhisperThreadsApiService? threadsApi,
    TwitchWhisperArchiveStore? store,
    bool receiveInBackground = true,
    this.onIncomingNotification,
    this.threadsSyncTimeout = const Duration(seconds: 45),
    this.historySyncTimeout = const Duration(seconds: 45),
    this.recoverySyncTimeout = const Duration(seconds: 45),
  }) {
    this.threadsApi =
        threadsApi ??
        (historyApi == null
            ? null
            : TwitchWhisperThreadsApiService(history: historyApi!));
    archive =
        store ??
        TwitchWhisperArchiveStore(
          read: (key) async =>
              (await SharedPreferences.getInstance()).getString(key),
          write: (key, value) async {
            final saved = await (await SharedPreferences.getInstance())
                .setString(key, value);
            if (!saved) {
              throw const TwitchWhisperArchiveException(
                'Could not save private message history',
              );
            }
          },
        );
    if (this.threadsApi != null && historyApi != null) {
      _recovery = TwitchWhisperRecoveryService(
        archive: archive,
        threads: this.threadsApi!,
        history: historyApi!,
        timeout: recoverySyncTimeout,
      );
    }
    if (receiveInBackground) {
      _receiver = TwitchWhisperEventSubService(
        api: api,
        onReceiveGap: recordReceiveGap,
        onStatus: (status) {
          receiveStatus = status;
          _notify();
        },
        onMessage: (event, timestamp) {
          final generation = _generation;
          _incomingQueue = _incomingQueue
              .then(
                (_) => receiveEvent(event, timestamp, generation: generation),
              )
              .catchError((Object _) {});
        },
      );
    }
  }

  String? get ownerId => _ownerId;
  String? get activePeerId => _activePeerId;
  List<TwitchWhisperConversation> get conversations =>
      List.unmodifiable(_conversations);
  int get unreadCount =>
      _conversations.fold(0, (count, peer) => count + peer.unreadCount);
  TwitchWhisperConversation? get activeConversation {
    for (final peer in _conversations) {
      if (peer.userId == _activePeerId) return peer;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation, String owner) =>
      !_disposed && _generation == generation && _ownerId == owner;

  Future<void> refreshSession({bool afterCurrent = false}) {
    if (_disposed) return Future<void>.value();
    final active = _sessionRefresh;
    if (active != null) {
      // Authorization may change credentials while this request validates the
      // previous token. Recheck only after the pending request has finished.
      return afterCurrent ? active.then((_) => refreshSession()) : active;
    }
    if (loading || sending || _managingHistory) return Future<void>.value();
    cancelRecovery();
    final completion = Completer<void>();
    final pending = completion.future;
    _sessionRefresh = pending;
    unawaited(
      _refreshSession().then(
        (_) {
          if (identical(_sessionRefresh, pending)) _sessionRefresh = null;
          completion.complete();
        },
        onError: (Object error, StackTrace stack) {
          if (identical(_sessionRefresh, pending)) _sessionRefresh = null;
          completion.completeError(error, stack);
        },
      ),
    );
    return pending;
  }

  Future<void> _refreshSession() async {
    if (_disposed || loading || sending || _managingHistory) return;
    _invalidateThreadsRead();
    _invalidateHistoryRead();
    final generation = ++_generation;
    recoveryProgress = null;
    recoveryError = null;
    recoveryStatus = null;
    syncingThreads = false;
    threadsError = null;
    threadsStatus = null;
    _threadsCursor = null;
    threadsComplete = false;
    _historicalIds.clear();
    syncingHistory = false;
    historyPeerId = null;
    historyError = null;
    historyStatus = null;
    loadingEmotes = false;
    emoteCatalog = const TwitchWhisperEmoteCatalog.empty();
    emoteError = null;
    refreshingProfile = false;
    _receiver?.stop();
    loading = true;
    searching = false;
    errorText = null;
    _notify();
    try {
      await flushDrafts();
      final auth = await api.session();
      if (_disposed || generation != _generation) return;
      final owner = auth.validation.userId;
      if (_ownerId != owner) {
        _activePeerId = null;
        _conversations = const [];
        _pendingDrafts.clear();
        for (final timer in _draftTimers.values) {
          timer.cancel();
        }
        _draftTimers.clear();
      }
      _ownerId = owner;
      ownerName = auth.validation.login;
      if (_activeReceiveOwner != owner) {
        try {
          await archive.beginReceiveSession(
            owner,
            DateTime.now().toUtc(),
            canApply: () => _current(generation, owner),
          );
          if (_current(generation, owner)) _activeReceiveOwner = owner;
        } catch (_) {
          if (_current(generation, owner)) {
            errorText = '收件會話紀錄尚未保存，重開 App 可能無法辨識離線區間；請恢復儲存後重新載入。';
          }
        }
      }
      final persistedGap = await archive.receiveGapSince(owner);
      if (_current(generation, owner) && persistedGap != null) {
        final prior = _receiveGaps[owner];
        if (prior == null || persistedGap.isBefore(prior)) {
          _receiveGaps[owner] = persistedGap;
        }
      }
      await _reload(owner, generation);
      final work = await archive.recoveryCheckpoint(owner);
      if (_current(generation, owner)) recoveryProgress = work;
      if (_current(generation, owner) && threadsApi != null) {
        final checkpoint = await archive.threadsCheckpoint(owner);
        if (_current(generation, owner)) {
          _threadsCursor = checkpoint.cursor;
          threadsComplete = checkpoint.complete;
        }
      }
      if (_current(generation, owner)) _receiver?.start(owner);
    } on TwitchWhisperException catch (error) {
      if (!_disposed && generation == _generation) {
        _ownerId = null;
        _activeReceiveOwner = null;
        _conversations = const [];
        _activePeerId = null;
        errorText = error.message;
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _ownerId = null;
        _activeReceiveOwner = null;
        _conversations = const [];
        _activePeerId = null;
        errorText = '私訊資料暫時無法載入；原本歷史已保留。';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        sessionReady = true;
        _notify();
      }
    }
  }

  /// Called only with an EventSub payload for the currently validated account.
  Future<void> receiveEvent(
    Map<String, dynamic> event,
    DateTime timestamp, {
    int? generation,
  }) async {
    final owner = _ownerId;
    final currentGeneration = generation ?? _generation;
    if (owner == null || !_current(currentGeneration, owner)) return;
    final from = event['from_user_id']?.toString() ?? '';
    final to = event['to_user_id']?.toString() ?? '';
    final id = event['whisper_id']?.toString() ?? '';
    final whisper = event['whisper'];
    if (!RegExp(r'^\d+$').hasMatch(from) ||
        from == owner ||
        to != owner ||
        id.isEmpty ||
        whisper is! Map ||
        whisper['text'] is! String) {
      return;
    }
    final rawLogin = event['from_user_login'];
    final login = rawLogin is String ? rawLogin.trim().toLowerCase() : '';
    final validLogin = RegExp(r'^[a-z0-9_]{1,25}$').hasMatch(login)
        ? login
        : null;
    final rawName = event['from_user_name'];
    final displayName = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : null;
    final existing = _conversations
        .where((peer) => peer.userId == from)
        .firstOrNull;
    final peer = TwitchWhisperConversation(
      userId: from,
      login: validLogin ?? existing?.login ?? from,
      displayName: displayName ?? existing?.displayName ?? validLogin ?? from,
    );
    final pending = _pendingIncoming[owner] ??= {};
    final prior = pending[id];
    final text = whisper['text'] as String;
    if (prior != null &&
        (prior.message.fromUserId != from || prior.message.text != text)) {
      errorText = '私訊事件 ID 與待保存資料衝突；原資料保留。';
      _notify();
      return;
    }
    // Bound volatile storage without silently evicting previously received
    // events. An overflow requires remote history recovery, not fake success.
    if (prior == null &&
        (pending.length >= 500 ||
            text.length +
                    pending.values.fold<int>(
                      0,
                      (sum, item) => sum + item.message.text.length,
                    ) >
                512 * 1024)) {
      errorText = '私訊待保存暫存已滿；部分收件未保存，請恢復儲存後同步 Twitch 歷史。';
      _notify();
      return;
    }
    pending.putIfAbsent(
      id,
      () => _PendingWhisperIncoming(
        peer,
        TwitchWhisperMessage(
          id: id,
          fromUserId: from,
          toUserId: to,
          text: text,
          timestamp: timestamp,
          state: TwitchWhisperMessageState.received,
        ),
        appForeground &&
            panelVisible &&
            _activePeerId == from &&
            _readingLatest,
        validLogin,
        displayName,
      ),
    );
    try {
      await _reload(owner, currentGeneration);
    } catch (_) {
      if (_current(currentGeneration, owner)) {
        errorText = pendingIncomingCount > 0
            ? '收到的私訊尚未保存，暫存於記憶體；請恢復儲存後重新載入，退出 App 可能遺失。'
            : '私訊草稿或歷史儲存失敗，請稍後再試。';
        _notify();
      }
    }
  }

  Future<void> _reload(String owner, int generation) async {
    if (_receiveGaps.containsKey(owner)) {
      await _saveReceiveGap(owner, generation);
    }
    await _flushIncoming(owner, generation);
    var loaded = await archive.load(owner);
    final receipts = _pendingSubmitted[owner];
    if (_current(generation, owner) &&
        receipts != null &&
        receipts.isNotEmpty) {
      for (final receipt in receipts.values.toList()) {
        if (!_current(generation, owner)) return;
        await archive.saveSubmittedReceipt(owner, receipt);
        // A removed message is deliberately not recreated by the archive.
        if (identical(receipts[receipt.id], receipt)) {
          receipts.remove(receipt.id);
        }
      }
      loaded = await archive.load(owner);
    }
    if (!_current(generation, owner)) return;
    _conversations = loaded
        .map(
          (peer) => _pendingDrafts.containsKey(peer.userId)
              ? peer.copyWith(draft: _pendingDrafts[peer.userId])
              : peer,
        )
        .toList();
    _overlaySubmitted(owner);
    _refreshHistoricalIds();
    _notify();
  }

  Future<void> syncActiveHistory({bool older = false}) async {
    final owner = _ownerId;
    final peer = activeConversation;
    final history = historyApi;
    if (owner == null ||
        peer == null ||
        history == null ||
        loading ||
        managingHistory ||
        syncingHistory ||
        syncingThreads ||
        _disposed) {
      return;
    }
    if (older && peer.remoteHistoryComplete) return;
    final generation = _generation;
    final request = ++_historyRequest;
    bool current() => _current(generation, owner) && request == _historyRequest;
    _historyRetryOlder = older;
    syncingHistory = true;
    historyPeerId = peer.userId;
    historyError = null;
    historyStatus = null;
    _notify();
    try {
      await flushDrafts();
      if (!current() || _activePeerId != peer.userId) return;
      final cancellation = Completer<TwitchWhisperRemotePage>();
      _historyCancellation = cancellation;
      final response = history.page(
        ownerId: owner,
        peerId: peer.userId,
        cursor: older ? peer.remoteHistoryCursor : null,
      );
      final pending = Future.any([
        response,
        cancellation.future,
      ]).timeout(historySyncTimeout);
      _notify();
      final page = await pending;
      if (!current()) return;
      _historyCancellation = null;
      _notify();
      await archive.mergeRemotePage(
        owner,
        peer,
        page,
        refreshOnly:
            !older &&
            (peer.remoteHistoryCursor != null || peer.remoteHistoryComplete),
        canApply: current,
      );
      if (!current()) return;
      await _reload(owner, generation);
      if (!current()) return;
      historyStatus = '已同步 ${peer.displayName} 的一頁歷史；不代表所有對話已同步。';
    } on TimeoutException {
      if (current()) {
        historyError = '私訊歷史同步逾時，原資料與分頁位置已保留，請重試。';
      }
    } on TwitchWhisperException catch (error) {
      if (current()) historyError = error.message;
    } on TwitchWhisperArchiveException catch (error) {
      if (current()) historyError = error.message;
    } catch (_) {
      if (current()) {
        historyError = '私訊歷史同步未完成，原資料與分頁位置已保留。';
      }
    } finally {
      if (current()) {
        _historyCancellation = null;
        syncingHistory = false;
        _notify();
      }
    }
  }

  void cancelHistorySync() {
    if (!canCancelHistorySync) return;
    _invalidateHistoryRead();
    historyError = null;
    historyStatus = '已取消歷史同步，原資料與分頁位置已保留。';
    _notify();
  }

  Future<void> retryHistorySync() async {
    if (historyError != null && historyPeerId == _activePeerId) {
      await syncActiveHistory(older: _historyRetryOlder);
    }
  }

  void _invalidateHistoryRead() {
    final pending = _historyCancellation;
    _historyCancellation = null;
    if (pending != null) {
      ++_historyRequest;
      syncingHistory = false;
      pending.completeError(const TwitchWhisperException('歷史同步已停止。'));
    }
  }

  Future<void> syncThreads({bool more = false}) async {
    final owner = _ownerId;
    final remote = threadsApi;
    if (owner == null ||
        remote == null ||
        loading ||
        managingHistory ||
        syncingThreads ||
        syncingHistory ||
        _disposed ||
        (more && threadsComplete)) {
      return;
    }
    final generation = _generation;
    final request = ++_threadsRequest;
    _threadsRetryMore = more;
    bool current() => _current(generation, owner) && request == _threadsRequest;
    final requestedAt = DateTime.now().toUtc();
    void traceThreads(String stage) {
      if (kDebugMode) {
        debugPrint(
          '[WhisperSync generation=$generation request=$request] $stage',
        );
      }
    }

    traceThreads('start localCount=${_conversations.length} more=$more');
    syncingThreads = true;
    threadsError = null;
    threadsStatus = null;
    _notify();
    try {
      await flushDrafts();
      if (!current()) return;
      final cancellation = Completer<TwitchWhisperThreadsPage>();
      _threadsCancellation = cancellation;
      final response = remote.page(
        ownerId: owner,
        cursor: more ? _threadsCursor : null,
      );
      final pending = Future.any([
        response,
        cancellation.future,
      ]).timeout(threadsSyncTimeout);
      _notify();
      final page = await pending;
      traceThreads(
        'response parsed peers=${page.conversations.length} current=${current()}',
      );
      if (!current()) return;
      // Cancellation is safe while reading the server, not during a disk commit.
      _threadsCancellation = null;
      _notify();
      await archive.mergeThreadsPage(
        owner,
        page,
        requestedAt: requestedAt,
        canApply: current,
      );
      traceThreads('archive merge returned current=${current()}');
      if (!current()) return;
      await _reload(owner, generation);
      traceThreads(
        'reload localCount=${_conversations.length} current=${current()}',
      );
      final checkpoint = await archive.threadsCheckpoint(owner);
      if (!current()) return;
      _threadsCursor = checkpoint.cursor;
      threadsComplete = checkpoint.complete;
      threadsStatus = threadsComplete
          ? '已讀至已保存的 Twitch 對話列表最後一頁。'
          : '已同步一頁 Twitch 對話，仍可載入更多。';
    } on TimeoutException {
      if (current()) {
        threadsError = 'Twitch 對話同步逾時，原對話與分頁位置已保留，請重試。';
      }
    } on TwitchWhisperException catch (error) {
      if (current()) {
        threadsError = error.message;
      }
      traceThreads('failed API; archive merge not completed');
    } on TwitchWhisperArchiveException catch (error) {
      if (current()) {
        threadsError = error.message;
      }
      traceThreads('failed archive');
    } catch (_) {
      if (current()) {
        threadsError = 'Twitch 對話同步未完成，原對話與分頁位置已保留。';
      }
      traceThreads('failed unexpected exception');
    } finally {
      if (current()) {
        _threadsCancellation = null;
        syncingThreads = false;
        _notify();
      }
    }
  }

  void cancelThreadsSync() {
    if (!canCancelThreadsSync) return;
    final cancellation = _threadsCancellation!;
    _threadsCancellation = null;
    ++_threadsRequest;
    syncingThreads = false;
    threadsError = null;
    threadsStatus = '已取消對話同步，原對話與分頁位置已保留。';
    cancellation.completeError(const TwitchWhisperException('對話同步已取消。'));
    _notify();
  }

  Future<void> retryThreadsSync() async {
    if (threadsError != null) await syncThreads(more: _threadsRetryMore);
  }

  void _invalidateThreadsRead() {
    final pending = _threadsCancellation;
    _threadsCancellation = null;
    if (pending != null) {
      ++_threadsRequest;
      pending.completeError(const TwitchWhisperException('對話同步已停止。'));
    }
  }

  Future<void> loadOfficialEmotes() async {
    final owner = _ownerId;
    if (owner == null || loading || loadingEmotes) return;
    final generation = _generation;
    loadingEmotes = true;
    emoteError = null;
    _notify();
    try {
      final catalog = await api.fetchWhisperEmotes(
        ownerId: owner,
        canRead: () => _current(generation, owner),
      );
      if (_current(generation, owner)) emoteCatalog = catalog;
    } on TwitchWhisperException catch (error) {
      if (_current(generation, owner)) emoteError = error.message;
    } catch (_) {
      if (_current(generation, owner)) emoteError = '官方貼圖暫時無法載入，請重試。';
    } finally {
      if (_current(generation, owner)) {
        loadingEmotes = false;
        _notify();
      }
    }
  }

  Future<void> refreshActiveProfile() async {
    final owner = _ownerId;
    final peerId = _activePeerId;
    if (owner == null || peerId == null || refreshingProfile || loading) return;
    final generation = _generation;
    final observedAt = DateTime.now().toUtc();
    final selection = _selectionSerial;
    bool canApply() =>
        _current(generation, owner) &&
        _activePeerId == peerId &&
        _selectionSerial == selection;
    refreshingProfile = true;
    errorText = null;
    _notify();
    try {
      final profile = await api.getUserById(
        ownerId: owner,
        peerId: peerId,
        canRead: canApply,
      );
      if (!canApply()) return;
      await archive.updateProfile(
        owner,
        profile,
        observedAt,
        canApply: canApply,
      );
      if (canApply()) await _reload(owner, generation);
    } on TwitchWhisperException catch (error) {
      if (canApply()) errorText = error.message;
    } catch (_) {
      if (canApply()) errorText = '私訊對象資料暫時無法更新；原本對話已保留。';
    } finally {
      if (_current(generation, owner)) {
        refreshingProfile = false;
        _notify();
      }
    }
  }

  Future<void> startConversation(String login) async {
    final owner = _ownerId;
    if (owner == null || searching || loading || managingHistory) return;
    final generation = _generation;
    searching = true;
    errorText = null;
    _notify();
    try {
      final peer = await api.findUser(login, owner);
      if (!_current(generation, owner)) return;
      final existing = _conversations.where((c) => c.userId == peer.userId);
      if (existing.isEmpty) await archive.saveDraft(owner, peer, '');
      await _reload(owner, generation);
      if (_current(generation, owner)) await selectConversation(peer.userId);
    } on TwitchWhisperException catch (error) {
      if (_current(generation, owner)) errorText = error.message;
    } catch (_) {
      if (_current(generation, owner)) errorText = '私訊資料暫時無法載入；原本歷史已保留。';
    } finally {
      if (_current(generation, owner)) {
        searching = false;
        _notify();
      }
    }
  }

  Future<void> selectConversation(String? peerId) async {
    final owner = _ownerId;
    if (owner == null) return;
    if (peerId != _activePeerId) _invalidateHistoryRead();
    final generation = _generation;
    final selection = ++_selectionSerial;
    if (peerId != _activePeerId || peerId == null) _readingLatest = true;
    _activePeerId = peerId;
    _notify();
    await flushDrafts();
    if (!_current(generation, owner) || selection != _selectionSerial) return;
    if (peerId != null && panelVisible && appForeground && _readingLatest) {
      try {
        await archive.markRead(owner, peerId);
        await _reload(owner, generation);
      } catch (_) {
        if (_current(generation, owner)) {
          errorText = '私訊草稿或歷史儲存失敗，請稍後再試。';
          _notify();
        }
      }
    }
  }

  void updateDraft(String peerId, String text) {
    if (_ownerId == null || _disposed) return;
    _pendingDrafts[peerId] = text;
    _conversations = _conversations
        .map(
          (peer) => peer.userId == peerId ? peer.copyWith(draft: text) : peer,
        )
        .toList();
    _draftTimers.remove(peerId)?.cancel();
    _draftTimers[peerId] = Timer(const Duration(milliseconds: 300), () {
      unawaited(flushDrafts());
    });
  }

  Future<void> flushDrafts() async {
    final owner = _ownerId;
    if (owner == null) return;
    final pending = Map<String, String>.from(_pendingDrafts);
    for (final entry in pending.entries) {
      _draftTimers.remove(entry.key)?.cancel();
      final peers = _conversations.where((c) => c.userId == entry.key);
      if (peers.isEmpty) continue;
      try {
        await archive.saveDraft(owner, peers.first, entry.value);
        if (_pendingDrafts[entry.key] == entry.value) {
          _pendingDrafts.remove(entry.key);
        }
      } catch (_) {
        if (!_disposed && _ownerId == owner) {
          errorText = '私訊草稿或歷史儲存失敗，請稍後再試。';
          _notify();
        }
      }
    }
  }

  Future<void> sendActiveMessage() async {
    final owner = _ownerId;
    final peer = activeConversation;
    if (owner == null ||
        peer == null ||
        sending ||
        loading ||
        managingHistory) {
      return;
    }
    final draft = peer.draft;
    final text = draft.trim();
    if (text.isEmpty || text.length > peer.messageLimit) return;
    final generation = _generation;
    sending = true;
    errorText = null;
    _notify();
    final message = TwitchWhisperMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}-${_messageSerial++}',
      fromUserId: owner,
      toUserId: peer.userId,
      text: text,
      timestamp: DateTime.now().toUtc(),
      state: TwitchWhisperMessageState.sending,
    );
    var acceptedByTwitch = false;
    try {
      await flushDrafts();
      await archive.append(owner, peer, message);
      await _reload(owner, generation);
      if (!_current(generation, owner)) return;
      await api.send(
        ownerId: owner,
        peerId: peer.userId,
        text: text,
        canSend: () => _current(generation, owner),
        hasReceivedWhisper: peer.hasReceivedWhisper,
      );
      acceptedByTwitch = true;
      final receipt = message.copyWith(
        state: TwitchWhisperMessageState.submitted,
      );
      if (_current(generation, owner)) {
        (_pendingSubmitted[owner] ??= {})[message.id] = receipt;
        _overlaySubmitted(owner);
      }
      await archive.append(
        owner,
        peer,
        message.copyWith(state: TwitchWhisperMessageState.submitted),
      );
      _pendingSubmitted[owner]?.remove(message.id);
      if (_current(generation, owner)) {
        final peers = _conversations.where((c) => c.userId == peer.userId);
        if (peers.isNotEmpty && peers.first.draft == draft) {
          _pendingDrafts.remove(peer.userId);
          await archive.saveDraft(owner, peers.first, '');
        }
      }
    } catch (error) {
      try {
        await archive.append(
          owner,
          peer,
          message.copyWith(
            state: acceptedByTwitch
                ? TwitchWhisperMessageState.submitted
                : error is TwitchWhisperException && error.outcomeUnknown
                ? TwitchWhisperMessageState.unconfirmed
                : TwitchWhisperMessageState.failed,
          ),
        );
        if (acceptedByTwitch) _pendingSubmitted[owner]?.remove(message.id);
      } catch (_) {
        /* Preserve the original send error; never erase history. */
      }
      if (_current(generation, owner)) {
        errorText = acceptedByTwitch
            ? 'Twitch 已接受本次提交，但本機紀錄或草稿保存未完成；請勿直接重送。'
            : error is TwitchWhisperException
            ? error.message
            : '私訊送出失敗，請確認授權、電話驗證與 Twitch 限制。';
      }
    } finally {
      if (_current(generation, owner)) {
        sending = false;
        try {
          await _reload(owner, generation);
        } catch (_) {
          errorText = acceptedByTwitch
              ? 'Twitch 已接受本次提交，但本機紀錄或草稿保存未完成；請勿直接重送。'
              : '私訊草稿或歷史儲存失敗，請稍後再試。';
        }
        _overlaySubmitted(owner);
        _notify();
      }
    }
  }

  void setPanelVisible(bool visible) {
    panelVisible = visible;
    if (!visible) _readingLatest = true;
    if (!visible) unawaited(flushDrafts());
  }

  void setReadingLatest(bool reading) {
    if (_disposed || _readingLatest == reading) return;
    _readingLatest = reading;
    if (reading && panelVisible && appForeground && _activePeerId != null) {
      unawaited(selectConversation(_activePeerId));
    }
  }

  void setAppForeground(bool foreground) {
    if (_disposed || appForeground == foreground) return;
    appForeground = foreground;
    if (foreground && panelVisible && _activePeerId != null) {
      unawaited(selectConversation(_activePeerId));
    }
    _notify();
  }

  Future<String?> exportBackup() async {
    final owner = _ownerId;
    if (owner == null || sending || managingHistory) return null;
    final generation = _generation;
    await flushDrafts();
    final raw = await archive.exportBackup(owner);
    return _current(generation, owner) ? raw : null;
  }

  Future<int?> importBackup(String raw) async {
    final owner = _ownerId;
    if (owner == null ||
        sending ||
        managingHistory ||
        syncingHistory ||
        syncingThreads) {
      return null;
    }
    final generation = _generation;
    managingHistory = true;
    errorText = null;
    _notify();
    try {
      await flushDrafts();
      final added = await archive.importBackup(owner, raw);
      await _reload(owner, generation);
      return _current(generation, owner) ? added : null;
    } catch (error) {
      if (_current(generation, owner)) {
        errorText = error is TwitchWhisperArchiveException
            ? error.message
            : '備份格式不符、不是目前帳號，或無法儲存；原本歷史已保留。';
      }
      return null;
    } finally {
      if (_current(generation, owner)) {
        managingHistory = false;
        _notify();
      }
    }
  }

  Future<void> removeConversation(String peerId) async {
    final owner = _ownerId;
    if (owner == null ||
        _disposed ||
        loading ||
        sending ||
        managingHistory ||
        syncingHistory ||
        syncingThreads) {
      return;
    }
    final generation = _generation;
    var removed = false;
    final deletionKey = (owner, peerId);
    final deletionToken = Object();
    void releaseIncoming() {
      if (identical(_deletingIncomingPeers[deletionKey], deletionToken)) {
        _deletingIncomingPeers.remove(deletionKey);
      }
    }

    final priorIncoming = Map<String, _PendingWhisperIncoming>.fromEntries(
      (_pendingIncoming[owner]?.entries ??
              const <MapEntry<String, _PendingWhisperIncoming>>[])
          .where((entry) => entry.value.peer.userId == peerId),
    );
    _deletingIncomingPeers[deletionKey] = deletionToken;
    managingHistory = true;
    errorText = null;
    _notify();
    try {
      await flushDrafts();
      if (!_current(generation, owner)) return;
      removed = await archive.removeConversation(
        owner,
        peerId,
        canApply: () => _current(generation, owner),
      );
      if (!removed) return;
      // Remove only arrivals already pending when deletion began, after commit.
      // A new ID received during deletion is preserved and may recreate the peer.
      final pending = _pendingIncoming[owner];
      for (final entry in priorIncoming.entries) {
        if (identical(pending?[entry.key], entry.value)) {
          pending?.remove(entry.key);
        }
      }
      releaseIncoming();
      if (_current(generation, owner)) {
        _conversations = _conversations
            .where((peer) => peer.userId != peerId)
            .toList();
        _refreshHistoricalIds();
        _pendingDrafts.remove(peerId);
        _draftTimers.remove(peerId)?.cancel();
      }
      if (_current(generation, owner) && _activePeerId == peerId) {
        _activePeerId = null;
      }
      await _reload(owner, generation);
    } catch (_) {
      if (_current(generation, owner)) {
        errorText = removed
            ? '本機對話已刪除，但列表重新載入失敗；請重新載入確認，不必重複刪除。'
            : '本機對話刪除未完成，原資料已保留；請恢復儲存後再試。';
      }
    } finally {
      releaseIncoming();
      if (_current(generation, owner)) {
        managingHistory = false;
        _notify();
      }
    }
  }

  void clearSession() {
    cancelRecovery();
    _recoveryGeneration = null;
    recoveryProgress = null;
    recoveryError = null;
    recoveryStatus = null;
    _invalidateThreadsRead();
    _invalidateHistoryRead();
    _sessionRefresh = null;
    syncingThreads = false;
    threadsError = null;
    threadsStatus = null;
    _threadsCursor = null;
    threadsComplete = false;
    _historicalIds.clear();
    syncingHistory = false;
    historyPeerId = null;
    historyError = null;
    historyStatus = null;
    loadingEmotes = false;
    emoteCatalog = const TwitchWhisperEmoteCatalog.empty();
    emoteError = null;
    ++_generation;
    _receiver?.stop();
    receiveStatus = '私訊收件尚未連線';
    _ownerId = null;
    _activePeerId = null;
    ownerName = '';
    _conversations = const [];
    _pendingDrafts.clear();
    _pendingSubmitted.clear();
    _pendingIncoming.clear();
    _receiveGaps.clear();
    _receiveGapObservations.clear();
    _receiveGapObservationIds.clear();
    _activeReceiveOwner = null;
    for (final timer in _draftTimers.values) {
      timer.cancel();
    }
    _draftTimers.clear();
    loading = false;
    searching = false;
    sending = false;
    refreshingProfile = false;
    sessionReady = true;
    managingHistory = false;
    _notify();
  }

  @override
  void dispose() {
    cancelRecovery();
    _invalidateThreadsRead();
    _invalidateHistoryRead();
    unawaited(flushDrafts());
    _disposed = true;
    _pendingSubmitted.clear();
    _pendingIncoming.clear();
    _receiveGaps.clear();
    _receiveGapObservations.clear();
    _receiveGapObservationIds.clear();
    ++_generation;
    _receiver?.stop();
    for (final timer in _draftTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
