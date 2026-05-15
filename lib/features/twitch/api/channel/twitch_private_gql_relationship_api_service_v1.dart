// PATCH VERSION: streamnook_relationship_token_split_v15
// StreamNook-aligned Twitch relationship API service.
//
// Notes:
// - Follow status uses the main OAuth token and Helix /channels/followed first.
// - Follow / unfollow now mirrors the provided StreamNook twitch_service.rs:
//   DropsAuthService token + TWITCH_ANDROID_CLIENT_ID + OAuth prefix + APQ hashes.
// - Do not use full mutation query fallback for follow / unfollow.
// - v13 reads the same SharedPreferences keys as TwitchDropsAuthService when
//   constructor providers are missing or not wired correctly.
// - v15 removes legacy Web-token fallback. Follow / Unfollow can only use Drops Android token sources.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_api_exception.dart';

/// Token provider for Twitch OAuth / Web tokens.
typedef TwitchRelationshipTokenProvider = Future<String?> Function();

typedef TwitchRelationshipStringProvider = Future<String?> Function();

class _StreamNookDropsPrefsKeys {
  static const String tokenStorageKey = 'new_twitch_app_twitch_drops_token';
  static const String clientIdStorageKey = 'new_twitch_app_twitch_drops_client_id';
}

class TwitchPrivateGqlRelationshipSnapshot {
  final String userId;
  final String login;
  final String displayName;
  final bool isFollowing;
  final DateTime? followedAt;

  const TwitchPrivateGqlRelationshipSnapshot({
    required this.userId,
    required this.login,
    required this.displayName,
    required this.isFollowing,
    this.followedAt,
  });

  bool get hasUser => userId.trim().isNotEmpty;

  factory TwitchPrivateGqlRelationshipSnapshot.empty(String login) {
    return TwitchPrivateGqlRelationshipSnapshot(
      userId: '',
      login: login.trim().toLowerCase(),
      displayName: login.trim(),
      isFollowing: false,
    );
  }

  TwitchPrivateGqlRelationshipSnapshot copyWith({
    String? userId,
    String? login,
    String? displayName,
    bool? isFollowing,
    DateTime? followedAt,
  }) {
    return TwitchPrivateGqlRelationshipSnapshot(
      userId: userId ?? this.userId,
      login: login ?? this.login,
      displayName: displayName ?? this.displayName,
      isFollowing: isFollowing ?? this.isFollowing,
      followedAt: followedAt ?? this.followedAt,
    );
  }
}

class _TwitchRelationshipUserLite {
  final String id;
  final String login;
  final String displayName;

  const _TwitchRelationshipUserLite({
    required this.id,
    required this.login,
    required this.displayName,
  });

  bool get hasId => id.trim().isNotEmpty;
}

class _TwitchRelationshipAuthCandidate {
  final String token;
  final String authorizationPrefix;
  final String clientId;
  final String label;
  final String tokenSource;
  final String clientIdSource;
  final String? validateSummary;
  final bool blocked;
  final String? blockReason;

  const _TwitchRelationshipAuthCandidate({
    required this.token,
    required this.authorizationPrefix,
    required this.clientId,
    required this.label,
    required this.tokenSource,
    required this.clientIdSource,
    this.validateSummary,
    this.blocked = false,
    this.blockReason,
  });

  Map<String, String> gqlHeaders() {
    return <String, String>{
      ...TwitchApiConstants.twitchWebHeaders,
      'Client-Id': clientId,
      'Content-Type': 'application/json',
      'Accept': '*/*',
      'Authorization': '$authorizationPrefix $token',
    };
  }
}

/// Backward-compatible class name used by the current WatchPage.

class _RelationshipValueSource<T> {
  final T value;
  final String source;

  const _RelationshipValueSource(this.value, this.source);
}

class _TokenValidationDetails {
  final String clientId;
  final String login;
  final String userId;
  final String scopesText;
  final String error;

  const _TokenValidationDetails({
    required this.clientId,
    required this.login,
    required this.userId,
    required this.scopesText,
    this.error = '',
  });

