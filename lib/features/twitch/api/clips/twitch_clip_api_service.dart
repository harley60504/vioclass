import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_api_exception.dart';
import 'package:uuid/uuid.dart';

typedef TwitchClipAccessTokenProvider = Future<String?> Function();
typedef TwitchClipClientIdProvider = Future<String?> Function();

class TwitchCreateClipResult {
  final String id;
  final String editUrl;

  const TwitchCreateClipResult({required this.id, required this.editUrl});

  String get publicUrl =>
      id.trim().isEmpty ? '' : 'https://clips.twitch.tv/$id';

  factory TwitchCreateClipResult.fromJson(Map<String, dynamic> json) {
    return TwitchCreateClipResult(
      id: json['id']?.toString().trim() ?? '',
      editUrl: json['edit_url']?.toString().trim() ?? '',
    );
  }
}

class TwitchLiveBroadcast {
  final String broadcastId;
  final DateTime? startedAt;

  const TwitchLiveBroadcast({
    required this.broadcastId,
    required this.startedAt,
  });
}

class TwitchClipEditSession {
  final String rawMediaId;
  final double durationSeconds;
  final String previewUrl;

  const TwitchClipEditSession({
    required this.rawMediaId,
    required this.durationSeconds,
    required this.previewUrl,
  });
}

class TwitchClipRenderStatus {
  final bool ready;
  final String? thumbnailUrl;

  const TwitchClipRenderStatus({
    required this.ready,
    required this.thumbnailUrl,
  });
}

class TwitchClipApiService {
  static const String _createRawMediaHash =
      '19cbfe94f0aff2e1338fd8ee472d90c8d334e17a84ebe8b06dcb236bd9394dfd';
  static const String _createClipFromRawHash =
      'dfc972bc2a6d70778cb63256123fd1a6a024bec914a947de47ea500b75fc9216';
  static const String _getRawMediaHash =
      'a702cc4a4701f0e32fd666630ca707806dc502103f5810323c3ab32d98179fac';
  static const String _shareClipRenderStatusHash =
      '324783ea014524fa10a88739aa507de7a52f9624574dba9739a52b8c97d885cf';

  final TwitchApiClient client;
  final TwitchClipAccessTokenProvider accessTokenProvider;
  final TwitchClipClientIdProvider clientIdProvider;
  final TwitchClipAccessTokenProvider rawMediaAccessTokenProvider;
  final TwitchClipClientIdProvider rawMediaClientIdProvider;

  const TwitchClipApiService({
    required this.client,
    required this.accessTokenProvider,
    required this.clientIdProvider,
    required this.rawMediaAccessTokenProvider,
    required this.rawMediaClientIdProvider,
  });

  Future<TwitchCreateClipResult> createClip({
    required String broadcasterId,
  }) async {
    final cleanBroadcasterId = broadcasterId.trim();
    if (cleanBroadcasterId.isEmpty) {
      throw const TwitchApiException('缺少頻道 id，無法建立 Clip。');
    }

    final token = (await accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const TwitchApiException('沒有可用 OAuth，請先登入 Twitch。');
    }

    final clientId = (await clientIdProvider())?.trim();
    final raw = await client.postJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/clips',
      queryParameters: <String, dynamic>{'broadcaster_id': cleanBroadcasterId},
      headers: <String, String>{
        'Client-ID': clientId != null && clientId.isNotEmpty
            ? clientId
            : TwitchApiConstants.twitchWebClientId,
        'Authorization': 'Bearer $token',
      },
    );

    final data = raw['data'];
    final first = data is List && data.isNotEmpty ? data.first : null;
    if (first is! Map<String, dynamic>) {
      throw const TwitchApiException('Twitch 沒有回傳 Clip 資訊。');
    }

