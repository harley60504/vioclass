import 'dart:async';

import '../../api/chat/twitch_whisper_api_service.dart';
import '../../api/chat/twitch_whisper_history_api_service.dart';
import '../../api/chat/twitch_whisper_threads_api_service.dart';
import '../../models/chat/twitch_whisper_recovery_checkpoint.dart';
import 'twitch_whisper_archive_store.dart';

/// Enumerate every accessible thread, then page every discovered/local peer.
/// Complete means exhausted API cursors, never delivery or unlimited retention.
class TwitchWhisperRecoveryService {
  final TwitchWhisperArchiveStore archive;
  final TwitchWhisperThreadsApiService threads;
  final TwitchWhisperHistoryApiService history;
  final Duration timeout;
  bool running = false;
  bool committing = false;
  bool _cancelled = false;
  Completer<void>? _cancellation;
  bool get canCancel => running && !committing;

  TwitchWhisperRecoveryService({
    required this.archive,
    required this.threads,
    required this.history,
    this.timeout = const Duration(seconds: 45),
  });

  void cancel() {
    if (!canCancel) return;
    _cancelled = true;
    _cancellation?.complete();
    _cancellation = null;
  }

  Future<T> _read<T>(Future<T> request) => Future.any<T>([
    request,
    _cancellation!.future.then<T>(
      (_) => throw const TwitchWhisperException('歷史恢復已取消，已保存的進度保留。'),
    ),
  ]).timeout(timeout);

  Future<TwitchWhisperRecoveryCheckpoint> run(
    String owner, {
    required bool Function() canApply,
    void Function(TwitchWhisperRecoveryCheckpoint work)? onProgress,
    void Function()? onState,
  }) async {
    if (running) throw const TwitchWhisperException('歷史恢復已在執行。');
    running = true;
    _cancelled = false;
    _cancellation = Completer<void>();
    bool current() => !_cancelled && canApply();
    void commit(bool value) {
      committing = value;
      onState?.call();
    }

    void check() {
      if (!current()) throw const TwitchWhisperException('帳號已變更或恢復已停止；原進度保留。');
    }

    try {
      check();
      commit(true);
      var work = await archive.beginRecovery(owner, canApply: current);
      commit(false);
      check();
      onProgress?.call(work);
      while (!work.complete) {
        check();
        if (await archive.recoveryNeedsRestart(owner, work)) {
          throw const TwitchWhisperException('恢復期間出現新收件缺口；已保存資料保留，請重新恢復全部對話。');
        }
        check();
        if (work.phase == 'threads') {
          final requestedAt = DateTime.now().toUtc();
          final page = await _read(
            threads.page(ownerId: owner, cursor: work.cursor),
          );
          check();
          commit(true);
          await archive.mergeThreadsPage(
            owner,
            page,
            recovery: work,
            canApply: current,
            requestedAt: requestedAt,
          );
        } else {
          final peers = await archive.load(owner);
          check();
          final peer = peers
              .where((p) => p.userId == work.activePeerId)
              .firstOrNull;
          if (peer == null) {
            throw const TwitchWhisperException('恢復對話已移除，原進度保留。');
          }
          final page = await _read(
            history.page(
              ownerId: owner,
              peerId: peer.userId,
              cursor: work.cursor,
            ),
          );
          check();
          commit(true);
          await archive.mergeRemotePage(
            owner,
            peer,
            page,
            recovery: work,
            canApply: current,
          );
        }
        commit(false);
        check();
        work = (await archive.recoveryCheckpoint(owner))!;
        check();
        onProgress?.call(work);
      }
      if (await archive.recoveryNeedsRestart(owner, work)) {
        throw const TwitchWhisperException('恢復期間出現新收件缺口；已保存資料保留，請重新恢復全部對話。');
      }
      check();
      return work;
    } finally {
      running = false;
      committing = false;
      _cancellation = null;
      onState?.call();
    }
  }
}
