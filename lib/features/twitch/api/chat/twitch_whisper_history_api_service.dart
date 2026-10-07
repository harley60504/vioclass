import 'package:flutter/foundation.dart';

import '../auth/twitch_auth_api_service.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../../models/chat/twitch_whisper_conversation.dart';
import '../../models/chat/twitch_whisper_remote_history.dart';
import 'twitch_whisper_api_service.dart';

/// Read-only private Twitch Web GQL. Does not discover unknown conversation peers.
class TwitchWhisperHistoryApiService {
  static int _diagnosticSequence = 0;
  static const operation = 'Whispers_Thread_WhisperThread';
  static const hash =
      'c11d356f7e2d8a2b7da3f90c11487414b7fb188649bafe331e93937a5da2310d';
  final TwitchApiClient client;
  final List<Future<String?> Function()> webTokenProviders;
  final Future<Map<String, String>> Function(TwitchWhisperSession)?
  integrityHeadersProvider;
  final Future<void> Function(TwitchWhisperSession, String)?
  integrityInvalidator;
  TwitchWhisperHistoryApiService({
    required this.client,
    required this.webTokenProviders,
    this.integrityHeadersProvider,
    this.integrityInvalidator,
  });

  static String threadId(String owner, String peer) {
    if (!RegExp(r'^\d+$').hasMatch(owner) ||
        !RegExp(r'^\d+$').hasMatch(peer) ||
        owner == peer) {
      throw const TwitchWhisperException('私訊歷史的帳號或對象無效。');
    }
    // Official inbox responses order IDs numerically. Lexical ordering puts
    // a 10-digit ID beginning with 1 before a smaller 9-digit ID.
    return BigInt.parse(owner) < BigInt.parse(peer)
        ? '${owner}_$peer'
        : '${peer}_$owner';
  }

  Future<TwitchWhisperSession> webSession(String owner) async {
    for (final provider in webTokenProviders) {
      try {
        final token = (await provider())?.trim();
        if (token == null || token.isEmpty) continue;
        final validation = await TwitchAuthApiService(
          client: client,
        ).validateToken(token);
        if (validation.userId == owner &&
            validation.clientId == TwitchApiConstants.twitchWebClientId) {
          return TwitchWhisperSession(token, validation);
        }
      } catch (_) {
        /* Never store credentials or fall back to another account. */
      }
    }
    throw const TwitchWhisperException('私訊歷史需要同一帳號的 Twitch Web 授權。');
  }

  Future<TwitchWhisperRemotePage> page({
    required String ownerId,
    required String peerId,
    String? cursor,
  }) => _page(ownerId: ownerId, peerId: peerId, cursor: cursor);

  Future<TwitchWhisperRemotePage> _page({
    required String ownerId,
    required String peerId,
    String? cursor,
    bool retryIntegrity = true,
  }) async {
    final id = threadId(ownerId, peerId);
    if (cursor != null && (cursor.isEmpty || cursor.length > 4096)) {
      throw const TwitchWhisperException('私訊歷史分頁游標無效。');
    }
    final trace = ++_diagnosticSequence;
    final watch = Stopwatch()..start();
    var phase = 'web-session';
    void log(String summary) {
      if (kDebugMode) {
        debugPrint(
          '[WhisperHistory#$trace][${watch.elapsedMilliseconds}ms] '
          '$phase $summary',
        );
      }
    }

    log('start directHTTP=true cursorPresent=${cursor != null}');
    try {
      final session = await webSession(ownerId);
      log('validated sameOwner=${session.validation.userId == ownerId}');
      final integrityHeaders =
          await integrityHeadersProvider?.call(session) ?? <String, String>{};
      phase = 'gql';
      final response = await client.postJson<dynamic>(
        TwitchApiConstants.gqlEndpoint,
        headers: {
          'Client-ID': session.validation.clientId,
          'Authorization': 'OAuth ${session.token}',
          ...integrityHeaders,
        },
        data: [
          {
            'operationName': operation,
            'variables': {'id': id, 'cursor': ?cursor},
            'extensions': {
              'persistedQuery': {'version': 1, 'sha256Hash': hash},
            },
          },
        ],
      );
      final result = response is List && response.length == 1
          ? response.single
          : response;
      final errors = result is Map ? result['errors'] : null;
      final integrityRejected =
          errors is List &&
          errors.any(
            (error) =>
                error is Map && error['message'] == 'failed integrity check',
          );
      log(
        'HTTP=2xx errors=${errors is List ? errors.length : 0} '
        'integrityRejected=$integrityRejected',
      );
      if (integrityRejected && retryIntegrity && integrityInvalidator != null) {
        await integrityInvalidator!(
          session,
          integrityHeaders['Client-Integrity'] ?? '',
        );
        log('refresh rejected verification and retry once');
        return _page(
          ownerId: ownerId,
          peerId: peerId,
          cursor: cursor,
          retryIntegrity: false,
        );
      }
      phase = 'parse';
      final page = parse(
        response,
        ownerId: ownerId,
        peerId: peerId,
        cursor: cursor,
        diagnostic: log,
      );
      log(
        'success messages=${page.messages.length} '
        'nextCursorPresent=${page.nextCursor != null}',
      );
      return page;
    } on TwitchWhisperException {
      log('failed featureException; no archive write');
      rethrow;
    } catch (_) {
      log('failed requestException; no archive write');
      throw const TwitchWhisperException('私訊歷史讀取失敗，既有資料保持不變。');
    }
  }

