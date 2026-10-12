import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/playback/twitch_playback_viewer_auth.dart';

typedef TwitchPlaybackStoredTokenProvider = Future<String?> Function();
typedef TwitchPlaybackStoredClientIdProvider = String Function();
typedef TwitchPlaybackTokenValidator =
    Future<TwitchTokenValidation> Function(String token);

/// Resolves a Web-client viewer session without changing any token storage.
class TwitchPlaybackViewerAuthResolver {
  final String expectedClientId;
  final TwitchPlaybackStoredTokenProvider tokenProvider;
  final TwitchPlaybackStoredTokenProvider ownerTokenProvider;
  final TwitchPlaybackStoredClientIdProvider clientIdProvider;
  final TwitchPlaybackTokenValidator validate;
  final TwitchPlaybackTokenValidator validateOwner;
  final DateTime Function() now;
  final Duration validationTtl;
  final Duration failureTtl;

  TwitchPlaybackViewerAuthResolver({
    required this.expectedClientId,
    required this.tokenProvider,
    required this.ownerTokenProvider,
    required this.clientIdProvider,
    required this.validate,
    required this.validateOwner,
    DateTime Function()? now,
    this.validationTtl = const Duration(minutes: 5),
    this.failureTtl = const Duration(seconds: 30),
  }) : now = now ?? (() => DateTime.now().toUtc());

  String? _cachedKey;
  TwitchPlaybackViewerAuthResolution? _cached;
  DateTime? _cachedUntil;
  String? _pendingKey;
  Future<TwitchPlaybackViewerAuthResolution>? _pending;

  Future<TwitchPlaybackViewerAuthResolution> resolve() async {
    final token = (await tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      _clearCache();
      return const TwitchPlaybackViewerAuthResolution.anonymous();
    }
    final storedClientId = clientIdProvider().trim();
    if (storedClientId != expectedClientId) {
      _clearCache();
      return const TwitchPlaybackViewerAuthResolution.failed(
        TwitchPlaybackViewerAuthState.clientMismatch,
      );
    }
    final ownerToken = (await ownerTokenProvider())?.trim();
    if (ownerToken == null || ownerToken.isEmpty) {
      _clearCache();
      return const TwitchPlaybackViewerAuthResolution.failed(
        TwitchPlaybackViewerAuthState.ownerUnavailable,
      );
    }
    final key = '$token\n$ownerToken';
    final cached = _cached;
    final cachedUntil = _cachedUntil;
    if (_cachedKey == key &&
        cached != null &&
        cachedUntil != null &&
        cachedUntil.isAfter(now().toUtc())) {
      return cached;
    }
    if (_pendingKey == key && _pending != null) return _pending!;

    final pending = _validate(token, ownerToken);
    _pendingKey = key;
    _pending = pending;
    try {
      final result = await pending;
      _cachedKey = key;
      _cached = result;
      final current = now().toUtc();
      final maximum = current.add(
        result.auth == null ? failureTtl : validationTtl,
      );
      final tokenDeadline = result.auth?.expiresAt?.subtract(
        const Duration(seconds: 30),
      );
      _cachedUntil = tokenDeadline != null && tokenDeadline.isBefore(maximum)
          ? tokenDeadline
          : maximum;
      return result;
    } finally {
      if (identical(_pending, pending)) {
        _pending = null;
        _pendingKey = null;
      }
    }
  }

  Future<TwitchPlaybackViewerAuthResolution> _validate(
    String token,
    String ownerToken,
  ) async {
    try {
      final validations = await Future.wait<TwitchTokenValidation>(
        <Future<TwitchTokenValidation>>[
          validate(token),
          validateOwner(ownerToken),
        ],
      );
      final validation = validations[0];
      final ownerValidation = validations[1];
      if (validation.clientId.trim() != expectedClientId) {
        return const TwitchPlaybackViewerAuthResolution.failed(
          TwitchPlaybackViewerAuthState.clientMismatch,
        );
      }
      final userId = validation.userId.trim();
      if (userId.isEmpty || validation.expiresIn <= 30) {
        return const TwitchPlaybackViewerAuthResolution.failed(
          TwitchPlaybackViewerAuthState.storedTokenInvalid,
        );
      }
      if (ownerValidation.userId.trim().isEmpty ||
          ownerValidation.expiresIn <= 30) {
        return const TwitchPlaybackViewerAuthResolution.failed(
          TwitchPlaybackViewerAuthState.ownerUnavailable,
        );
      }
      if (ownerValidation.userId.trim() != userId) {
        return const TwitchPlaybackViewerAuthResolution.failed(
          TwitchPlaybackViewerAuthState.ownerMismatch,
        );
      }
      final shortestExpiry = validation.expiresIn < ownerValidation.expiresIn
          ? validation.expiresIn
          : ownerValidation.expiresIn;
      return TwitchPlaybackViewerAuthResolution.authenticated(
        TwitchPlaybackViewerAuth(
          clientId: expectedClientId,
          accessToken: token,
          userId: userId,
          expiresAt: now().toUtc().add(Duration(seconds: shortestExpiry)),
        ),
      );
    } catch (_) {
      return const TwitchPlaybackViewerAuthResolution.failed(
        TwitchPlaybackViewerAuthState.storedTokenInvalid,
      );
    }
  }

  void clear() => _clearCache();

  void _clearCache() {
    _cachedKey = null;
    _cached = null;
    _cachedUntil = null;
  }
}
