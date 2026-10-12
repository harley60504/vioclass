enum TwitchPlaybackViewerAuthState {
  anonymous,
  authenticated,
  storedTokenInvalid,
  clientMismatch,
  ownerUnavailable,
  ownerMismatch,
}

class TwitchPlaybackViewerAuth {
  final String clientId;
  final String accessToken;
  final String userId;
  final DateTime? expiresAt;

  const TwitchPlaybackViewerAuth({
    required this.clientId,
    required this.accessToken,
    required this.userId,
    this.expiresAt,
  });

  String get identityKey => '$clientId\n$userId\n$accessToken';
}

class TwitchPlaybackViewerAuthResolution {
  final TwitchPlaybackViewerAuthState state;
  final TwitchPlaybackViewerAuth? auth;

  const TwitchPlaybackViewerAuthResolution._(this.state, this.auth);

  const TwitchPlaybackViewerAuthResolution.anonymous()
    : this._(TwitchPlaybackViewerAuthState.anonymous, null);

  const TwitchPlaybackViewerAuthResolution.failed(
    TwitchPlaybackViewerAuthState state,
  ) : this._(state, null);

  TwitchPlaybackViewerAuthResolution.authenticated(
    TwitchPlaybackViewerAuth auth,
  ) : this._(TwitchPlaybackViewerAuthState.authenticated, auth);

  bool get hadUnavailableLogin =>
      state == TwitchPlaybackViewerAuthState.storedTokenInvalid ||
      state == TwitchPlaybackViewerAuthState.clientMismatch ||
      state == TwitchPlaybackViewerAuthState.ownerUnavailable ||
      state == TwitchPlaybackViewerAuthState.ownerMismatch;
}