  bool get isValid => error.isEmpty;
  bool get hasClientId => clientId.trim().isNotEmpty;

  String toSummary() {
    if (!isValid) return 'validate failed: $error';
    return 'validate: client_id=$clientId login=$login user_id=$userId scopes=[$scopesText]';
  }
}

class TwitchPrivateGqlRelationshipApiServiceV1 {
  final TwitchApiClient client;

  /// Main app OAuth token. Used for Helix /channels/followed status checks.
  final TwitchRelationshipTokenProvider? oauthTokenProvider;

  /// StreamNook-compatible Drops / Android token provider.
  ///
  /// Important: v15 no longer treats [webTokenProvider] as a Drops fallback.
  /// Relationship mutations must not consume kimne/Web tokens.
  final TwitchRelationshipTokenProvider? dropsTokenProvider;

  /// Legacy constructor slot retained for older call sites only. It is ignored
  /// for follow / unfollow to prevent Web token pollution.
  final TwitchRelationshipTokenProvider? webTokenProvider;

  /// Legacy alias retained for older call sites.
  final TwitchRelationshipTokenProvider? fallbackTokenProvider;

  /// Main app Client-ID used with Helix. Prefer TwitchAuthService.clientId.
  final TwitchRelationshipStringProvider? oauthClientIdProvider;

  /// StreamNook-compatible Android / Drops Client-ID provider.
  final TwitchRelationshipStringProvider? dropsClientIdProvider;

  /// Twitch Web GQL Client-ID, used only for read-only fallback GQL queries.
  final String gqlClientId;

  /// APQ hashes captured from the StreamNook twitch_service.rs supplied by the user.
  /// Build-time defines can override these if Twitch rotates the hashes.
  static const String _followApqHash = String.fromEnvironment(
    'TWITCH_FOLLOW_APQ_HASH',
    defaultValue: '800e7346bdf7e5278a3c1d3f21b2b56e2639928f86815677a7126b093b2fdd08',
  );
  static const String _unfollowApqHash = String.fromEnvironment(
    'TWITCH_UNFOLLOW_APQ_HASH',
    defaultValue: 'f7dae976ebf41c755ae2d758546bfd176b4eeb856656098bb40e0a672ca0d880',
  );

  static final Map<String, String> _runtimeApqHashCache = <String, String>{};
  static final Map<String, String> _runtimeApqDiscoveryDebug = <String, String>{};
  static bool _apqDiscoveryFailedRecently = false;

  /// Last APQ discovery summary. Useful when the UI only shows a compact error.
  static Map<String, String> get lastApqDiscoveryDebug =>
      Map<String, String>.unmodifiable(_runtimeApqDiscoveryDebug);

  const TwitchPrivateGqlRelationshipApiServiceV1({
    required this.client,
    this.oauthTokenProvider,
    this.dropsTokenProvider,
    this.webTokenProvider,
    this.fallbackTokenProvider,
    this.oauthClientIdProvider,
    this.dropsClientIdProvider,
    this.gqlClientId = TwitchApiConstants.twitchWebClientId,
  });

  Future<TwitchPrivateGqlRelationshipSnapshot> fetchRelationship({
    required String channelLogin,
    String? targetUserId,
    String? viewerUserId,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      return TwitchPrivateGqlRelationshipSnapshot.empty(login);
    }

    final target = await _resolveUserByLoginOrId(
      channelLogin: login,
      targetUserId: targetUserId,
    );

    if (!target.hasId) {
      return TwitchPrivateGqlRelationshipSnapshot.empty(login);
    }

    final following = await _checkFollowingByHelix(
      targetUserId: target.id,
      viewerUserId: viewerUserId,
    );

    if (following != null) {
      return TwitchPrivateGqlRelationshipSnapshot(
        userId: target.id,
        login: target.login.isNotEmpty ? target.login : login,
        displayName: target.displayName.isNotEmpty ? target.displayName : login,
        isFollowing: following,
      );
    }

    final fallbackFollowing = await _checkFollowingByGql(
      channelLogin: target.login.isNotEmpty ? target.login : login,
    );

    return TwitchPrivateGqlRelationshipSnapshot(
      userId: target.id,
      login: target.login.isNotEmpty ? target.login : login,
      displayName: target.displayName.isNotEmpty ? target.displayName : login,
      isFollowing: fallbackFollowing ?? false,
    );
  }

