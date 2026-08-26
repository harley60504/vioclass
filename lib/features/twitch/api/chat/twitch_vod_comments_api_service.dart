import 'package:dio/dio.dart';

import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../parsers/chat/twitch_chat_message_normalizer.dart';
import '../../parsers/chat/twitch_irc_message_parser.dart';
import '../../services/chat/twitch_badge_cache_service.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';

class TwitchVodComment {
  final double contentOffsetSeconds;
  final TwitchChatRuntimeMessage message;

  const TwitchVodComment({
    required this.contentOffsetSeconds,
    required this.message,
  });
}

class TwitchVodCommentsApiService {
  static const String _operationName = 'VideoCommentsByOffsetOrCursor';
  static const String _sha256Hash =
      'b70a3591ff0f4e0313d126c6a1502d79a1c02baebb288227c582044aa76adf6a';

  final TwitchApiClient client;
  final TwitchBadgeCacheService badgeCache;
  final TwitchIrcMessageParser _parser = const TwitchIrcMessageParser();

  TwitchVodCommentsApiService({
    required this.client,
    required this.badgeCache,
  });

  Future<List<TwitchVodComment>> fetchComments({
    required String videoId,
    required String channelLogin,
    required double offsetSeconds,
  }) async {
    final cleanVideoId = videoId.trim();
    final cleanChannel = channelLogin.trim().toLowerCase();
    if (cleanVideoId.isEmpty) {
      throw ArgumentError.value(videoId, 'videoId', 'video id cannot be empty');
    }

    final response = await client.dio.post<dynamic>(
      TwitchApiConstants.gqlEndpoint,
      data: <String, dynamic>{
        'operationName': _operationName,
        'variables': <String, dynamic>{
          'videoID': cleanVideoId,
          'contentOffsetSeconds': offsetSeconds.clamp(0, double.infinity).floor(),
        },
        'extensions': const <String, dynamic>{
          'persistedQuery': <String, dynamic>{
            'version': 1,
            'sha256Hash': _sha256Hash,
          },
        },
      },
      options: Options(
        headers: <String, String>{
          'Client-ID': TwitchApiConstants.twitchWebClientId,
          'Origin': 'https://www.twitch.tv',
          'Referer': 'https://www.twitch.tv',
          'User-Agent': TwitchApiConstants.browserUserAgent,
          'X-Device-Id': _sessionId(),
          'Client-Session-Id': _sessionId(),
        },
      ),
    );

    final data = response.data;
    final edges = _readEdges(data);
    final normalizer = TwitchChatMessageNormalizer(badgeCache: badgeCache);
    return edges.map((edge) {
      final node = _asMap(edge['node']);
      final offset = _readDouble(node['contentOffsetSeconds']);
      final rawLine = _buildIrcLine(node, cleanChannel);
      final message = _parser.parseLine(rawLine);
      return TwitchVodComment(
        contentOffsetSeconds: offset,
        message: normalizer.normalize(
          message,
          receivedAt: normalizer.readMessageTimeOrNow(message),
        ),
      );
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> _readEdges(dynamic raw) {
    final root = _asMap(raw);
    final data = _asMap(root['data']);
    final video = _asMap(data['video']);
    final comments = _asMap(video['comments']);
    final edges = comments['edges'];
    if (edges is! List) return const <Map<String, dynamic>>[];
    return edges.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  String _buildIrcLine(Map<String, dynamic> node, String channelLogin) {
    final commenter = _asMap(node['commenter']);
    final message = _asMap(node['message']);
    final login = (commenter['login']?.toString() ?? 'unknown').toLowerCase();
    final displayName =
        commenter['displayName']?.toString() ??
        commenter['login']?.toString() ??
        'unknown';
    final userId = commenter['id']?.toString() ?? '';
    final createdAt = DateTime.tryParse(node['createdAt']?.toString() ?? '');
    final ts = createdAt?.millisecondsSinceEpoch ?? 0;
    final fragments = message['fragments'];
    final buffer = StringBuffer();
    final emotes = <String>[];
    var cursor = 0;

    if (fragments is List) {
      for (final rawFragment in fragments.whereType<Map<String, dynamic>>()) {
        final text = rawFragment['text']?.toString() ?? '';
        final emote = _asMap(rawFragment['emote']);
        final emoteId = emote['emoteID']?.toString() ?? '';
        final length = text.runes.length;
        if (emoteId.isNotEmpty && length > 0) {
          emotes.add('$emoteId:$cursor-${cursor + length - 1}');
        }
        buffer.write(text.replaceAll(RegExp(r'[\r\n]'), ' '));
        cursor += length;
      }
    }

    final badges = <String>[];
    final rawBadges = message['userBadges'];
    if (rawBadges is List) {
      for (final rawBadge in rawBadges.whereType<Map<String, dynamic>>()) {
        final setId = rawBadge['setID']?.toString() ?? '';
        final version = rawBadge['version']?.toString() ?? '';
        if (setId.isNotEmpty) badges.add('${_sanitizeTag(setId)}/${_sanitizeTag(version)}');
      }
    }

    final tags = <String>[
      'vod-offset=${_readDouble(node['contentOffsetSeconds'])}',
      'id=${_sanitizeTag(node['id']?.toString() ?? '')}',
      'user-id=${_sanitizeTag(userId)}',
      'display-name=${_sanitizeTag(displayName)}',
      'tmi-sent-ts=$ts',
      if ((message['userColor']?.toString() ?? '').isNotEmpty)
        'color=${_sanitizeTag(message['userColor'].toString())}',
      if (badges.isNotEmpty) 'badges=${badges.join(',')}',
      if (emotes.isNotEmpty) 'emotes=${emotes.join('/')}',
    ];

    return '@${tags.join(';')} :$login!$login@$login.tmi.twitch.tv '
        'PRIVMSG #$channelLogin :$buffer';
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _sanitizeTag(String value) {
    return value.replaceAll(RegExp(r'[; \\\r\n]'), '');
  }

  static String _sessionId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  }
}
