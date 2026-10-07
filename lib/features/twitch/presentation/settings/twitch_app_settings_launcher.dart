import 'dart:async';

import 'package:flutter/foundation.dart';

import 'vioclass_update_controller.dart';
import '../../services/chat/twitch_whisper_inbox_controller.dart';
import '../../services/notifications/twitch_app_notification_service.dart';

class TwitchAppSettingsLauncher extends ChangeNotifier {
  Future<void> Function()? _opener;
  Future<void> Function()? _updateOpener;
  Future<void> Function()? _whisperOpener;
  VioClassUpdateController? _updateController;
  TwitchWhisperInboxController? _whisperInbox;
  TwitchWhisperNotificationTarget? _pendingWhisper;
  TwitchWhisperNotificationTarget? _openingWhisper;
  bool _navigationReady = false;
  bool _drainScheduled = false;
  bool _disposed = false;

  void queueWhisperNotification(TwitchWhisperNotificationTarget target) {
    if (_disposed) return;
    if (_openingWhisper?.payload == target.payload) return;
    _pendingWhisper = target;
    _scheduleWhisperNotification();
  }

  void setNavigationReady(bool ready) {
    _navigationReady = ready;
    _scheduleWhisperNotification();
  }

  void _scheduleWhisperNotification() {
    if (_disposed || _drainScheduled) return;
    _drainScheduled = true;
    scheduleMicrotask(() {
      _drainScheduled = false;
      if (!_disposed) unawaited(_drainWhisperNotification());
    });
  }

  Future<void> _drainWhisperNotification() async {
    final inbox = _whisperInbox;
    final target = _pendingWhisper;
    if (target == null ||
        _openingWhisper != null ||
        !_navigationReady ||
        inbox == null ||
        _whisperOpener == null ||
        !inbox.sessionReady ||
        inbox.loading ||
        !inbox.appForeground) {
      return;
    }
    _pendingWhisper = null;
    _openingWhisper = target;
    try {
      await openWhisperConversation(
        ownerId: target.ownerId,
        peerId: target.peerId,
      );
    } on StateError catch (error) {
      if (!_disposed) {
        twitchAppNotificationCenter.showWarning(
          title: '無法開啟私訊',
          message: error.message.toString(),
        );
      }
    } catch (_) {
      if (!_disposed) {
        twitchAppNotificationCenter.showWarning(
          title: '無法開啟私訊',
          message: '請開啟私訊列表查看。',
        );
      }
    } finally {
      _openingWhisper = null;
      _scheduleWhisperNotification();
    }
  }

  bool get hasUpdate => _updateController?.hasUpdate == true;
  int get whisperUnreadCount => _whisperInbox?.unreadCount ?? 0;

  void attach(
    Future<void> Function() opener, {
    required VioClassUpdateController updateController,
    required Future<void> Function() updateOpener,
    Future<void> Function()? whisperOpener,
    TwitchWhisperInboxController? whisperInbox,
    bool navigationReady = true,
  }) {
    _updateController?.removeListener(_handleUpdateChanged);
    _whisperInbox?.removeListener(_handleUpdateChanged);
    _opener = opener;
    _updateOpener = updateOpener;
    _whisperOpener = whisperOpener;
    _updateController = updateController;
    updateController.addListener(_handleUpdateChanged);
    _whisperInbox = whisperInbox;
    whisperInbox?.addListener(_handleUpdateChanged);
    _navigationReady = navigationReady;
    _scheduleWhisperNotification();
  }

  void detach() {
    _navigationReady = false;
    _updateController?.removeListener(_handleUpdateChanged);
    _whisperInbox?.removeListener(_handleUpdateChanged);
    _whisperInbox = null;
    _updateController = null;
    _updateOpener = null;
    _whisperOpener = null;
    _opener = null;
  }

  void _handleUpdateChanged() {
    notifyListeners();
    _scheduleWhisperNotification();
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingWhisper = null;
    detach();
    super.dispose();
  }

  Future<void> openUpdate() async {
    await _updateOpener?.call();
  }

  Future<void> openWhispers() async {
    await _whisperOpener?.call();
  }

  Future<void> openWhisperConversation({
    required String ownerId,
    required String peerId,
  }) async {
    final inbox = _whisperInbox;
    final opener = _whisperOpener;
    if (inbox == null || opener == null || inbox.ownerId != ownerId) {
      throw StateError('私訊通知屬於其他帳號，請切回收件帳號。');
    }
    if (!inbox.conversations.any((peer) => peer.userId == peerId)) {
      throw StateError('這則私訊對話已不存在，請開啟私訊列表查看。');
    }
    await inbox.selectConversation(peerId);
    if (_whisperInbox != inbox ||
        _whisperOpener != opener ||
        inbox.ownerId != ownerId ||
        inbox.activePeerId != peerId ||
        !inbox.conversations.any((peer) => peer.userId == peerId)) {
      throw StateError('私訊帳號或對話已變更，未開啟通知。');
    }
    await opener();
  }

  Future<void> openWhisperTo(
    String login, {
    required String ownerId,
    String? peerId,
  }) async {
    final inbox = _whisperInbox;
    if (inbox == null || _whisperOpener == null || inbox.ownerId != ownerId) {
      throw StateError('私訊帳號尚未準備好或已變更。');
    }
    await inbox.startConversation(login);
    if (_whisperInbox != inbox || inbox.ownerId != ownerId) {
      throw StateError('登入帳號已變更，未開啟私訊。');
    }
    if (inbox.errorText != null) throw StateError(inbox.errorText!);
    final selected = inbox.conversations.where(
      (peer) => peer.userId == inbox.activePeerId,
    );
    if (selected.isEmpty ||
        selected.first.login.toLowerCase() != login.trim().toLowerCase()) {
      throw StateError('私訊對象尚未準備好，請稍後再試。');
    }
    if (peerId != null &&
        peerId.isNotEmpty &&
        selected.first.userId != peerId) {
      throw StateError('私訊對象與原本選取的使用者不符。');
    }
    await openWhispers();
  }

  Future<void> open() async {
    await _opener?.call();
  }
}

final TwitchAppSettingsLauncher twitchAppSettingsLauncher =
    TwitchAppSettingsLauncher();
