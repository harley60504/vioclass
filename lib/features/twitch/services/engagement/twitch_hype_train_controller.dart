import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../api/engagement/twitch_hype_train_api_service.dart';
import '../../models/engagement/twitch_hype_train.dart';

class TwitchHypeTrainController extends ChangeNotifier {
  final TwitchHypeTrainApiService api;
  final bool Function(String channelLogin)? isCurrentChannel;

  TwitchHypeTrainSnapshot? snapshot;
  bool loading = false;
  Object? error;
  int _refreshSerial = 0;
  bool _disposed = false;
  Timer? _pollTimer;
  String _pollLogin = '';

  void startPolling({
    required String channelLogin,
    String? channelId,
    required bool Function() shouldPoll,
  }) {
    final login = channelLogin.trim().toLowerCase();
    if (_disposed || login.isEmpty) return;
    if (_pollLogin == login && _pollTimer?.isActive == true) return;
    _pollTimer?.cancel();
    _pollLogin = login;
    void schedule() {
      if (_disposed || _pollLogin != login) return;
      final active = snapshot?.isActive == true && error == null;
      final seconds = active ? (snapshot!.progressRatio > 0.85 ? 1 : 3) : 15;
      _pollTimer = Timer(Duration(seconds: seconds), () async {
        if (_disposed || _pollLogin != login || !shouldPoll()) return;
        if (!loading) await refresh(channelLogin: login, channelId: channelId);
        schedule();
      });
    }

    schedule();
  }

  TwitchHypeTrainController({required this.api, this.isCurrentChannel});

  Duration get remainingDuration {
    return snapshot?.remainingDuration ?? Duration.zero;
  }

  Future<void> refresh({
    required String channelLogin,
    String? channelId,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    final serial = ++_refreshSerial;
    if (login.isEmpty) {
      clear();
      return;
    }

    loading = true;
    error = null;
    _notifyIfAlive();

    try {
      final next = await api.getHypeTrainStatus(
        channelLogin: login,
        channelId: channelId,
      );
      if (!_isCurrentRefresh(serial, login)) return;
      final previous = snapshot;
      if (next == null || next.isActive) {
        snapshot =
            next != null &&
                previous?.id == next.id &&
                previous?.isGoldenKappa == true
            ? next.copyWith(isGoldenKappa: true)
            : next;
      } else {
        snapshot = null;
      }
    } catch (caughtError) {
      if (!_isCurrentRefresh(serial, login)) return;
      error = caughtError;
    } finally {
      if (_isCurrentRefresh(serial, login)) {
        loading = false;
        _notifyIfAlive();
      }
    }
  }

  void clear() {
    _pollTimer?.cancel();
    _pollLogin = '';
    if (snapshot == null && !loading && error == null) return;
    _refreshSerial++;
    snapshot = null;
    loading = false;
    error = null;
    _notifyIfAlive();
  }

  bool _isCurrentRefresh(int serial, String login) {
    return !_disposed &&
        serial == _refreshSerial &&
        (isCurrentChannel?.call(login) ?? true);
  }

  void _notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _refreshSerial++;
    snapshot = null;
    loading = false;
    error = null;
    super.dispose();
  }
}
