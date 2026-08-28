import 'package:dio/dio.dart';

import '../../models/playback/twitch_m3u8_variant.dart';
import '../../models/playback/twitch_playback.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_gql_api_service.dart';

class TwitchPlaybackApiService {
  final TwitchGqlApiService gql;

  const TwitchPlaybackApiService({required this.gql});

  static const String _clipAccessTokenQuery = r'''
    query VideoAccessToken_Clip($slug: ID!) {
      clip(slug: $slug) {
        id
        durationSeconds
        videoOffsetSeconds
        video {
          id
        }
        broadcaster {
          login
        }
        playbackAccessToken(
          params: {
            platform: "web"
            playerBackend: "mediaplayer"
            playerType: "site"
          }
        ) {
          signature
          value
        }
        videoQualities {
          frameRate
          quality
          sourceURL
        }
      }
    }
  ''';

  Future<TwitchPlaybackAccessToken> getLivePlaybackAccessToken({
    required String channelLogin,
    String platform = 'web',
    String playerType = 'site',
  }) async {
    final login = channelLogin.trim().toLowerCase();
    final cleanPlatform = platform.trim().isEmpty ? 'web' : platform.trim();
    final cleanPlayerType = playerType.trim().isEmpty
        ? 'site'
        : playerType.trim();

    if (login.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channel login cannot be empty',
      );
    }

    final data = await gql.request(
      operationName: 'PlaybackAccessToken',
      query: r'''
        query PlaybackAccessToken(
          $login: String!
          $isLive: Boolean!
          $vodID: ID!
          $isVod: Boolean!
          $platform: String!
          $playerType: String!
        ) {
          streamPlaybackAccessToken(
            channelName: $login
            params: {
              platform: $platform
              playerBackend: "mediaplayer"
              playerType: $playerType
            }
          ) @include(if: $isLive) {
            value
            signature
          }
          videoPlaybackAccessToken(
            id: $vodID
            params: {
              platform: $platform
              playerBackend: "mediaplayer"
              playerType: $playerType
            }
          ) @include(if: $isVod) {
            value
            signature
          }
        }
      ''',
      variables: <String, dynamic>{
        'login': login,
        'isLive': true,
        'vodID': '',
        'isVod': false,
        'platform': cleanPlatform,
        'playerType': cleanPlayerType,
      },
    );

