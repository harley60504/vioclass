import '../../api/playback/twitch_playback_viewer_auth.dart';

typedef TwitchPlaybackIntegrityAcquirer =
    Future<TwitchPlaybackIntegrityContext> Function({
      required String clientId,
      required String channelLogin,
      required TwitchPlaybackViewerAuth? viewerAuth,
    });

class TwitchPlaybackIntegrityContext {
  final String clientId;
  final String token;
  final String deviceId;
  final String userAgent;
  final DateTime expiresAt;
  final String identityKey;

  const TwitchPlaybackIntegrityContext({
    required this.clientId,
    required this.token,
    required this.deviceId,
    required this.userAgent,
    required this.expiresAt,
    required this.identityKey,
  });

  Map<String, String> headersFor({
    required String expectedClientId,
    required String expectedIdentityKey,
  }) {
    final cleanClientId = expectedClientId.trim();
    if (cleanClientId.isEmpty ||
        cleanClientId != clientId ||
        expectedIdentityKey != identityKey) {
      throw StateError('Playback integrity context client does not match.');
    }
    if (token.trim().isEmpty ||
        deviceId.trim().isEmpty ||
        userAgent.trim().isEmpty) {
      throw StateError('Playback integrity context is incomplete.');
    }
    return <String, String>{
      'Client-Integrity': token,
      'X-Device-ID': deviceId,
      'User-Agent': userAgent,
    };
  }
}

/// Owns playback verification, isolated by viewer session.
///
/// Contexts are never shared with whisper/Drops requests and are kept in memory.
/// A browser is started only after the playback endpoint explicitly rejects an
/// unverified or cached context.
class TwitchPlaybackIntegrityManager {
  final TwitchPlaybackIntegrityAcquirer acquire;
  final DateTime Function() now;
  final Duration refreshSkew;

  TwitchPlaybackIntegrityManager({
    required this.acquire,
    DateTime Function()? now,
    this.refreshSkew = const Duration(seconds: 30),
  }) : now = now ?? (() => DateTime.now().toUtc());

  final Map<String, TwitchPlaybackIntegrityContext> _contexts =
      <String, TwitchPlaybackIntegrityContext>{};
  final Map<String, Future<TwitchPlaybackIntegrityContext>> _pending =
      <String, Future<TwitchPlaybackIntegrityContext>>{};
  final Map<String, int> _generations = <String, int>{};

  Map<String, String>? cachedHeadersFor({
    required String clientId,
    required TwitchPlaybackViewerAuth? viewerAuth,
  }) {
    final key = _key(clientId, viewerAuth);
    final context = _contexts[key];
    if (context == null || !_isUsable(context)) return null;
    return context.headersFor(
      expectedClientId: clientId.trim(),
      expectedIdentityKey: _identityKey(viewerAuth),
    );
  }

  Future<Map<String, String>> headersFor({
    required String clientId,
    required String channelLogin,
    required TwitchPlaybackViewerAuth? viewerAuth,
  }) async {
    final cleanClientId = clientId.trim();
    final key = _key(cleanClientId, viewerAuth);
    final channel = channelLogin.trim().toLowerCase();
    if (cleanClientId.isEmpty || channel.isEmpty) {
      throw ArgumentError(
        'Playback integrity client and channel are required.',
      );
    }

    final cached = cachedHeadersFor(
      clientId: cleanClientId,
      viewerAuth: viewerAuth,
    );
    if (cached != null) return cached;

    final existing = _pending[key];
    if (existing != null) {
      return (await existing).headersFor(
        expectedClientId: cleanClientId,
        expectedIdentityKey: _identityKey(viewerAuth),
      );
    }

    final generation = _generations[key] ?? 0;
    // Share the validated result, not the raw browser response. Every waiter
    // must observe expiry and generation failures (including clear()).
    final pending = () async {
      final context = await acquire(
        clientId: cleanClientId,
        channelLogin: channel,
        viewerAuth: viewerAuth,
      );
      context.headersFor(
        expectedClientId: cleanClientId,
        expectedIdentityKey: _identityKey(viewerAuth),
      );
      if (!_isUsable(context)) {
        throw StateError('Playback integrity context is already expired.');
      }
      if ((_generations[key] ?? 0) != generation) {
        throw StateError('Playback integrity context changed while acquiring.');
      }
      _contexts[key] = context;
      return context;
    }();
    _pending[key] = pending;
    try {
      return (await pending).headersFor(
        expectedClientId: cleanClientId,
        expectedIdentityKey: _identityKey(viewerAuth),
      );
    } finally {
      if (identical(_pending[key], pending)) _pending.remove(key);
    }
  }

  void invalidateRejected({
    required String clientId,
    required TwitchPlaybackViewerAuth? viewerAuth,
    required String rejectedIntegrity,
  }) {
    final key = _key(clientId, viewerAuth);
    final current = _contexts[key];
    if (current == null || current.token != rejectedIntegrity) return;
    _generations[key] = (_generations[key] ?? 0) + 1;
    _contexts.remove(key);
  }

  void clear() {
    final keys = <String>{..._contexts.keys, ..._pending.keys};
    for (final key in keys) {
      _generations[key] = (_generations[key] ?? 0) + 1;
    }
    _contexts.clear();
  }

  bool _isUsable(TwitchPlaybackIntegrityContext context) =>
      context.expiresAt.isAfter(now().toUtc().add(refreshSkew));

  String _key(String clientId, TwitchPlaybackViewerAuth? viewerAuth) =>
      '${clientId.trim()}\n${_identityKey(viewerAuth)}';

  String _identityKey(TwitchPlaybackViewerAuth? viewerAuth) =>
      viewerAuth?.identityKey ?? 'anonymous';
}