  Future<TwitchPrivateGqlRelationshipSnapshot> followChannel({
    required String channelLogin,
    String? targetUserId,
    String? viewerUserId,
  }) async {
    final target = await _resolveUserByLoginOrId(
      channelLogin: channelLogin,
      targetUserId: targetUserId,
    );
    if (!target.hasId) {
      throw TwitchApiException(
        '無法取得 $channelLogin 的 user id，不能送出 follow。',
      );
    }

    await _sendFollowMutation(target.id, channelLogin: channelLogin);

    return fetchRelationship(
      channelLogin: channelLogin,
      targetUserId: target.id,
      viewerUserId: viewerUserId,
    );
  }

  Future<TwitchPrivateGqlRelationshipSnapshot> unfollowChannel({
    required String channelLogin,
    String? targetUserId,
    String? viewerUserId,
  }) async {
    final target = await _resolveUserByLoginOrId(
      channelLogin: channelLogin,
      targetUserId: targetUserId,
    );
    if (!target.hasId) {
      throw TwitchApiException(
        '無法取得 $channelLogin 的 user id，不能送出 unfollow。',
      );
    }

    await _sendUnfollowMutation(target.id, channelLogin: channelLogin);

    return fetchRelationship(
      channelLogin: channelLogin,
      targetUserId: target.id,
      viewerUserId: viewerUserId,
    );
  }

  Future<_TwitchRelationshipUserLite> _resolveUserByLoginOrId({
    required String channelLogin,
    String? targetUserId,
  }) async {
    final explicitId = targetUserId?.trim();
    final login = channelLogin.trim().toLowerCase();

    if (explicitId != null && explicitId.isNotEmpty) {
      return _TwitchRelationshipUserLite(
        id: explicitId,
        login: login,
        displayName: login,
      );
    }

    final oauthToken = await _mainOauthToken();
    final clientId = await _mainClientId();

    if (oauthToken != null && oauthToken.isNotEmpty) {
      try {
        final raw = await client.getJson<Map<String, dynamic>>(
          '${TwitchApiConstants.helixBaseUrl}/users',
          queryParameters: <String, dynamic>{'login': login},
          headers: <String, String>{
            'Client-ID': clientId,
            'Authorization': 'Bearer $oauthToken',
            'Accept': 'application/json',
          },
        );

        final data = raw['data'];
        if (data is List && data.isNotEmpty) {
          final first = data.first;
          if (first is Map) {
            return _TwitchRelationshipUserLite(
              id: first['id']?.toString() ?? '',
              login: first['login']?.toString() ?? login,
              displayName: first['display_name']?.toString() ??
                  first['displayName']?.toString() ??
                  login,
            );
          }
        }
      } catch (_) {
        // Fallback to GQL below.
      }
    }

    try {
      final raw = await client.postJson<dynamic>(
        TwitchApiConstants.gqlEndpoint,
        data: <String, dynamic>{
          'operationName': 'StreamNookRelationshipResolveUser',
          'query': r'''
            query StreamNookRelationshipResolveUser($login: String!) {
              user(login: $login) {
                id
                login
                displayName
              }
            }
          ''',
          'variables': <String, dynamic>{'login': login},
        },
        headers: <String, String>{
          ...TwitchApiConstants.twitchWebHeaders,
          'Client-ID': gqlClientId,
          'Content-Type': 'application/json',
        },
      );

      if (raw is Map) {
        final data = raw['data'];
        final user = data is Map ? data['user'] : null;
        if (user is Map) {
          return _TwitchRelationshipUserLite(
            id: user['id']?.toString() ?? '',
            login: user['login']?.toString() ?? login,
            displayName: user['displayName']?.toString() ?? login,
          );
        }
      }
    } catch (_) {
      // Return empty below.
    }

    return _TwitchRelationshipUserLite(
      id: '',
      login: login,
      displayName: login,
    );
  }

