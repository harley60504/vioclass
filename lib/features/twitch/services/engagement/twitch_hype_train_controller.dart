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
      if (next == null || next.isActive) {
        snapshot = next;
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
    _refreshSerial++;
    snapshot = null;
    loading = false;
    error = null;
    super.dispose();
  }
}
