import 'package:flutter/foundation.dart';

import '../core/twitch_api_constants.dart';
import '../core/twitch_api_exception.dart';
import '../../models/chat/twitch_whisper_conversation.dart';
import '../../models/chat/twitch_whisper_remote_history.dart';
import 'twitch_whisper_api_service.dart';
import 'twitch_whisper_history_api_service.dart';

class TwitchWhisperIntegrityContext {
  final String ownerId, clientId, token, deviceId, userAgent;
  final DateTime expiresAt;
  const TwitchWhisperIntegrityContext({
    required this.ownerId,
    required this.clientId,
    required this.token,
    required this.deviceId,
    required this.userAgent,
    required this.expiresAt,
  });

  Map<String, String> headersFor(TwitchWhisperSession session) {
    if (ownerId != session.validation.userId ||
        clientId != session.validation.clientId ||
        !expiresAt.isAfter(DateTime.now().toUtc()) ||
        token.isEmpty ||
        token.length > 16384 ||
        !RegExp(r'^[a-zA-Z0-9_-]{16,128}$').hasMatch(deviceId) ||
        userAgent.isEmpty ||
        userAgent.length > 1024 ||
        token.contains(RegExp(r'[\r\n]')) ||
        userAgent.contains(RegExp(r'[\r\n]'))) {
      throw const TwitchWhisperException('完整性工作階段不匹配或已過期，未發送列表請求。');
    }
    return {
      'Client-Integrity': token,
      'X-Device-ID': deviceId,
      'Device-ID': deviceId,
      'User-Agent': userAgent,
    };
  }
}

/// Private read-only GQL query; no existing persisted hash is changed.
class TwitchWhisperThreadsApiService {
  static int _diagnosticSequence = 0;
  final TwitchWhisperHistoryApiService history;
  final Future<Object> Function(String? cursor)? browserResponse;
  final Future<TwitchWhisperIntegrityContext> Function(TwitchWhisperSession)?
  integrityProvider;
  final Future<void> Function(TwitchWhisperSession, String)?
  integrityInvalidator;
  TwitchWhisperThreadsApiService({
    required this.history,
    this.browserResponse,
    this.integrityProvider,
    this.integrityInvalidator,
  });

  static DateTime _parseTimestamp(String value) {
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException {
      final match = RegExp(
        r'^(\d{4})/(\d{1,2})/(\d{1,2}) (上午|下午) (\d{1,2}):(\d{2}):(\d{2})$',
      ).firstMatch(value);
      if (match == null) throw const FormatException();
      var hour = int.parse(match.group(5)!);
      if (match.group(4) == '下午' && hour < 12) hour += 12;
      if (match.group(4) == '上午' && hour == 12) hour = 0;
      return DateTime.utc(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        hour,
        int.parse(match.group(6)!),
        int.parse(match.group(7)!),
      );
    }
  }

  static const operation = 'Whispers_Whispers_UserWhisperThreads';
  static const hash =
      'b9535d107dc5b016645d2ef895c295e8001df6ff89ca26231599e0d11b2a5927';

  Future<TwitchWhisperThreadsPage> page({
    required String ownerId,
    String? cursor,
  }) => _page(ownerId: ownerId, cursor: cursor);