  Future<bool?> _checkFollowingByHelix({
    required String targetUserId,
    String? viewerUserId,
  }) async {
    final token = await _mainOauthToken();
    if (token == null || token.isEmpty) return null;

    final clientId = await _mainClientId();
    final viewerId = viewerUserId?.trim().isNotEmpty == true
        ? viewerUserId!.trim()
        : await _resolveViewerUserId(token);

    if (viewerId == null || viewerId.isEmpty) return null;

    try {
      final raw = await client.getJson<Map<String, dynamic>>(
        '${TwitchApiConstants.helixBaseUrl}/channels/followed',
        queryParameters: <String, dynamic>{
          'user_id': viewerId,
          'broadcaster_id': targetUserId,
        },
        headers: <String, String>{
          'Client-ID': clientId,
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final data = raw['data'];
      if (data is List) return data.isNotEmpty;
      return false;
    } catch (_) {
      return null;
    }
  }

  Future<bool?> _checkFollowingByGql({
    required String channelLogin,
  }) async {
    final candidates = await _authCandidates();
    for (final auth in candidates) {
      if (auth.blocked) continue;
      try {
        final raw = await client.postJson<dynamic>(
          TwitchApiConstants.gqlEndpoint,
          data: <String, dynamic>{
            'operationName': 'StreamNookRelationshipCheckFollowing',
            'query': r'''
              query StreamNookRelationshipCheckFollowing($login: String!) {
                user(login: $login) {
                  id
                  self {
                    follower {
                      __typename
                    }
                  }
                }
              }
            ''',
            'variables': <String, dynamic>{
              'login': channelLogin.trim().toLowerCase(),
            },
          },
          headers: auth.gqlHeaders(),
        );

        _throwIfGqlErrors(raw, auth.label);

        if (raw is Map) {
          final data = raw['data'];
          final user = data is Map ? data['user'] : null;
          final self = user is Map ? user['self'] : null;
          final follower = self is Map ? self['follower'] : null;
          return follower is Map;
        }
      } catch (_) {
        // Try next token/header combination.
      }
    }
    return null;
  }

  Future<void> _sendFollowMutation(
    String targetUserId, {
    String? channelLogin,
  }) async {
    final variables = <String, dynamic>{
      'input': <String, dynamic>{
        'targetID': targetUserId,
        'disableNotifications': false,
      },
    };

    final runtimeHash = _followApqHash.trim();

    if (runtimeHash.isEmpty) {
      throw TwitchApiException(
        'Follow APQ hash is empty. 請設定 TWITCH_FOLLOW_APQ_HASH 或更新 v11 內建 hash。',
        details: _debugDetails(
          actionLabel: 'follow',
          operationName: 'FollowButton_FollowUser',
          requestMode: 'apq-hash-empty/no-full-query',
        ),
      );
    }

    await _sendRelationshipMutation(
      actionLabel: 'follow',
      bodies: <Map<String, dynamic>>[
        _persistedBody(
          operationName: 'FollowButton_FollowUser',
          variables: variables,
          sha256Hash: runtimeHash,
        ),
      ],
    );
  }

  Future<void> _sendUnfollowMutation(
    String targetUserId, {
    String? channelLogin,
  }) async {
    final variables = <String, dynamic>{
      'input': <String, dynamic>{
        'targetID': targetUserId,
      },
    };

    final runtimeHash = _unfollowApqHash.trim();

    if (runtimeHash.isEmpty) {
      throw TwitchApiException(
        'Unfollow APQ hash is empty. 請設定 TWITCH_UNFOLLOW_APQ_HASH 或更新 v11 內建 hash。',
        details: _debugDetails(
          actionLabel: 'unfollow',
          operationName: 'FollowButton_UnfollowUser',
          requestMode: 'apq-hash-empty/no-full-query',
        ),
      );
    }

    await _sendRelationshipMutation(
      actionLabel: 'unfollow',
      bodies: <Map<String, dynamic>>[
        _persistedBody(
          operationName: 'FollowButton_UnfollowUser',
          variables: variables,
          sha256Hash: runtimeHash,
        ),
      ],
    );
  }

  Future<void> _sendRelationshipMutation({
    required String actionLabel,
    required List<Map<String, dynamic>> bodies,
  }) async {
    final candidates = await _authCandidates();
    if (candidates.isEmpty) {
      throw const TwitchApiException(
        '沒有可用的 Drops / Android token，請到登入頁完成 Drops device flow。',
      );
    }

    final errors = <String>[];

    for (final auth in candidates) {
      if (auth.blocked) {
        errors.add(
          '${auth.label}/blocked tokenSource=${auth.tokenSource} clientIdSource=${auth.clientIdSource} clientId=${auth.clientId} ${auth.validateSummary ?? ''} blockReason=${auth.blockReason ?? 'blocked'}',
        );
        continue;
      }

      for (final body in bodies) {
        final isApq = body.containsKey('extensions');
        try {
          final raw = await client.postJson<dynamic>(
            TwitchApiConstants.gqlEndpoint,
            data: body,
            headers: auth.gqlHeaders(),
          );

          _throwIfGqlErrors(
            raw,
            '${auth.label}/$actionLabel/${isApq ? 'apq' : 'full-query'}',
          );
          return;
        } catch (e) {
          errors.add(
            _compactError(
              e,
              '${auth.label}/${isApq ? 'apq' : 'full-query'} tokenSource=${auth.tokenSource} clientIdSource=${auth.clientIdSource} clientId=${auth.clientId} ${auth.validateSummary ?? ''}',
            ),
          );
        }
      }
    }

    throw TwitchApiException(
      'Twitch $actionLabel APQ mutation failed. v15 已分離 Web GQL token 與 Drops Android token；若 details 顯示 missing，請到登入頁完成 Drops / Android device flow。',
      details: errors.take(8).toList(growable: false),
    );
  }

  Map<String, dynamic> _persistedBody({
    required String operationName,
    required Map<String, dynamic> variables,
    required String sha256Hash,
  }) {
    return <String, dynamic>{
      'operationName': operationName,
      'variables': variables,
      'extensions': <String, dynamic>{
        'persistedQuery': <String, dynamic>{
          'version': 1,
          'sha256Hash': sha256Hash,
        },
      },
    };
  }

  void _throwIfGqlErrors(Object? raw, String label) {
    if (raw is Map) {
      final errors = raw['errors'];
      if (errors is List && errors.isNotEmpty) {
        throw TwitchApiException(
          'Twitch GQL relationship error during $label.',
          details: errors,
        );
      }
      return;
    }

    throw TwitchApiException(
      'Unexpected Twitch GQL relationship response type: ${raw.runtimeType}.',
      details: raw,
    );
  }

  Future<List<_TwitchRelationshipAuthCandidate>> _authCandidates() async {
    final result = <_TwitchRelationshipAuthCandidate>[];

    final dropsTokenResult = await _dropsCompatibleTokenWithSource();
    final safeDropsToken = dropsTokenResult.value?.trim();
    if (safeDropsToken != null && safeDropsToken.isNotEmpty) {
      final dropsClientIdResult = await _dropsCompatibleClientIdWithSource();
      final safeClientId = _normalizeDropsClientIdForRelationship(
        dropsClientIdResult.value,
      );
      final validation = await _validateTokenDetails(safeDropsToken);
      final expectedClientId = safeClientId.trim();
      final actualClientId = validation.clientId.trim();
      final isWebClientToken = _looksLikeTwitchWebClientId(actualClientId);
      final isMismatch = validation.hasClientId &&
          expectedClientId.isNotEmpty &&
          actualClientId != expectedClientId;

      result.add(
        _TwitchRelationshipAuthCandidate(
          token: safeDropsToken,
          authorizationPrefix: 'OAuth',
          clientId: expectedClientId,
          label: 'streamnook-drops-token/oauth-prefix/android-client',
          tokenSource: dropsTokenResult.source,
          clientIdSource: dropsClientIdResult.source,
          validateSummary: validation.toSummary(),
          blocked: isWebClientToken || isMismatch,
          blockReason: isWebClientToken
              ? 'this token validates as Twitch Web client_id=$actualClientId, not Android/Drops; clear drops session and login drops again'
              : isMismatch
                  ? 'token client_id=$actualClientId does not match selected drops clientId=$expectedClientId; clear drops session and login drops again'
                  : null,
        ),
      );
    }

    return result;
  }

  Future<String?> _resolveTwitchWebApqHash({
    required String operationName,
    String? channelLogin,
  }) async {
    final cached = _runtimeApqHashCache[operationName];
    if (cached != null && cached.isNotEmpty) return cached;
    if (_apqDiscoveryFailedRecently) return null;

    final assetUrls = <String>{};
    var pageFetchOk = 0;
    var pageFetchFailed = 0;
    var scannedAssets = 0;
    var assetFetchFailed = 0;

    final pages = <String>[
      if (channelLogin != null && channelLogin.trim().isNotEmpty)
        'https://www.twitch.tv/${Uri.encodeComponent(channelLogin.trim().toLowerCase())}',
      'https://www.twitch.tv/',
    ];

    for (final pageUrl in pages) {
      try {
        final response = await client.dio.get<String>(
          pageUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: TwitchApiConstants.twitchWebHeaders,
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        final html = response.data ?? '';
        pageFetchOk++;
        assetUrls.addAll(_extractTwitchAssetUrls(html));
      } catch (_) {
        pageFetchFailed++;
      }
    }

    final orderedAssets = assetUrls.toList()
      ..sort((a, b) {
        int score(String value) {
          final lower = value.toLowerCase();
          var result = 0;
          if (lower.contains('follow')) result -= 10;
          if (lower.contains('channel')) result -= 4;
          if (lower.contains('core')) result -= 2;
          if (lower.contains('vendor')) result += 5;
          return result;
        }

        return score(a).compareTo(score(b));
      });

    for (final assetUrl in orderedAssets.take(90)) {
      try {
        final response = await client.dio.get<String>(
          assetUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: TwitchApiConstants.twitchWebHeaders,
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 12),
          ),
        );
        scannedAssets++;
        final source = response.data ?? '';
        final hash = _extractApqHashNearOperation(source, operationName);
        if (hash != null && hash.isNotEmpty) {
          _runtimeApqHashCache[operationName] = hash;
          _runtimeApqDiscoveryDebug[operationName] =
              'found hash; pagesOk=$pageFetchOk pagesFailed=$pageFetchFailed assets=${assetUrls.length} scanned=$scannedAssets assetFailed=$assetFetchFailed';
          return hash;
        }
      } catch (_) {
        assetFetchFailed++;
      }
    }

    _runtimeApqDiscoveryDebug[operationName] =
        'hash not found; pagesOk=$pageFetchOk pagesFailed=$pageFetchFailed assets=${assetUrls.length} scanned=$scannedAssets assetFailed=$assetFetchFailed';
    _apqDiscoveryFailedRecently = true;
    return null;
  }

  List<String> _extractTwitchAssetUrls(String html) {
    final result = <String>{};
    final patterns = <RegExp>[
      RegExp(r'''https://static\.twitchcdn\.net/assets/[^"'<>\s]+?\.js[^"'<>\s]*'''),
      RegExp(r'''//static\.twitchcdn\.net/assets/[^"'<>\s]+?\.js[^"'<>\s]*'''),
      RegExp(r'''/assets/[^"'<>\s]+?\.js[^"'<>\s]*'''),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(html)) {
        var url = match.group(0) ?? '';
        if (url.startsWith('//')) {
          url = 'https:$url';
        } else if (url.startsWith('/assets/')) {
          url = 'https://static.twitchcdn.net$url';
        }
        if (url.startsWith('https://static.twitchcdn.net/') &&
            url.contains('.js')) {
          result.add(url);
        }
      }
    }

    return result.toList(growable: false);
  }

