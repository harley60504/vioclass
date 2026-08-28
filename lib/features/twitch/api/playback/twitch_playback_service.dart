import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../models/playback/twitch_m3u8_variant.dart';
import 'twitch_gql_client.dart';

class TwitchPlaybackServiceException implements Exception {
  final String message;
  final Object? cause;

  const TwitchPlaybackServiceException(this.message, {this.cause});

  @override
  String toString() {
    if (cause == null) return 'TwitchPlaybackServiceException: $message';
    return 'TwitchPlaybackServiceException: $message｜$cause';
  }
}

class TwitchPlaybackService {
  static const String playbackAccessTokenOperationName = 'PlaybackAccessToken';

  static const String playbackAccessTokenQuery = r'''
    query PlaybackAccessToken(
      $login: String!,
      $isLive: Boolean!,
      $vodID: ID!,
      $isVod: Boolean!,
      $platform: String!,
      $playerType: String!
    ) {
      streamPlaybackAccessToken(
        channelName: $login,
        params: {
          platform: $platform,
          playerBackend: "mediaplayer",
          playerType: $playerType
        }
      ) @include(if: $isLive) {
        value
        signature
      }
      videoPlaybackAccessToken(
        id: $vodID,
        params: {
          platform: $platform,
          playerBackend: "mediaplayer",
          playerType: $playerType
        }
      ) @include(if: $isVod) {
        value
        signature
      }
    }
  ''';

  final TwitchGqlClient gqlClient;
  final Dio _dio;