  static TwitchWhisperRemotePage parse(
    dynamic response, {
    required String ownerId,
    required String peerId,
    String? cursor,
    void Function(String)? diagnostic,
  }) {
    threadId(ownerId, peerId);
    var stage = 'response/batch';
    try {
      diagnostic?.call(
        'responseType=${response.runtimeType} '
        'batchCount=${response is List ? response.length : -1}',
      );
      if (response is! List ||
          response.length != 1 ||
          response.single is! Map) {
        throw const FormatException();
      }
      final result = response.single as Map;
      stage = 'response/errors';
      if (result['errors'] != null &&
          (result['errors'] is! List ||
              (result['errors'] as List).isNotEmpty)) {
        throw const FormatException();
      }
      stage = 'data';
      final data = result['data'] as Map;
      stage = 'data/whisperThread';
      diagnostic?.call('threadType=${data['whisperThread'].runtimeType}');
      final thread = data['whisperThread'] as Map;
      stage = 'whisperThread/messages';
      final connection = thread['messages'] as Map;
      stage = 'messages/edges';
      final edges = connection['edges'] as List;
      diagnostic?.call(
        'edges=${edges.length} '
        'pageInfoPresent=${connection['pageInfo'] != null}',
      );
      if (edges.length > 500) throw const FormatException();
      final messages = <TwitchWhisperMessage>[];
      final ids = <String>{};
      String? lastCursor;
      for (final value in edges) {
        stage = 'messages/edges/cursor';
        final edge = value as Map;
        final edgeCursor = edge['cursor'] as String;
        diagnostic?.call(
          'edgeIndex=${messages.length} '
          'cursorEmpty=${edgeCursor.isEmpty}',
        );
        if (edgeCursor.isEmpty || edgeCursor.length > 4096) {
          throw const FormatException();
        }
        lastCursor = edgeCursor;
        stage = 'messages/edges/node';
        final node = edge['node'] as Map;
        stage = 'messages/edges/node/from';
        final sender = (node['from'] as Map)['id'] as String;
        stage = 'messages/edges/node/id';
        final id = node['id'] as String;
        stage = 'messages/edges/node/content';
        final text = (node['content'] as Map)['content'] as String;
        stage = 'messages/edges/node/sentAt';
        final time = DateTime.parse(node['sentAt'] as String).toUtc();
        stage = 'messages/edges/node/identity';
        if ((sender != ownerId && sender != peerId) ||
            id.isEmpty ||
            !ids.add(id) ||
            text.length > 20000) {
          throw const FormatException();
        }
        messages.add(
          TwitchWhisperMessage(
            id: id,
            fromUserId: sender,
            toUserId: sender == ownerId ? peerId : ownerId,
            text: text,
            timestamp: time,
            state: sender == ownerId
                ? TwitchWhisperMessageState.submitted
                : TwitchWhisperMessageState.received,
          ),
        );
      }
      stage = 'messages/pageInfo';
      final info = connection['pageInfo'];
      if (info != null) {
        if (info is! Map || info['hasNextPage'] is! bool) {
          throw const FormatException();
        }
        if (info['hasNextPage'] == false) {
          lastCursor = null;
        } else if (lastCursor == null) {
          throw const FormatException();
        }
      }
      stage = 'messages/nextCursor';
      if (lastCursor != null && lastCursor == cursor) {
        throw const FormatException();
      }
      return TwitchWhisperRemotePage(
        ownerId: ownerId,
        peerId: peerId,
        messages: messages,
        requestedCursor: cursor,
        nextCursor: lastCursor,
      );
    } catch (_) {
      diagnostic?.call('formatFailure stage=$stage');
      throw TwitchWhisperException('私訊歷史回應不完整（$stage），未合併資料。');
    }
  }
}
