import 'package:flutter/foundation.dart';

import '../../api/moderation/twitch_moderation_api_service.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../models/chat/twitch_chat_message.dart';
import '../../models/chat/twitch_moderation_target_policy.dart';

enum TwitchModerationBatchResult {
  pending,
  submitting,
  submitted,
  rejected,
  unknown,
}

class TwitchModerationDeleteTarget {
  final String messageId;
  final String userId;
  final String displayName;
  final String text;
  TwitchModerationDeleteTarget._(TwitchChatRuntimeMessage message)
    : messageId = message.source.tags['id']!.trim(),
      userId = message.source.tags['user-id'] ?? '',
      displayName = message.displayName,
      text = message.message;
}

/// A fixed preview, not permission to act without explicit UI confirmation.
class TwitchModerationDeletePlan {
  final List<TwitchModerationDeleteTarget> messages;
  final int excluded;
  TwitchModerationDeletePlan._(
    List<TwitchModerationDeleteTarget> messages,
    this.excluded,
  ) : messages = List.unmodifiable(messages);
}

enum TwitchModerationUserBatchAction { timeout, warn }

class TwitchModerationUserTarget {
  final String userId;
  final String displayName;
  final String exampleText;
  TwitchModerationUserTarget._(TwitchChatRuntimeMessage message)
    : userId = message.source.tags['user-id']!,
      displayName = message.displayName,
      exampleText = message.message;
}

class TwitchModerationUserPlan {
  final List<TwitchModerationUserTarget> users;
  final TwitchModerationUserBatchAction action;
  final String reason;
  final int? seconds;
  final int excluded;
  TwitchModerationUserPlan._(
    List<TwitchModerationUserTarget> users,
    this.action,
    this.reason,
    this.seconds,
    this.excluded,
  ) : users = List.unmodifiable(users);
}

/// Serial official-message deletion. No clear-chat fallback, retry or undo.
class TwitchModerationBatchController extends ChangeNotifier {
  final TwitchModerationApiService api;
  final bool Function() canModerate;
  final Future<void> Function(Duration) _wait;
  Object? _plan;
  final Map<String, TwitchModerationBatchResult> _results = {};
  bool _consumed = false;
  bool _cancelled = false;
  bool _disposed = false;
  bool _running = false;
  String? _problem;