  Future<TwitchWhisperThreadsPage> _page({
    required String ownerId,
    String? cursor,
    bool retryIntegrity = true,
  }) async {
    if (!RegExp(r'^\d+$').hasMatch(ownerId) ||
        (cursor != null && (cursor.isEmpty || cursor.length > 4096))) {
      throw const TwitchWhisperException('私訊列表帳號或分頁位置無效。');
    }
    final trace = ++_diagnosticSequence;
    final watch = Stopwatch()..start();
    var phase = 'web-session';
    void log(String summary) {
      if (kDebugMode) {
        debugPrint(
          '[WhisperThreads#$trace][${watch.elapsedMilliseconds}ms] '
          '$phase $summary',
        );
      }
    }

    log('start operation=$operation cursorPresent=${cursor != null}');
    try {
      final browser = browserResponse;
      if (browser != null) {
        phase = 'official-browser';
        log('waiting for official page response');
        final response = await browser(cursor);
        final page = parse(
          response,
          ownerId: ownerId,
          cursor: cursor,
          diagnostic: log,
        );
        log('success conversations=${page.conversations.length}');
        return page;
      }
      final session = await history.webSession(ownerId);
      log(
        'validated sameOwner=${session.validation.userId == ownerId} '
        'webClient=${session.validation.clientId == TwitchApiConstants.twitchWebClientId}',
      );
      phase = 'integrity';
      Map<String, String> integrityHeaders;
      final provider = integrityProvider;
      if (provider != null) {
        log('officialSDK acquisition; response is not a whisper list');
        final context = await provider(session);
        integrityHeaders = context.headersFor(session);
        log('context validated pairedDevice=true');
      } else {
        log(
          'POST /integrity browserRuntime=false deviceHeader=false sessionHeader=false',
        );
        final integrity = await history.client.postJson<dynamic>(
          TwitchApiConstants.gqlIntegrityEndpoint,
          headers: {
            'Client-ID': session.validation.clientId,
            'Authorization': 'OAuth ${session.token}',
            'Origin': 'https://www.twitch.tv',
            'Referer': 'https://www.twitch.tv/',
            'User-Agent': TwitchApiConstants.browserUserAgent,
          },
          data: const {},
        );
        final clientIntegrity = integrity is Map && integrity['token'] is String
            ? (integrity['token'] as String).trim()
            : '';
        final expiration = integrity is Map ? integrity['expiration'] : null;
        log(
          'HTTP=2xx type=${integrity.runtimeType} '
          'tokenPresent=${clientIntegrity.isNotEmpty} '
          'expirationFuture=${expiration is num && expiration > DateTime.now().millisecondsSinceEpoch}',
        );
        if (clientIntegrity.isEmpty) {
          throw const TwitchWhisperException('Twitch 完整性驗證 token 無效。');
        }
        integrityHeaders = {
          'Client-Integrity': clientIntegrity,
          'User-Agent': TwitchApiConstants.browserUserAgent,
        };
      }
      phase = 'gql';
      log('POST /gql batch=1 persisted=true integrityHeader=true');
      final response = await history.client.postJson<dynamic>(
        TwitchApiConstants.gqlEndpoint,
        headers: {
          'Client-ID': session.validation.clientId,
          'Authorization': 'OAuth ${session.token}',
          'Origin': 'https://www.twitch.tv',
          'Referer': 'https://www.twitch.tv/',
          ...integrityHeaders,
        },
        // Exact Twitch Web request captured from the user's Network payload.
        data: [
          {
            'operationName': operation,
            'variables': {'cursor': cursor ?? ''},
            'extensions': {
              'persistedQuery': {'version': 1, 'sha256Hash': hash},
            },
          },
        ],
      );
      final result = response is List && response.length == 1
          ? response.single
          : response;
      final extensions = result is Map ? result['extensions'] : null;
      final serverId = extensions is Map ? extensions['requestID'] : null;
      final safeId =
          serverId is String &&
              RegExp(r'^[a-zA-Z0-9-]{1,80}$').hasMatch(serverId)
          ? serverId
          : 'unavailable';
      final errors = result is Map ? result['errors'] : null;
      final integrityRejected =
          errors is List &&
          errors.any(
            (error) =>
                error is Map && error['message'] == 'failed integrity check',
          );
      log(
        'HTTP=2xx type=${response.runtimeType} '
        'errors=${errors is List ? errors.length : 0} '
        'integrityRejected=$integrityRejected serverRequestId=$safeId',
      );
      phase = 'parse';
      if (integrityRejected && retryIntegrity && integrityInvalidator != null) {
        await integrityInvalidator!(
          session,
          integrityHeaders['Client-Integrity'] ?? '',
        );
        log('refresh rejected verification and retry once');
        return _page(ownerId: ownerId, cursor: cursor, retryIntegrity: false);
      }
      final page = parse(
        response,
        ownerId: ownerId,
        cursor: cursor,
        diagnostic: log,
      );
      log(
        'success conversations=${page.conversations.length} '
        'messages=${page.conversations.fold<int>(0, (n, peer) => n + peer.messages.length)} '
        'nextCursorPresent=${page.nextCursor != null}',
      );
      return page;
    } on TwitchWhisperException {
      log('failed featureException; no archive write');
      rethrow;
    } on TwitchApiException catch (error) {
      log('failed HTTP=${error.statusCode ?? 'unknown'}; no archive write');
      throw TwitchWhisperException(
        'Twitch 對話列表 $phase 請求失敗 '
        '（HTTP ${error.statusCode ?? '未知'}），既有對話保持不變。',
      );
    } catch (_) {
      log('failed unexpectedException; no archive write');
      throw const TwitchWhisperException('Twitch 對話列表讀取失敗，既有對話保持不變。');
    }
  }