    final raw = data['streamPlaybackAccessToken'];
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'GQL response does not contain streamPlaybackAccessToken.',
      );
    }

    final token = TwitchPlaybackAccessToken.fromJson(raw);
    if (!token.isValid) {
      throw StateError('Playback token is incomplete.');
    }

    return token;
  }

  Future<TwitchPlaybackAccessToken> getVodPlaybackAccessToken({
    required String videoId,
    String platform = 'web',
    String playerType = 'embed',
  }) async {
    final cleanVideoId = videoId.trim();
    final cleanPlatform = platform.trim().isEmpty ? 'web' : platform.trim();
    final cleanPlayerType = playerType.trim().isEmpty
        ? 'site'
        : playerType.trim();

    if (cleanVideoId.isEmpty) {
      throw ArgumentError.value(videoId, 'videoId', 'video id cannot be empty');
    }

    final data = await gql.request(
      operationName: 'PlaybackAccessToken',
      query: r'''
        query PlaybackAccessToken(
          $login: String!
          $isLive: Boolean!
          $vodID: ID!
          $isVod: Boolean!
          $platform: String!
          $playerType: String!
        ) {
          streamPlaybackAccessToken(
            channelName: $login
            params: {
              platform: $platform
              playerBackend: "mediaplayer"
              playerType: $playerType
            }
          ) @include(if: $isLive) {
            value
            signature
          }
          videoPlaybackAccessToken(
            id: $vodID
            params: {
              platform: $platform
              playerBackend: "mediaplayer"
              playerType: $playerType
            }
          ) @include(if: $isVod) {
            value
            signature
          }
        }
      ''',
      variables: <String, dynamic>{
        'login': '',
        'isLive': false,
        'vodID': cleanVideoId,
        'isVod': true,
        'platform': cleanPlatform,
        'playerType': cleanPlayerType,
      },
    );

    final raw = data['videoPlaybackAccessToken'];
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'GQL response does not contain videoPlaybackAccessToken.',
      );
    }

    final token = TwitchPlaybackAccessToken.fromJson(raw);
    if (!token.isValid) {
      throw StateError('VOD playback token is incomplete.');
    }

    return token;
  }

  Uri buildLivePlaylistUri({
    required String channelLogin,
    required TwitchPlaybackAccessToken accessToken,
    bool allowSource = true,
    bool allowAudioOnly = true,
    String supportedCodecs = 'avc1',
  }) {
    final login = channelLogin.trim().toLowerCase();

    return TwitchPlaybackPlaylistRequest(
      channelLogin: login,
      accessToken: accessToken,
      clientId: gql.clientId,
      allowSource: allowSource,
      allowAudioOnly: allowAudioOnly,
      supportedCodecs: supportedCodecs.trim().isEmpty
          ? 'avc1'
          : supportedCodecs.trim(),
    ).buildUsherUri();
  }

  Uri buildVodPlaylistUri({
    required String videoId,
    required TwitchPlaybackAccessToken accessToken,
    bool allowSource = true,
    bool allowAudioOnly = true,
    String supportedCodecs = 'av1,h264,h265',
  }) {
    final cleanVideoId = videoId.trim();

    return TwitchVodPlaylistRequest(
      videoId: cleanVideoId,
      accessToken: accessToken,
      clientId: gql.clientId,
      allowSource: allowSource,
      allowAudioOnly: allowAudioOnly,
      supportedCodecs: supportedCodecs.trim().isEmpty
          ? 'avc1'
          : supportedCodecs.trim(),
    ).buildUsherUri();
  }

  Future<TwitchVodPlaybackResult> resolveVodPlaylist({
    required String videoId,
    String preferredQuality = 'source',
  }) async {
    final token = await getVodPlaybackAccessToken(videoId: videoId);
    final masterUri = buildVodPlaylistUri(videoId: videoId, accessToken: token);
    final response = await gql.client.dio.getUri<String>(
      masterUri,
      options: Options(
        responseType: ResponseType.plain,
        headers: const <String, String>{
          'Accept': 'application/x-mpegURL, application/vnd.apple.mpegurl, */*',
          'Origin': 'https://player.twitch.tv',
          'Referer': 'https://player.twitch.tv',
          'User-Agent': TwitchApiConstants.browserUserAgent,
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    final text = response.data ?? '';
    if (statusCode >= 400 || text.trim().isEmpty) {
      throw StateError('VOD master playlist 載入失敗：HTTP $statusCode');
    }

    final variants = TwitchM3u8Parser.parseMasterPlaylist(
      text,
      masterUri: masterUri,
      sourceTag: 'vod-web-embed',
    );
    final selected = _selectVodVariant(variants, preferredQuality);
    final playlistUri = selected == null
        ? masterUri
        : Uri.tryParse(selected.url) ?? masterUri;

    return TwitchVodPlaybackResult(
      masterUri: masterUri,
      playlistUri: playlistUri,
      masterPlaylistText: text,
      variants: variants,
      selectedVariant: selected,
    );
  }

  Future<TwitchClipPlaybackResult> resolveClipPlayback({
    required String clipSlug,
    String preferredQuality = 'source',
  }) async {
    final slug = clipSlug.trim();
    if (slug.isEmpty) {
      throw ArgumentError.value(
        clipSlug,
        'clipSlug',
        'clip slug cannot be empty',
      );
    }

    final data = await gql.request(
      operationName: 'VideoAccessToken_Clip',
      query: _clipAccessTokenQuery,
      variables: <String, dynamic>{'slug': slug},
    );

    final clip = data['clip'];
    if (clip is! Map<String, dynamic>) {
      throw StateError('Clip playback response does not contain clip.');
    }

    final tokenRaw = clip['playbackAccessToken'];
    if (tokenRaw is! Map<String, dynamic>) {
      throw StateError('Clip playback token is missing.');
    }
    final token = TwitchPlaybackAccessToken.fromJson(tokenRaw);
    if (!token.isValid) {
      throw StateError('Clip playback token is incomplete.');
    }

    final qualitiesRaw = clip['videoQualities'];
    final variants = qualitiesRaw is List
        ? qualitiesRaw
              .whereType<Map<String, dynamic>>()
              .map((quality) => _parseClipVariant(quality, token))
              .whereType<TwitchM3u8Variant>()
              .toList(growable: false)
        : const <TwitchM3u8Variant>[];
    if (variants.isEmpty) {
      throw StateError('Clip 沒有可播放的畫質。');
    }

    final selected =
        _selectVodVariant(variants, preferredQuality) ??
        _sortVodVariants(variants).first;
    final playbackUri = Uri.tryParse(selected.url);
    if (playbackUri == null) {
      throw StateError('Clip 播放 URL 無效。');
    }

    final video = clip['video'];
    final broadcaster = clip['broadcaster'];
    return TwitchClipPlaybackResult(
      playbackUri: playbackUri,
      variants: variants,
      selectedVariant: selected,
      sourceVideoId: video is Map<String, dynamic>
          ? video['id']?.toString().trim()
          : null,
      sourceVodOffsetSeconds: _readIntOrNull(clip['videoOffsetSeconds']),
      durationSeconds: _readDoubleOrNull(clip['durationSeconds']),
      broadcasterLogin: broadcaster is Map<String, dynamic>
          ? broadcaster['login']?.toString().trim().toLowerCase()
          : null,
    );
  }

  TwitchM3u8Variant? _parseClipVariant(
    Map<String, dynamic> quality,
    TwitchPlaybackAccessToken token,
  ) {
    final sourceUrl = quality['sourceURL']?.toString().trim() ?? '';
    final rawQuality = quality['quality']?.toString().trim() ?? '';
    if (sourceUrl.isEmpty || rawQuality.isEmpty) return null;

    final sourceUri = Uri.tryParse(sourceUrl);
    if (sourceUri == null) return null;

    final frameRate = _readDoubleOrNull(quality['frameRate']);
    final height = int.tryParse(rawQuality);
    final name =
        '${rawQuality}p${frameRate == null || frameRate <= 0 ? '' : frameRate.round()}';
    final signedUri = sourceUri.replace(
      queryParameters: <String, String>{
        ...sourceUri.queryParameters,
        'sig': token.signature,
        'token': token.value,
      },
    );

    return TwitchM3u8Variant(
      name: name,
      url: signedUri.toString(),
      resolution: height == null ? null : '0x$height',
      frameRate: frameRate,
      sourceTag: 'clip-web-site',
    );
  }

  TwitchM3u8Variant? _selectVodVariant(
    List<TwitchM3u8Variant> variants,
    String preferredQuality,
  ) {
    if (variants.isEmpty) return null;
    final videos = variants.where((v) => !v.isAudioOnly).toList();
    final pool = videos.isEmpty ? variants.toList() : videos;
    final target = preferredQuality.trim().toLowerCase();

    if (target == 'source' || target == 'best' || target.isEmpty) {
      final source = pool.where(_isSourceLikeVariant).toList();
      if (source.isNotEmpty) return _sortVodVariants(source).first;
      return _sortVodVariants(pool).first;
    }

    final normalizedTarget = _normalizeQualityName(target);
    final matches = pool.where((variant) {
      return _normalizeQualityName(variant.name) == normalizedTarget ||
          _normalizeQualityName(variant.displayName) == normalizedTarget ||
          _normalizeQualityName(variant.videoGroupId ?? '') ==
              normalizedTarget ||
          _normalizeQualityName(variant.adAwareQualityKey) == normalizedTarget;
    }).toList();
    if (matches.isNotEmpty) return _sortVodVariants(matches).first;
    return _sortVodVariants(pool).first;
  }

  List<TwitchM3u8Variant> _sortVodVariants(List<TwitchM3u8Variant> variants) {
    final list = variants.toList();
    list.sort((a, b) => _vodVariantScore(b).compareTo(_vodVariantScore(a)));
    return list;
  }

  int _vodVariantScore(TwitchM3u8Variant variant) {
    var score = 0;
    if (!variant.isAudioOnly) score += 10000000;
    score += variant.height * 10000;
    score += variant.fpsRounded * 100;
    score += (variant.bandwidth ?? 0) ~/ 1000;
    return score;
  }

  bool _isSourceLikeVariant(TwitchM3u8Variant variant) {
    final text = '${variant.name} ${variant.videoGroupId ?? ''}'
        .trim()
        .toLowerCase();
    return text.contains('source') || text.contains('chunked');
  }

  String _normalizeQualityName(String value) {
    final text = value.trim().toLowerCase();
    if (text.contains('source')) return 'source';
    if (text.contains('chunked')) return 'chunked';
    if (text.contains('audio')) return 'audio_only';
    return text
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('_', '')
        .replaceAll('-', '');
  }

  int? _readIntOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _readDoubleOrNull(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