  TwitchModerationBatchController({
    required this.api,
    required this.canModerate,
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? ((duration) => Future<void>.delayed(duration));

  bool get running => _running;
  bool get cancelled => _cancelled;
  String? get problem => _problem;
  Map<String, TwitchModerationBatchResult> get results =>
      Map.unmodifiable(_results);

  TwitchModerationDeletePlan prepareDelete(
    List<TwitchChatRuntimeMessage> selected,
  ) {
    if (_disposed || _running || !canModerate()) {
      throw const TwitchModerationException('管理身分已變更或批次操作正在處理。');
    }
    if (selected.length > 50) {
      throw const TwitchModerationException('一次最多預覽 50 則訊息，請縮小選取範圍。');
    }
    final eligible = <String, TwitchModerationDeleteTarget>{};
    var excluded = 0;
    for (final message in selected) {
      if (!TwitchModerationTargetPolicy.canDelete(message, api.broadcasterId)) {
        excluded++;
        continue;
      }
      final id = message.source.tags['id']!.trim();
      final previous = eligible[id];
      if (previous != null) {
        if (previous.text != message.message ||
            previous.userId != message.source.tags['user-id']) {
          throw const TwitchModerationException('相同訊息 ID 的資料不一致，未建立批次操作。');
        }
        excluded++;
        continue;
      }
      eligible[id] = TwitchModerationDeleteTarget._(message);
    }
    final plan = TwitchModerationDeletePlan._(
      eligible.values.toList(),
      excluded,
    );
    _reset(plan, eligible.keys);
    return plan;
  }

  TwitchModerationUserPlan prepareUsers(
    List<TwitchChatRuntimeMessage> selected, {
    required TwitchModerationUserBatchAction action,
    required String reason,
    int? seconds,
  }) {
    if (_disposed || _running || !canModerate()) {
      throw const TwitchModerationException('管理身分已變更或批次操作正在處理。');
    }
    final normalized = reason.trim();
    if (selected.length > 50 ||
        normalized.length > 500 ||
        (action == TwitchModerationUserBatchAction.warn &&
            (normalized.isEmpty || seconds != null)) ||
        (action == TwitchModerationUserBatchAction.timeout &&
            (seconds == null || seconds < 1 || seconds > 1209600))) {
      throw const TwitchModerationException(
        '批次警告需 1–500 字原因；禁言需 1–1209600 秒，一次最多選取 50 則。',
      );
    }
    // A contradictory local role hint must not be lost through user deduplication.
    final protected = <String>{
      for (final message in selected)
        if (TwitchModerationTargetPolicy.sameChannel(
              message,
              api.broadcasterId,
            ) &&
            !TwitchModerationTargetPolicy.canManageUser(
              message,
              broadcasterId: api.broadcasterId,
              moderatorId: api.moderatorId,
            ))
          message.source.tags['user-id'] ?? '',
    };
    final users = <String, TwitchModerationUserTarget>{};
    var excluded = 0;
    for (final message in selected) {
      final id = message.source.tags['user-id'] ?? '';
      if (protected.contains(id) ||
          users.containsKey(id) ||
          message.source.source == TwitchChatMessageSource.localEcho ||
          message.source.source == TwitchChatMessageSource.synthetic ||
          !message.source.isPrivMsg ||
          !TwitchModerationTargetPolicy.canManageUser(
            message,
            broadcasterId: api.broadcasterId,
            moderatorId: api.moderatorId,
          )) {
        excluded++;
        continue;
      }
      users[id] = TwitchModerationUserTarget._(message);
    }
    final plan = TwitchModerationUserPlan._(
      users.values.toList(),
      action,
      normalized,
      seconds,
      excluded,
    );
    _reset(plan, users.keys);
    return plan;
  }

  void _reset(Object plan, Iterable<String> ids) {
    _plan = plan;
    _consumed = false;
    _cancelled = false;
    _problem = null;
    _results.clear();
    for (final id in ids) {
      _results[id] = TwitchModerationBatchResult.pending;
    }
    _publish();
  }

  Future<void> executeDelete(TwitchModerationDeletePlan confirmedPlan) =>
      _execute(
        confirmedPlan,
        confirmedPlan.messages.map((target) => target.messageId).toList(),
        (id) => api.deleteMessages(messageId: id),
      );

  Future<void> executeUsers(
    TwitchModerationUserPlan confirmedPlan, {
    required bool Function(String userId) canManageTarget,
  }) => _execute(
    confirmedPlan,
    confirmedPlan.users.map((target) => target.userId).toList(),
    (id) async {
      if (!canManageTarget(id)) {
        throw const TwitchModerationException('對象身分已變更或無法確認，已停止後續操作。');
      }
      if (confirmedPlan.action == TwitchModerationUserBatchAction.warn) {
        await api.warn(id, reason: confirmedPlan.reason);
      } else {
        await api.ban(
          id,
          seconds: confirmedPlan.seconds,
          reason: confirmedPlan.reason,
        );
      }
    },
  );

  Future<void> _execute(
    Object confirmedPlan,
    List<String> targets,
    Future<void> Function(String) submit,
  ) async {
    if (_disposed ||
        _running ||
        _consumed ||
        !identical(confirmedPlan, _plan)) {
      return;
    }
    _consumed = true;
    _running = true;
    _publish();
    try {
      for (var index = 0; index < targets.length; index++) {
        if (index > 0) await _wait(const Duration(milliseconds: 350));
        if (_disposed || _cancelled) break;
        if (!canModerate()) {
          _problem = '管理身分或頻道已變更，未送出剩餘操作。';
          break;
        }
        final id = targets[index];
        _results[id] = TwitchModerationBatchResult.submitting;
        _publish();
        try {
          await submit(id);
          _results[id] = TwitchModerationBatchResult.submitted;
        } on TwitchModerationException catch (error) {
          _results[id] = TwitchModerationBatchResult.rejected;
          _problem = error.message;
          break;
        } catch (_) {
          _results[id] = TwitchModerationBatchResult.unknown;
          _problem = '這筆操作結果不明，已停止批次；請先核對 Twitch 狀態，勿直接重送。';
          break;
        }
        _publish();
      }
    } finally {
      _running = false;
      _publish();
    }
  }

  /// In-flight requests cannot be undone; only subsequent entries are stopped.
  void cancelRemaining() {
    _cancelled = true;
    _publish();
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _cancelled = true;
    _disposed = true;
    super.dispose();
  }
}
