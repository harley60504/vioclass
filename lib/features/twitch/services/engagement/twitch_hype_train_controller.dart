import 'package:flutter/foundation.dart';

import '../../api/engagement/twitch_hype_train_api_service.dart';
import '../../models/engagement/twitch_hype_train.dart';

class TwitchHypeTrainController extends ChangeNotifier {
  final TwitchHypeTrainApiService api;

  TwitchHypeTrainSnapshot? snapshot;
  bool loading = false;
  Object? error;

  TwitchHypeTrainController({required this.api});

  Duration get remainingDuration {
    return snapshot?.remainingDuration ?? Duration.zero;
  }

  Future<void> refresh({
    required String channelLogin,
    String? channelId,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      clear();
      return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      final next = await api.getHypeTrainStatus(
        channelLogin: login,
        channelId: channelId,
      );
      if (next == null || next.isActive) {
        snapshot = next;
      } else {
        snapshot = null;
      }
    } catch (caughtError) {
      error = caughtError;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clear() {
    if (snapshot == null && !loading && error == null) return;
    snapshot = null;
    loading = false;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
