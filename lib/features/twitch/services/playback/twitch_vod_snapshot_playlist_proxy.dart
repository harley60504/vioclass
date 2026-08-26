import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../api/core/twitch_api_constants.dart';

class TwitchVodSnapshotPlaylistProxy {
  final Dio _dio;

  HttpServer? _server;
  String _playlistText = '';

  TwitchVodSnapshotPlaylistProxy({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 12),
            ),
          );

  Future<Uri> openSnapshot(Uri sourceUri) async {
    final response = await _dio.getUri<String>(
      sourceUri,
      options: Options(
        responseType: ResponseType.plain,
        headers: const <String, String>{
          'Accept': 'application/x-mpegURL, application/vnd.apple.mpegurl, */*',
          'Origin': 'https://www.twitch.tv',
          'Referer': 'https://www.twitch.tv/',
          'User-Agent': TwitchApiConstants.browserUserAgent,
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    final sourceText = response.data ?? '';
    if (statusCode >= 400 || !sourceText.contains('#EXTM3U')) {
      throw StateError('DVR snapshot playlist 載入失敗：HTTP $statusCode');
    }

    _playlistText = _rewriteAsVodSnapshot(sourceUri, sourceText);
    final server = await _ensureServer();
    return Uri.parse('http://127.0.0.1:${server.port}/playlist.m3u8');
  }

  Future<void> dispose() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<HttpServer> _ensureServer() async {
    final existing = _server;
    if (existing != null) return existing;

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(_serve(server));
    return server;
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      if (request.uri.path != '/playlist.m3u8') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }

      request.response.headers.contentType = ContentType(
        'application',
        'vnd.apple.mpegurl',
      );
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      request.response.write(_playlistText);
      await request.response.close();
    }
  }

  String _rewriteAsVodSnapshot(Uri sourceUri, String sourceText) {
    final output = <String>[];
    var hasPlaylistType = false;
    var hasEndList = false;

    for (final rawLine in sourceText.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXT-X-PLAYLIST-TYPE:')) {
        output.add('#EXT-X-PLAYLIST-TYPE:VOD');
        hasPlaylistType = true;
        continue;
      }

      if (line == '#EXT-X-ENDLIST') {
        hasEndList = true;
        output.add(line);
        continue;
      }

      if (line.startsWith('#ID3-EQUIV-TDTG:') ||
          line.startsWith('#EXT-X-TWITCH-ELAPSED-SECS:') ||
          line.startsWith('#EXT-X-TWITCH-TOTAL-SECS:')) {
        continue;
      }

      if (line.startsWith('#')) {
        output.add(line);
        continue;
      }

      output.add(sourceUri.resolve(line).toString());
    }

    if (!hasPlaylistType) {
      final index = output.indexWhere((line) => line.startsWith('#EXTM3U'));
      output.insert(index >= 0 ? index + 1 : 0, '#EXT-X-PLAYLIST-TYPE:VOD');
    }
    if (!hasEndList) output.add('#EXT-X-ENDLIST');

    return '${output.join('\n')}\n';
  }
}