  static TwitchWhisperThreadsPage parse(
    dynamic response, {
    required String ownerId,
    String? cursor,
    void Function(String)? diagnostic,
  }) {
    var stage = '回應外層';
    try {
      // Browser exports may wrap one GraphQL response in a single-element
      // array. The live client normally returns the inner map directly.
      final result = response is List && response.length == 1
          ? response.single
          : response;
      if (result is! Map) throw const FormatException();
      final errors = result['errors'];
      if (errors != null && (errors is! List || errors.isNotEmpty)) {
        final firstError = errors is List && errors.isNotEmpty
            ? errors.first
            : null;
        final message = firstError is Map && firstError['message'] is String
            ? (firstError['message'] as String)
            : '未知錯誤';
        if (message == 'failed integrity check') {
          throw const TwitchWhisperException(
            '既有登入已驗證，但 Twitch 拒絕對話列表完整性驗證。'
            '未開啟登入視窗，原對話與分頁位置保持不變。',
          );
        }
        throw TwitchWhisperException('Twitch 對話列表 GQL 錯誤：$message');
      }
      stage = 'data/currentUser';
      final user = (result['data'] as Map)['currentUser'] as Map;
      if (user['id'] != ownerId) throw const FormatException();
      stage = 'currentUser/whisperThreads';
      final connection = user['whisperThreads'] as Map;
      final edges = connection['edges'] as List;
      diagnostic?.call('edges=${edges.length}');
      if (edges.length > 500) throw const FormatException();
      stage = 'whisperThreads/pageInfo';
      // Captured Web responses omit pageInfo but provide edge cursors.
      // Absence alone does not prove completion: preserve the server's last
      // nonempty cursor for continuation. Never synthesize a cursor.
      final rawInfo = connection['pageInfo'];
      final hasNextPage = rawInfo == null
          ? null
          : rawInfo is Map && rawInfo['hasNextPage'] is bool
          ? rawInfo['hasNextPage'] as bool
          : throw const FormatException();
      final peers = <String>{};
      final conversations = <TwitchWhisperConversation>[];
      String? lastCursor;
      for (final value in edges) {
        stage = 'whisperThreads/edges/cursor';
        final edge = value as Map;
        final edgeCursor = edge['cursor'] as String;
        if (edgeCursor.length > 4096) {
          throw const FormatException();
        }
        lastCursor = edgeCursor;
        final node = edge['node'] as Map;
        stage = 'whisperThreads/edges/participants';
        final participants = node['participants'] as List;
        if (participants.length != 2 ||
            participants
                    .where((value) => (value as Map)['id'] == ownerId)
                    .length !=
                1) {
          throw const FormatException();
        }
        final peer =
            participants.firstWhere((value) => (value as Map)['id'] != ownerId)
                as Map;
        stage = 'whisperThreads/edges/threadId';
        final peerId = peer['id'] as String;
        if (node['id'] !=
                TwitchWhisperHistoryApiService.threadId(ownerId, peerId) ||
            !peers.add(peerId)) {
          throw const FormatException();
        }
        stage = 'whisperThreads/edges/profile';
        final login = peer['login'] as String;
        final name = peer['displayName'] as String;
        final unread = node['unreadMessagesCount'] as int;
        if (!RegExp(r'^[a-zA-Z0-9_]{1,25}$').hasMatch(login) ||
            name.isEmpty ||
            unread < 0) {
          throw const FormatException();
        }
        final avatar = peer['profileImageURL'] as String?;
        if (avatar != null &&
            (Uri.tryParse(avatar)?.scheme != 'https' ||
                Uri.tryParse(avatar)?.host.isEmpty != false)) {
          throw const FormatException();
        }
        stage = 'whisperThreads/edges/messages';
        final messages = <TwitchWhisperMessage>[];
        final messageEdges = node['messages'] is Map
            ? ((node['messages'] as Map)['edges'] as List?) ?? const []
            : const [];
        for (final messageEdgeValue in messageEdges) {
          final messageNode = (messageEdgeValue as Map)['node'] as Map;
          final sender = (messageNode['from'] as Map)['id'] as String;
          final text =
              ((messageNode['content'] as Map)['content'] as String?) ?? '';
          final id = messageNode['id'] as String;
          if ((sender != ownerId && sender != peerId) ||
              id.isEmpty ||
              text.length > 20000) {
            throw const FormatException();
          }
          stage = 'whisperThreads/edges/messages/sentAt';
          messages.add(
            TwitchWhisperMessage(
              id: id,
              fromUserId: sender,
              toUserId: sender == ownerId ? peerId : ownerId,
              text: text,
              timestamp: _parseTimestamp(messageNode['sentAt'] as String),
              state: sender == ownerId
                  ? TwitchWhisperMessageState.submitted
                  : TwitchWhisperMessageState.received,
              historicalOnly: true,
            ),
          );
        }
        // Older responses/fixtures may expose only a preview lastMessage.
        // Captured Twitch Web responses use messages.edges above.
        if (messages.isEmpty && node['lastMessage'] is Map) {
          final last = node['lastMessage'] as Map;
          final sender = (last['from'] as Map)['id'] as String;
          final text = (last['content'] as Map)['content'] as String;
          final id = last['id'] as String;
          if ((sender != ownerId && sender != peerId) ||
              id.isEmpty ||
              text.length > 20000) {
            throw const FormatException();
          }
          messages.add(
            TwitchWhisperMessage(
              id: id,
              fromUserId: sender,
              toUserId: sender == ownerId ? peerId : ownerId,
              text: text,
              timestamp: _parseTimestamp(last['sentAt'] as String),
              state: sender == ownerId
                  ? TwitchWhisperMessageState.submitted
                  : TwitchWhisperMessageState.received,
            ),
          );
        }
        conversations.add(
          TwitchWhisperConversation(
            userId: peerId,
            login: login.toLowerCase(),
            displayName: name,
            avatarUrl: avatar,
            remoteUnreadCount: unread,
            messages: messages,
          ),
        );
      }
      final next = hasNextPage == false
          ? null
          : lastCursor?.isNotEmpty == true
          ? lastCursor
          : null;
      stage = 'whisperThreads/nextCursor';
      if ((hasNextPage == true && next == null) ||
          (next != null && next == cursor)) {
        throw const FormatException();
      }
      return TwitchWhisperThreadsPage(
        ownerId: ownerId,
        conversations: conversations,
        requestedCursor: cursor,
        nextCursor: next,
      );
    } on TwitchWhisperException {
      rethrow;
    } catch (_) {
      diagnostic?.call('formatFailure stage=$stage');
      throw TwitchWhisperException('Twitch 對話列表回應格式不符（$stage），未當作空列表。');
    }
  }
}
