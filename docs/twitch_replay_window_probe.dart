// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import 'package:vioclass/features/twitch/api/playback/twitch_playback_api_service.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_m3u8_variant.dart';

import 'package:vioclass/features/twitch/parsers/playback/twitch_hls_playlist_parser.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_playlist_player_runtime.dart';
import 'twitch_native_log_diagnostics.dart';

Future<List<Map<String, Object?>>> probeChannelLiveFormats(
  TwitchPlaybackApiService api,
  String channelLogin, {
  String platform = 'web',
  String playerType = 'site',
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final token = await api.getLivePlaybackAccessToken(
      channelLogin: channelLogin,
      platform: platform,
      playerType: playerType,
    );
    final uri = api.buildLivePlaylistUri(
      channelLogin: channelLogin,
      accessToken: token,
    );
    final request = await client.getUrl(uri);
    TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders.forEach(
      request.headers.set,
    );
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      return [
        {'masterStatus': response.statusCode},
      ];
    }
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
    final variants = TwitchM3u8Parser.parseMasterPlaylist(
      text,
      masterUri: uri,
    ).where((variant) => !variant.isAudioOnly).take(3).toList();
    return [
      for (var i = 0; i < variants.length; i++)
        {
          'variantIndex': i,
          ...await probeLiveVariantFormat(Uri.parse(variants[i].url)),
        },
    ];
  } catch (error) {
    return [
      {'errorType': error.runtimeType.toString()},
    ];
  } finally {
    client.close(force: true);
  }
}

/// A bounded media prefix probe, not a decoder or advertising assertion.
Future<Map<String, Object?>> probeLiveVariantFormat(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final request = await client.getUrl(uri);
    TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders.forEach(
      request.headers.set,
    );
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      return {'playlistStatus': response.statusCode};
    }
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
    final parsed = TwitchHlsPlaylistParser.parse(
      text,
      playlistUrl: uri.toString(),
    );
    final items = parsed.items.where((item) => !item.isPrefetch).toList();
    if (items.isEmpty) {
      return {'playlistStatus': 200, 'format': 'no-media'};
    }
    final media = await client.getUrl(Uri.parse(items.last.url));
    TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders.forEach(
      media.headers.set,
    );
    media.headers.set('Range', 'bytes=0-4095');
    final segment = await media.close().timeout(const Duration(seconds: 8));
    final bytes = <int>[];
    await for (final chunk in segment.timeout(const Duration(seconds: 8))) {
      bytes.addAll(chunk.take(4096 - bytes.length));
      if (bytes.length >= 4096) {
        break;
      }
    }
    final hints = twitchMediaHeaderHints(bytes);
    return {
      'playlistStatus': 200,
      'segmentStatus': segment.statusCode,
      'bytes': bytes.length,
      'hasInitMap': text.contains('#EXT-X-MAP:'),
      'format': segment.statusCode != 200 && segment.statusCode != 206
          ? 'http-failure'
          : hints['mp4BoxAtStart'] == true
          ? 'fmp4'
          : hints['tsSyncAtStart'] == true
          ? 'mpegts'
          : 'unknown',
    };
  } catch (error) {
    return {'errorType': error.runtimeType.toString()};
  } finally {
    client.close(force: true);
  }
}

Future<List<Map<String, Object?>>> probeChannelReplayWindows(
  TwitchPlaybackApiService api,
  String channelLogin,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final token = await api.getLivePlaybackAccessToken(
      channelLogin: channelLogin,
    );
    final uri = api.buildLivePlaylistUri(
      channelLogin: channelLogin,
      accessToken: token,
    );
    final request = await client.getUrl(uri);
    TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders.forEach(
      request.headers.set,
    );
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      await response.drain<void>();
      return [
        {'masterStatus': response.statusCode},
      ];
    }
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
    final variants = TwitchM3u8Parser.parseMasterPlaylist(
      text,
      masterUri: uri,
    ).where((variant) => !variant.isAudioOnly).take(3).toList();
    final results = <Map<String, Object?>>[];
    for (final variant in variants) {
      results.add(await probeReplayWindow(Uri.parse(variant.url)));
    }
    return results;
  } catch (error) {
    return [
      {'errorType': error.runtimeType.toString()},
    ];
  } finally {
    client.close(force: true);
  }
}

/// Read-only probe. Returns numbers only, never signed URLs or identities.
Future<Map<String, Object?>> probeReplayWindow(Uri playlistUri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  Future<HttpClientResponse> get(Uri uri) async {
    final request = await client.getUrl(uri);
    TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders.forEach(
      request.headers.set,
    );
    return request.close().timeout(const Duration(seconds: 8));
  }

  try {
    final response = await get(playlistUri);
    if (response.statusCode != 200) {
      await response.drain<void>();
      return {'playlistStatus': response.statusCode};
    }
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
    final playlist = TwitchHlsPlaylistParser.parse(
      text,
      playlistUrl: playlistUri.toString(),
    );
    final bySequence = {
      for (final item in playlist.items)
        if (!item.isPrefetch) item.sequence: item,
    };
    final items = bySequence.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    var duration = Duration.zero;
    for (final item in items) {
      duration += item.duration;
    }
    int? oldestStatus;
    var oldestBytes = 0;
    if (items.isNotEmpty) {
      final oldest = await get(Uri.parse(items.first.url));
      oldestStatus = oldest.statusCode;
      await for (final chunk in oldest.timeout(const Duration(seconds: 8))) {
        oldestBytes += chunk.length;
      }
    }
    return {
      'adMarkerPresent': RegExp(
        r'twitch-stitched-ad|stitched-ad|X-TV-TWITCH-AD',
        caseSensitive: false,
      ).hasMatch(text),
      'normalSegments': items.length,
      'normalWindowMs': duration.inMilliseconds,
      'canonicalWindowMs':
          playlist.twitchTotal == null || playlist.twitchElapsed == null
          ? null
          : (playlist.twitchTotal! - playlist.twitchElapsed!).inMilliseconds,
      'futureSegments': playlist.futureCount,
      'firstSegmentMs': items.isEmpty
          ? null
          : items.first.duration.inMilliseconds,
      'lastSegmentMs': items.isEmpty
          ? null
          : items.last.duration.inMilliseconds,
      'oldestStatus': oldestStatus,
      'oldestBytes': oldestBytes,
    };
  } catch (error) {
    return {'errorType': error.runtimeType.toString()};
  } finally {
    client.close(force: true);
  }
}
