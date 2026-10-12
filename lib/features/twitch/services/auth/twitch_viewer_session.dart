import 'package:flutter/foundation.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../api/core/twitch_api_exception.dart';
import 'twitch_auth_service.dart';

enum TwitchViewerStatus { checking, guest, authenticated }

class TwitchViewerAuthSnapshot {
  final String accessToken;
  final String clientId;
  final String viewerId;
  final String viewerLogin;
  final List<String> scopes;

  const TwitchViewerAuthSnapshot({
    required this.accessToken,
    required this.clientId,
    required this.viewerId,
    required this.viewerLogin,
    required this.scopes,
  });

  bool get canReadFollows => scopes.contains('user:read:follows');
}

/// One in-memory identity decision per account service, shared by its routes.
/// Does not load, save, refresh or revoke credentials itself.
class TwitchViewerSession extends ChangeNotifier {
  static final _sessions = Expando<TwitchViewerSession>();
  factory TwitchViewerSession.forAuth(TwitchAuthService auth) =>
      _sessions[auth] ??= TwitchViewerSession._(auth);

  TwitchViewerSession._(this.auth)
    : _token = auth.accessToken,
      _status = auth.accessToken?.trim().isNotEmpty == true
          ? TwitchViewerStatus.checking
          : TwitchViewerStatus.guest {
    auth.addListener(_onAuthChanged);
  }

  final TwitchAuthService auth;
  String? _token;
  int _generation = 0;
  TwitchViewerStatus _status;
  TwitchViewerAuthSnapshot? _snapshot;
  Future<TwitchViewerAuthSnapshot?>? _pending;

  void _sync() {
    final token = auth.accessToken;
    if (_token == token) return;
    _token = token;
    _generation++;
    _snapshot = null;
    _pending = null;
    _status = token?.trim().isNotEmpty == true
        ? TwitchViewerStatus.checking
        : TwitchViewerStatus.guest;
  }

  void _onAuthChanged() {
    _sync();
    notifyListeners();
  }

  TwitchViewerStatus get status {
    _sync();
    return _status;
  }

  /// Changes when identity is replaced or invalidated, not when its pending
  /// validation succeeds. Consumers can supersede old work without seeing tokens.
  int get identityRevision {
    _sync();
    return _generation;
  }

  TwitchViewerAuthSnapshot? get snapshot {
    _sync();
    return _snapshot;
  }

  bool get hasAccount =>
      status != TwitchViewerStatus.guest &&
      auth.accessToken?.trim().isNotEmpty == true;

  void invalidate() {
    _sync();
    _generation++;
    _snapshot = null;
    _pending = null;
    _status = auth.accessToken?.trim().isNotEmpty == true
        ? TwitchViewerStatus.checking
        : TwitchViewerStatus.guest;
  }

  Future<TwitchViewerAuthSnapshot?> resolve(
    TwitchAuthApiService api, {
    bool forceValidate = false,
  }) async {
    final token = await auth.getValidAccessToken();
    _sync();
    if (token == null || token.trim().isEmpty) {
      invalidate();
      return null;
    }
    if (token != auth.accessToken) return null;
    if (!forceValidate && _snapshot != null) return _snapshot;
    if (_pending != null) return _pending;
    final generation = _generation;
    final request = _validate(api, token, generation);
    _pending = request;
    try {
      return await request;
    } finally {
      if (identical(_pending, request)) _pending = null;
    }
  }

  Future<TwitchViewerAuthSnapshot?> _validate(
    TwitchAuthApiService api,
    String token,
    int generation,
  ) async {
    try {
      final validation = await api.validateToken(token);
      _sync();
      if (generation != _generation || token != auth.accessToken) return null;
      _snapshot = TwitchViewerAuthSnapshot(
        accessToken: token,
        clientId: validation.clientId.trim().isNotEmpty
            ? validation.clientId.trim()
            : auth.clientId?.trim().isNotEmpty == true
            ? auth.clientId!.trim()
            : TwitchApiConstants.twitchWebClientId,
        viewerId: validation.userId,
        viewerLogin: validation.login,
        scopes: List.unmodifiable(validation.scopes),
      );
      _status = TwitchViewerStatus.authenticated;
      notifyListeners();
      return _snapshot;
    } on TwitchApiException catch (error) {
      _sync();
      if (generation != _generation || token != auth.accessToken) return null;
      if (error.statusCode != 401 && error.statusCode != 403) rethrow;
      _snapshot = null;
      _status = TwitchViewerStatus.guest;
      notifyListeners();
      return null;
    }
  }
}