  String? _extractApqHashNearOperation(String source, String operationName) {
    final opPattern = RegExp(RegExp.escape(operationName));
    final hashPattern = RegExp(r'''[a-f0-9]{64}''');
    String? bestHash;
    var bestDistance = 1 << 30;

    for (final match in opPattern.allMatches(source)) {
      final start = (match.start - 8000).clamp(0, source.length).toInt();
      final end = (match.end + 8000).clamp(0, source.length).toInt();
      final segment = source.substring(start, end);
      final localOpIndex = match.start - start;

      for (final hashMatch in hashPattern.allMatches(segment)) {
        final hash = hashMatch.group(0);
        if (hash == null) continue;
        final distance = (hashMatch.start - localOpIndex).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          bestHash = hash;
        }
      }
    }

    return bestHash;
  }

  Map<String, Object?> _debugDetails({
    required String actionLabel,
    required String operationName,
    required String requestMode,
  }) {
    return <String, Object?>{
      'patch': 'streamnook_relationship_token_split_v15',
      'action': actionLabel,
      'operationName': operationName,
      'requestMode': requestMode,
      'followApqHashConfigured': _followApqHash.trim().isNotEmpty,
      'unfollowApqHashConfigured': _unfollowApqHash.trim().isNotEmpty,
      'runtimeApqDiscovery': _runtimeApqDiscoveryDebug[operationName] ??
          'not started or cache hit unavailable',
      'tokenRule': 'follow/unfollow uses StreamNook-style drops/android token; status check still uses main OAuth Helix',
      'nextStep': 'if Twitch returns failed integrity check even with v11 APQ hashes, compare live Twitch request headers/client context',
    };
  }

  String _compactError(Object error, String label) {
    var text = error.toString().replaceAll('\n', ' ');
    if (text.length > 420) {
      text = '${text.substring(0, 420)}...';
    }
    return '$label => $text';
  }

  Future<_RelationshipValueSource<String?>> _dropsCompatibleTokenWithSource() async {
    final direct = await dropsTokenProvider?.call();
    final safeDirect = direct?.trim();
    if (safeDirect != null && safeDirect.isNotEmpty) {
      return _RelationshipValueSource<String?>(safeDirect, 'dropsTokenProvider');
    }

    final stored = await _loadDropsTokenFromSharedPreferences();
    final safeStored = stored?.trim();
    if (safeStored != null && safeStored.isNotEmpty) {
      return _RelationshipValueSource<String?>(safeStored, 'sharedPreferences:${_StreamNookDropsPrefsKeys.tokenStorageKey}');
    }

    return const _RelationshipValueSource<String?>(null, 'missing');
  }

  Future<String?> _dropsCompatibleToken() async {
    return (await _dropsCompatibleTokenWithSource()).value;
  }

  Future<_RelationshipValueSource<String>> _dropsCompatibleClientIdWithSource() async {
    final value = await dropsClientIdProvider?.call();
    final safe = value?.trim();
    if (safe != null && safe.isNotEmpty && !_looksLikeTwitchWebClientId(safe)) {
      return _RelationshipValueSource<String>(safe, 'dropsClientIdProvider');
    }

    final stored = await _loadDropsClientIdFromSharedPreferences();
    final safeStored = stored?.trim();
    if (safeStored != null &&
        safeStored.isNotEmpty &&
        !_looksLikeTwitchWebClientId(safeStored)) {
      return _RelationshipValueSource<String>(safeStored, 'sharedPreferences:${_StreamNookDropsPrefsKeys.clientIdStorageKey}');
    }

    final fromConstants = TwitchApiConstants.twitchDefaultDropsClientId.trim();
    if (fromConstants.isNotEmpty && !_looksLikeTwitchWebClientId(fromConstants)) {
      return _RelationshipValueSource<String>(fromConstants, 'TwitchApiConstants.twitchDefaultDropsClientId');
    }

    return _RelationshipValueSource<String>(
      TwitchApiConstants.twitchAndroidClientId,
      'TwitchApiConstants.twitchAndroidClientId',
    );
  }

  bool _looksLikeTwitchWebClientId(String value) {
    return value.trim() == TwitchApiConstants.twitchWebClientId.trim();
  }

  String _normalizeDropsClientIdForRelationship(String value) {
    final safe = value.trim();
    if (safe.isNotEmpty && !_looksLikeTwitchWebClientId(safe)) return safe;

    final fromConstants = TwitchApiConstants.twitchDefaultDropsClientId.trim();
    if (fromConstants.isNotEmpty && !_looksLikeTwitchWebClientId(fromConstants)) {
      return fromConstants;
    }

    return TwitchApiConstants.twitchAndroidClientId.trim();
  }

  Future<String> _dropsCompatibleClientId() async {
    return (await _dropsCompatibleClientIdWithSource()).value;
  }

  Future<String?> _loadDropsTokenFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_StreamNookDropsPrefsKeys.tokenStorageKey);
      if (raw == null || raw.trim().isEmpty) return null;

      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        final camel = parsed['accessToken']?.toString().trim();
        if (camel != null && camel.isNotEmpty) return camel;

        final snake = parsed['access_token']?.toString().trim();
        if (snake != null && snake.isNotEmpty) return snake;
      }
    } catch (_) {
      // Ignore corrupt cache; TwitchDropsAuthService owns cleanup.
    }
    return null;
  }

  Future<String?> _loadDropsClientIdFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_StreamNookDropsPrefsKeys.clientIdStorageKey);
    } catch (_) {
      return null;
    }
  }

  Future<String> _validateTokenSummary(String token) async {
    return (await _validateTokenDetails(token)).toSummary();
  }

  Future<_TokenValidationDetails> _validateTokenDetails(String token) async {
    try {
      final raw = await client.getJson<Map<String, dynamic>>(
        TwitchApiConstants.oauthValidateUrl,
        headers: <String, String>{
          'Authorization': 'OAuth $token',
          'Accept': 'application/json',
        },
      );

      final scopes = raw['scopes'];
      final scopesText = scopes is List ? scopes.join(',') : scopes?.toString() ?? '';
      return _TokenValidationDetails(
        clientId: raw['client_id']?.toString() ?? '',
        login: raw['login']?.toString() ?? '',
        userId: raw['user_id']?.toString() ?? '',
        scopesText: scopesText,
      );
    } catch (e) {
      return _TokenValidationDetails(
        clientId: '',
        login: '',
        userId: '',
        scopesText: '',
        error: _compactError(e, 'oauth-validate'),
      );
    }
  }

  Future<String?> _mainOauthToken() async {
    final direct = await oauthTokenProvider?.call();
    final safeDirect = direct?.trim();
    if (safeDirect != null && safeDirect.isNotEmpty) return safeDirect;

    final fallback = await fallbackTokenProvider?.call();
    final safeFallback = fallback?.trim();
    if (safeFallback != null && safeFallback.isNotEmpty) return safeFallback;

    return null;
  }

  Future<String> _mainClientId() async {
    final value = await oauthClientIdProvider?.call();
    final safe = value?.trim();
    if (safe != null && safe.isNotEmpty) return safe;
    return TwitchApiConstants.twitchWebClientId;
  }

  Future<String?> _resolveViewerUserId(String token) async {
    try {
      final raw = await client.getJson<Map<String, dynamic>>(
        TwitchApiConstants.oauthValidateUrl,
        headers: <String, String>{
          'Authorization': 'OAuth $token',
          'Accept': 'application/json',
        },
      );

      final id = raw['user_id']?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {
      // Ignore; caller can fallback.
    }
    return null;
  }
}
