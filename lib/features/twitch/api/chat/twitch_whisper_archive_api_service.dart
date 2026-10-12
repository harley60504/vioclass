import '../core/twitch_api_constants.dart';
import 'twitch_whisper_api_service.dart';
import 'twitch_whisper_history_api_service.dart';

/// Official Web archive mutation captured from Twitch's conversation menu.
/// It archives the caller's thread; it does not delete both users' messages.
class TwitchWhisperArchiveApiService {
  static const operation = 'Thread_ArchiveThread';
  static const hash =
      '4b4ef44b3b0a51ead216b83cfb340051ba49e4af12cf5eda580f6c5d609396c5';
  final TwitchWhisperHistoryApiService history;

  const TwitchWhisperArchiveApiService({required this.history});

  Future<void> archive({
    required String ownerId,
    required String peerId,
    required bool Function() canApply,
  }) async {
    final id = TwitchWhisperHistoryApiService.threadId(ownerId, peerId);
    void requireCurrent() {
      if (!canApply()) {
        throw const TwitchWhisperException('登入帳號已變更，未送出封存。');
      }
    }

    try {
      requireCurrent();
      final session = await history.webSession(ownerId);
      requireCurrent();
      for (var attempt = 0; attempt < 2; attempt++) {
        final proof = await history.integrityHeadersProvider?.call(session);
        if (proof == null || (proof['Client-Integrity'] ?? '').isEmpty) {
          throw const TwitchWhisperException('尚未取得私訊驗證資料，未送出封存。');
        }
        requireCurrent();
        final response = await history.client.postJson<dynamic>(
          TwitchApiConstants.gqlEndpoint,
          headers: {
            'Client-ID': session.validation.clientId,
            'Authorization': 'OAuth ${session.token}',
            'Origin': 'https://www.twitch.tv',
            'Referer': 'https://www.twitch.tv/',
            ...proof,
          },
          data: [
            {
              'operationName': operation,
              'variables': {
                'input': {'threadID': id, 'isArchived': true},
              },
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
        final rejected =
            errors is List &&
            errors.any(
              (error) =>
                  error is Map && error['message'] == 'failed integrity check',
            );
        // Only a definite integrity rejection may retry once. A transport
        // timeout or malformed acknowledgement must never replay a mutation.
        if (rejected &&
            result is Map &&
            result['data'] == null &&
            attempt == 0 &&
            history.integrityInvalidator != null) {
          await history.integrityInvalidator!(
            session,
            proof['Client-Integrity']!,
          );
          requireCurrent();
          continue;
        }
        if (result is! Map ||
            (errors != null && (errors is! List || errors.isNotEmpty))) {
          throw const TwitchWhisperException('Twitch 未確認封存成功，原紀錄已保留。');
        }
        final data = result['data'];
        final payload = data is Map ? data['updateWhisperThread'] : null;
        final thread = payload is Map ? payload['thread'] : null;
        if (thread is! Map ||
            thread['id'] != id ||
            thread['isArchived'] != true) {
          throw const TwitchWhisperException('封存回應不完整或對話不符，原紀錄已保留。');
        }
        return;
      }
    } on TwitchWhisperException {
      rethrow;
    } catch (_) {
      throw const TwitchWhisperException(
        '封存結果尚未確認，原紀錄已保留；請先確認 Twitch 對話列表再重試。',
        outcomeUnknown: true,
      );
    }
  }
}