  TwitchPlaybackService({required this.gqlClient, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 12),
            ),
          );

  Future<TwitchPlaybackResult> getLivePlaylist({
    required String channelLogin,
    String supportedCodecs = 'h264',
    bool allowSource = true,
    bool allowAudioOnly = true,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw const TwitchPlaybackServiceException('channelLogin is empty.');
    }

    final candidates =
        await Future.wait<_PlaybackCandidate?>(<Future<_PlaybackCandidate?>>[
          _loadCandidate(
            login,
            platform: 'web',
            playerType: 'site',
            sourceTag: 'web-site',
            defaultHasAds: true,
            supportedCodecs: supportedCodecs,
            allowSource: allowSource,
            allowAudioOnly: allowAudioOnly,
          ),
          _loadCandidate(
            login,
            platform: 'android',
            playerType: 'autoplay',
            sourceTag: 'android-autoplay',
            defaultHasAds: false,
            supportedCodecs: supportedCodecs,
            allowSource: allowSource,
            allowAudioOnly: allowAudioOnly,
          ),
          _loadCandidate(
            login,
            platform: 'ios',
            playerType: 'site',
            sourceTag: 'ios-site',
            defaultHasAds: false,
            supportedCodecs: supportedCodecs,
            allowSource: allowSource,
            allowAudioOnly: allowAudioOnly,
          ),
        ]);

    final webCandidate = candidates.firstWhere(
      (candidate) => candidate?.sourceTag == 'web-site',
      orElse: () => null,
    );
    final androidCandidate = candidates.firstWhere(
      (candidate) => candidate?.sourceTag == 'android-autoplay',
      orElse: () => null,
    );
    final iosCandidate = candidates.firstWhere(
      (candidate) => candidate?.sourceTag == 'ios-site',
      orElse: () => null,
    );

    final baseCandidate = webCandidate ?? androidCandidate ?? iosCandidate;
    if (baseCandidate == null) {
      throw const TwitchPlaybackServiceException(
        'Failed to load Twitch master m3u8 from all playback contexts.',
      );
    }

    final variants = _mergeAdAwareVariants(
      baseVariants: baseCandidate.variants,
      cleanCandidates: <_PlaybackCandidate>[?androidCandidate, ?iosCandidate],
    );

    if (variants.isEmpty) {
      throw TwitchPlaybackServiceException(
        'No playable m3u8 variants found.',
        cause: baseCandidate.masterPlaylistText.length > 500
            ? baseCandidate.masterPlaylistText.substring(0, 500)
            : baseCandidate.masterPlaylistText,
      );
    }

    return TwitchPlaybackResult(
      usherUri: baseCandidate.usherUri,
      masterPlaylistUrl: baseCandidate.usherUri.toString(),
      masterPlaylistText: baseCandidate.masterPlaylistText,
      variants: variants,
      token: baseCandidate.token,
      signature: baseCandidate.signature,
    );
  }

  Future<_PlaybackCandidate?> _loadCandidate(
    String login, {
    required String platform,
    required String playerType,
    required String sourceTag,
    required bool defaultHasAds,
    required String supportedCodecs,
    required bool allowSource,
    required bool allowAudioOnly,
  }) async {
    try {
      final tokenData = await _loadPlaybackAccessToken(
        login,
        platform: platform,
        playerType: playerType,
      );
      final signature = tokenData.signature;
      final token = tokenData.value;

      if (signature.isEmpty || token.isEmpty) {
        return null;
      }

      final usherUri = _buildUsherUri(
        channelLogin: login,
        signature: signature,
        token: token,
        supportedCodecs: supportedCodecs,
        allowSource: allowSource,
        allowAudioOnly: allowAudioOnly,
      );

      final response = await _dio.getUri<String>(
        usherUri,
        options: Options(
          responseType: ResponseType.plain,
          headers: const <String, String>{
            'Accept':
                'application/x-mpegURL, application/vnd.apple.mpegurl, */*',
            'Origin': 'https://www.twitch.tv',
            'Referer': 'https://www.twitch.tv/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final status = response.statusCode ?? 0;
      final playlistText = response.data ?? '';
      if (status >= 400 || playlistText.trim().isEmpty) {
        return null;
      }

      final variants = TwitchM3u8Parser.parseMasterPlaylist(
        playlistText,
        masterUri: usherUri,
        defaultHasAds: defaultHasAds,
        sourceTag: sourceTag,
      );
      if (variants.isEmpty) return null;

      return _PlaybackCandidate(
        sourceTag: sourceTag,
        usherUri: usherUri,
        masterPlaylistText: playlistText,
        token: token,
        signature: signature,
        variants: variants,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_PlaybackAccessTokenData> _loadPlaybackAccessToken(
    String login, {
    required String platform,
    required String playerType,
  }) async {
    final payload = <String, dynamic>{
      'operationName': playbackAccessTokenOperationName,
      'query': playbackAccessTokenQuery,
      'variables': <String, dynamic>{
        'isLive': true,
        'login': login,
        'isVod': false,
        'vodID': '',
        'platform': platform,
        'playerType': playerType,
      },
    };

    final data = await gqlClient.post(
      payload,
      operationLabel: '$playbackAccessTokenOperationName/$platform/$playerType',
    );

    final root = data is List && data.isNotEmpty ? data.first : data;
    if (root is! Map) {
      throw TwitchPlaybackServiceException(
        'Unexpected playback token response.',
        cause: data,
      );
    }

    final dataNode = root['data'];
    if (dataNode is! Map) {
      throw TwitchPlaybackServiceException(
        'Missing data in playback token response.',
        cause: data,
      );
    }

    final tokenNode = dataNode['streamPlaybackAccessToken'];
    if (tokenNode is! Map) {
      throw TwitchPlaybackServiceException(
        'Missing streamPlaybackAccessToken.',
        cause: data,
      );
    }

    return _PlaybackAccessTokenData(
      value: tokenNode['value']?.toString() ?? '',
      signature: tokenNode['signature']?.toString() ?? '',
    );
  }

  Uri _buildUsherUri({
    required String channelLogin,
    required String signature,
    required String token,
    required String supportedCodecs,
    required bool allowSource,
    required bool allowAudioOnly,
  }) {
    final random = math.Random();
    final playSessionId = _randomHex(random, 32);

    return Uri.https(
      'usher.ttvnw.net',
      '/api/channel/hls/$channelLogin.m3u8',
      <String, String>{
        'allow_source': allowSource ? 'true' : 'false',
        'allow_audio_only': allowAudioOnly ? 'true' : 'false',
        'client_id': gqlClient.clientId,
        'fast_bread': 'true',
        'p': random.nextInt(10000000).toString(),
        'play_session_id': playSessionId,
        'player_backend': 'mediaplayer',
        'playlist_include_framerate': 'true',
        'reassignments_supported': 'true',
        'sig': signature,
        'supported_codecs': supportedCodecs.trim().isEmpty
            ? 'h264'
            : supportedCodecs.trim(),
        'token': token,
      },
    );
  }

  List<TwitchM3u8Variant> _mergeAdAwareVariants({
    required List<TwitchM3u8Variant> baseVariants,
    required List<_PlaybackCandidate> cleanCandidates,
  }) {
    final cleanByQuality = <String, TwitchM3u8Variant>{};
    for (final candidate in cleanCandidates) {
      for (final variant in candidate.variants) {
        cleanByQuality.putIfAbsent(variant.adAwareQualityKey, () => variant);
      }
    }

    final merged = <TwitchM3u8Variant>[];
    final usedCleanUrls = <String>{};
    for (final base in baseVariants) {
      final clean = cleanByQuality[base.adAwareQualityKey];
      if (clean != null) {
        usedCleanUrls.add(clean.url);
        merged.add(
          base.copyWith(
            url: clean.url,
            hasAds: false,
            sourceTag: clean.sourceTag,
          ),
        );
      } else {
        merged.add(
          base.copyWith(
            hasAds: true,
            sourceTag: base.sourceTag.isEmpty ? 'web-site' : base.sourceTag,
          ),
        );
      }
    }

    for (final clean in cleanByQuality.values) {
      if (usedCleanUrls.contains(clean.url)) continue;
      if (merged.any((variant) => variant.url == clean.url)) continue;
      merged.add(clean.copyWith(hasAds: false));
    }

    merged.sort((a, b) {
      if (a.hasAds != b.hasAds) return a.hasAds ? 1 : -1;
      final heightCompare = b.height.compareTo(a.height);
      if (heightCompare != 0) return heightCompare;
      final fpsCompare = b.fpsRounded.compareTo(a.fpsRounded);
      if (fpsCompare != 0) return fpsCompare;
      return a.name.compareTo(b.name);
    });
    return merged;
  }

  String _randomHex(math.Random random, int length) {
    const chars = '0123456789abcdef';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }
}

class _PlaybackAccessTokenData {
  final String value;
  final String signature;

  const _PlaybackAccessTokenData({
    required this.value,
    required this.signature,
  });
}

class _PlaybackCandidate {
  final String sourceTag;
  final Uri usherUri;
  final String masterPlaylistText;
  final String token;
  final String signature;
  final List<TwitchM3u8Variant> variants;

  const _PlaybackCandidate({
    required this.sourceTag,
    required this.usherUri,
    required this.masterPlaylistText,
    required this.token,
    required this.signature,
    required this.variants,
  });
}