    final result = TwitchCreateClipResult.fromJson(first);
    if (result.id.isEmpty) {
      throw const TwitchApiException('Twitch 回傳的 Clip id 是空的。');
    }
    return result;
  }

  Future<TwitchLiveBroadcast> getLiveBroadcast({
    required String broadcasterId,
  }) async {
    final token = (await accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const TwitchApiException('沒有可用 OAuth，請先登入 Twitch。');
    }
    final clientId = (await clientIdProvider())?.trim();
    final raw = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/streams',
      queryParameters: <String, dynamic>{'user_id': broadcasterId.trim()},
      headers: <String, String>{
        'Client-ID': clientId != null && clientId.isNotEmpty
            ? clientId
            : TwitchApiConstants.twitchWebClientId,
        'Authorization': 'Bearer $token',
      },
    );
    final data = raw['data'];
    final first = data is List && data.isNotEmpty ? data.first : null;
    if (first is! Map<String, dynamic>) {
      throw const TwitchApiException('目前沒有直播，不能建立 Clip。');
    }
    final id = first['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const TwitchApiException('Twitch 沒有回傳直播 broadcast id。');
    }
    return TwitchLiveBroadcast(
      broadcastId: id,
      startedAt: DateTime.tryParse(first['started_at']?.toString() ?? ''),
    );
  }

  Future<TwitchClipEditSession> beginClipEdit({
    String? vodId,
    String? broadcastId,
    required double offsetSeconds,
  }) async {
    final cleanVodId = vodId?.trim();
    final cleanBroadcastId = broadcastId?.trim();
    if ((cleanVodId == null || cleanVodId.isEmpty) &&
        (cleanBroadcastId == null || cleanBroadcastId.isEmpty)) {
      throw const TwitchApiException('缺少 VOD 或 broadcast id，無法剪 Clip。');
    }

    final input = cleanBroadcastId != null && cleanBroadcastId.isNotEmpty
        ? <String, dynamic>{
            'vodID': null,
            'broadcastID': cleanBroadcastId,
            'offsetSeconds': offsetSeconds.round(),
          }
        : <String, dynamic>{
            'vodID': cleanVodId,
            'broadcastID': null,
            'offsetSeconds': offsetSeconds.round(),
          };

    String? rawMediaId;
    String lastError = 'Twitch 沒有回傳 raw media。';
    for (var attempt = 0; attempt < 4; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 4));
      }
      final raw = await _clipGql(
        operationName: 'CreateRawMedia',
        variables: <String, dynamic>{'input': input},
        hash: _createRawMediaHash,
      );
      rawMediaId = _readPath(raw, const <Object>[
        'data',
        'createRawMedia',
        'rawMedia',
        'id',
      ])?.toString();
      if (rawMediaId != null && rawMediaId.trim().isNotEmpty) break;
      lastError =
          _readPath(raw, const <Object>[
            'data',
            'createRawMedia',
            'error',
          ])?.toString() ??
          raw.toString();
      if (!lastError.contains('THROTTLED')) break;
    }

    final cleanRawMediaId = rawMediaId?.trim();
    if (cleanRawMediaId == null || cleanRawMediaId.isEmpty) {
      throw TwitchApiException('CreateRawMedia 失敗：$lastError');
    }

    for (var attempt = 0; attempt < 30; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      final raw = await _clipGql(
        operationName: 'GetRawMedia',
        variables: <String, dynamic>{'id': cleanRawMediaId},
        hash: _getRawMediaHash,
      );
      final rawMedia = _readPath(raw, const <Object>['data', 'rawMedia']);
      if (rawMedia is! Map) continue;
      final status = rawMedia['status']?.toString() ?? '';
      if (status.toUpperCase() != 'CREATED') continue;
      final rendition = _readPath(rawMedia, const <Object>[
        'assets',
        0,
        'renditions',
        0,
      ]);
      final previewUrl = rendition is Map
          ? rendition['sourceURL']?.toString().trim() ?? ''
          : '';
      final duration = rendition is Map
          ? double.tryParse(rendition['duration']?.toString() ?? '') ?? 0
          : 0.0;
      if (previewUrl.isNotEmpty) {
        return TwitchClipEditSession(
          rawMediaId: cleanRawMediaId,
          durationSeconds: duration,
          previewUrl: previewUrl,
        );
      }
    }

    throw const TwitchApiException('raw media 一直沒有完成處理。');
  }

  Future<TwitchCreateClipResult> finalizeClip({
    required String rawMediaId,
    required double startSeconds,
    required double durationSeconds,
    required String title,
  }) async {
    final cleanTitle = title.trim().isEmpty ? 'Clip' : title.trim();
    final variables = <String, dynamic>{
      'input': <String, dynamic>{
        'rawMediaID': rawMediaId.trim(),
        'shouldFeature': false,
        'shouldIncludeCaptions': false,
        'title': cleanTitle,
        'segments': <Map<String, dynamic>>[
          <String, dynamic>{
            'durationSeconds': durationSeconds.clamp(0.5, 60.0),
            'offsetSeconds': startSeconds.clamp(0.0, double.infinity),
          },
        ],
        'portraitMetadata': <String, dynamic>{
          'layout': 'FULL',
          'fullHeightMetadata': <String, dynamic>{
            'mainFrame': _defaultPortraitFrame(),
          },
        },
      },
    };

    String lastError = 'Twitch 沒有回傳 Clip。';
    for (var attempt = 0; attempt < 5; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      final raw = await _clipGql(
        operationName: 'ClipCreation_CreateClipFromRawMedia',
        variables: variables,
        hash: _createClipFromRawHash,
      );
      final slug = _readPath(raw, const <Object>[
        'data',
        'createClipFromRawMedia',
        'clip',
        'slug',
      ])?.toString();
      if (slug != null && slug.trim().isNotEmpty) {
        return TwitchCreateClipResult(
          id: slug.trim(),
          editUrl: 'https://clips.twitch.tv/${slug.trim()}/edit',
        );
      }
      lastError =
          _readPath(raw, const <Object>[
            'data',
            'createClipFromRawMedia',
            'error',
          ])?.toString() ??
          lastError;
    }

    throw TwitchApiException('clip finalize 失敗：$lastError');
  }

  Future<TwitchClipRenderStatus> getClipRenderStatus({
    required String clipSlug,
  }) async {
    final slug = clipSlug.trim();
    if (slug.isEmpty) {
      throw const TwitchApiException('缺少 Clip slug，無法確認處理狀態。');
    }

    final raw = await _clipGql(
      operationName: 'ShareClipRenderStatus',
      variables: <String, dynamic>{'slug': slug},
      hash: _shareClipRenderStatusHash,
    );
    final asset = _readPath(raw, const <Object>['data', 'clip', 'assets', 0]);
    if (asset is! Map) {
      return const TwitchClipRenderStatus(ready: false, thumbnailUrl: null);
    }

    final state = asset['creationState']?.toString() ?? '';
    final thumbnailUrl = asset['thumbnailURL']?.toString().trim();
    final qualities = asset['videoQualities'];
    final hasPlayableSource =
        qualities is List &&
        qualities.any((quality) {
          if (quality is! Map) return false;
          return (quality['sourceURL']?.toString().trim() ?? '').isNotEmpty;
        });

    return TwitchClipRenderStatus(
      ready: state.toUpperCase() == 'CREATED' && hasPlayableSource,
      thumbnailUrl: thumbnailUrl != null && thumbnailUrl.isNotEmpty
          ? thumbnailUrl
          : null,
    );
  }

  Future<TwitchClipRenderStatus> waitForClipRenderReady({
    required String clipSlug,
  }) async {
    TwitchClipRenderStatus? lastStatus;
    Object? lastError;
    for (var attempt = 0; attempt < 30; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      try {
        lastStatus = await getClipRenderStatus(clipSlug: clipSlug);
        if (lastStatus.ready) return lastStatus;
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError != null) {
      throw TwitchApiException('Clip 已建立，但 Twitch 還沒完成處理：$lastError');
    }
    return lastStatus ??
        const TwitchClipRenderStatus(ready: false, thumbnailUrl: null);
  }

  Future<Map<String, dynamic>> _clipGql({
    required String operationName,
    required Map<String, dynamic> variables,
    required String hash,
  }) async {
    final token = (await rawMediaAccessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const TwitchApiException('沒有 Drops / Android token，無法剪 Clip。');
    }
    final clientId = (await rawMediaClientIdProvider())?.trim();
    final raw = await client.postJson<Map<String, dynamic>>(
      TwitchApiConstants.gqlEndpoint,
      data: <String, dynamic>{
        'operationName': operationName,
        'variables': variables,
        'extensions': <String, dynamic>{
          'persistedQuery': <String, dynamic>{'version': 1, 'sha256Hash': hash},
        },
      },
      headers: <String, String>{
        'Client-ID': clientId != null && clientId.isNotEmpty
            ? clientId
            : TwitchApiConstants.twitchDefaultDropsClientId,
        'Authorization': 'OAuth $token',
        'Origin': 'https://www.twitch.tv',
        'Referer': 'https://www.twitch.tv/',
        'Accept-Language': 'en-US',
        'X-Device-Id': const Uuid().v4().replaceAll('-', ''),
        'Client-Session-Id': const Uuid().v4().replaceAll('-', ''),
      },
    );
    final errors = raw['errors'];
    if (errors != null) {
      throw TwitchApiException('$operationName GQL 錯誤：$errors');
    }
    return raw;
  }

  static Object? _readPath(Object? value, List<Object> path) {
    Object? current = value;
    for (final part in path) {
      if (part is String && current is Map) {
        current = current[part];
      } else if (part is int && current is List && current.length > part) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  static Map<String, dynamic> _defaultPortraitFrame() {
    return <String, dynamic>{
      'topLeft': <String, dynamic>{'xPercentage': 34.1796875, 'yPercentage': 0},
      'bottomRight': <String, dynamic>{
        'xPercentage': 65.8203125,
        'yPercentage': 100,
      },
    };
  }
}
