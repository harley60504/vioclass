import 'package:flutter/foundation.dart';

import '../../api/bootstrap/twitch_api_bootstrap_service.dart';
import '../../models/bootstrap/twitch_api_bootstrap.dart';

class TwitchChannelRuntime extends ChangeNotifier {
  final TwitchApiBootstrapService bootstrapApi;

  TwitchChannelRuntime({required this.bootstrapApi});

  String _channelLogin = '';
  TwitchApiBootstrapSnapshot? _snapshot;
  bool _loading = false;
  Object? _error;

  String get channelLogin => _channelLogin;
  TwitchApiBootstrapSnapshot? get snapshot => _snapshot;
  bool get loading => _loading;
  Object? get error => _error;

  bool get hasSnapshot => _snapshot != null;

  Future<TwitchApiBootstrapSnapshot?> loadChannel({
    required String channelLogin,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channelLogin cannot be empty',
      );
    }

    _channelLogin = login;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final loaded = await bootstrapApi.bootstrapChannel(channelLogin: login);
      _snapshot = loaded;
      return loaded;
    } catch (e) {
      _snapshot = null;
      _error = e;
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _channelLogin = '';
    _snapshot = null;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'loading': loading,
      'hasSnapshot': hasSnapshot,
      'error': error?.toString(),
      'snapshot': snapshot?.toJson(),
    };
  }
}
