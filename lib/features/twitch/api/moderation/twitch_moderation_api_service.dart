import 'package:dio/dio.dart';

import '../auth/twitch_auth_api_service.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../../models/chat/twitch_blocked_term.dart';
import '../../models/chat/twitch_automod_settings.dart';
import '../../models/engagement/twitch_pinned_chat.dart';
import '../../models/emotes/twitch_cheermote_catalog.dart';

class TwitchModerationApiService {
  final TwitchApiClient client;
  final List<Future<String?> Function()> tokenProviders;
  final String broadcasterId;
  final String moderatorId;
  final bool Function()? canModerate;
  final void Function(List<TwitchPinnedChatMessage>)? onPinsLoaded;

  const TwitchModerationApiService({
    required this.client,
    required this.tokenProviders,
    required this.broadcasterId,
    required this.moderatorId,
    this.canModerate,
    this.onPinsLoaded,
  });

  Future<Map<String, dynamic>> settings({Map<String, dynamic>? changes}) async {
    if (changes != null) _validateSettings(changes);
    final response = await _request(
      changes == null ? 'GET' : 'PATCH',
      '/chat/settings',
      scope: changes == null ? null : 'moderator:manage:chat_settings',
      data: changes,
    );
    final rows = response.data is Map ? response.data['data'] : null;
    if (rows is! List || rows.isEmpty || rows.first is! Map) {
      throw const TwitchModerationException('聊天室設定回應不完整，請重新整理。');
    }
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<void> deleteMessages({String? messageId}) async {
    if (messageId != null && messageId.trim().isEmpty) {
      throw const TwitchModerationException('這則訊息沒有官方 ID，無法刪除。');
    }
    await _request(
      'DELETE',
      '/moderation/chat',
      scope: 'moderator:manage:chat_messages',
      query: {'message_id': ?messageId},
    );
  }

  Future<TwitchAutomodSettings> automodSettings({
    Map<String, int>? changes,
  }) async {
    if (changes != null && !TwitchAutomodSettings.validChanges(changes)) {
      throw const TwitchModerationException(
        'AutoMod 等級需為 0–4；自訂時必須包含全部分類，不能同時設定整體等級。',
      );
    }
    final response = await _request(
      changes == null ? 'GET' : 'PUT',
      '/moderation/automod/settings',
      scope: changes == null
          ? 'moderator:read:automod_settings'
          : 'moderator:manage:automod_settings',
      alternateScope: changes == null
          ? 'moderator:manage:automod_settings'
          : null,
      data: changes,
    );
    if (changes != null && canModerate?.call() == false) {
      throw const TwitchModerationException(
        'AutoMod 設定已送出，但管理身分或頻道已變更；請回到原頻道重新確認結果。',
      );
    }
    _checkCurrentPermission();
    final rows = response.data is Map ? response.data['data'] : null;
    if (rows is List && rows.length == 1 && rows.single is Map) {
      final row = rows.single as Map;
      if (row['broadcaster_id'] == broadcasterId &&
          row['moderator_id'] == moderatorId) {
        final settings = TwitchAutomodSettings.parse(row);
        if (settings != null) return settings;
      }
    }
    throw TwitchModerationException(
      changes == null
          ? 'AutoMod 設定回應不完整，請重新整理。'
          : 'AutoMod 寫入結果未確認，請重新整理；不要直接重送。',
    );
  }

  Future<void> ban(String userId, {int? seconds, String reason = ''}) async {
    if (!_validTarget(userId) ||
        reason.trim().length > 500 ||
        (seconds != null && (seconds < 1 || seconds > 1209600))) {
      throw const TwitchModerationException('管理操作的使用者或時間無效。');
    }
    await _request(
      'POST',
      '/moderation/bans',
      scope: 'moderator:manage:banned_users',
      data: {
        'data': {
          'user_id': userId,
          'duration': ?seconds,
          if (reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      },
    );
  }

  bool _validTarget(String userId) =>
      RegExp(r'^\d+$').hasMatch(userId) &&
      userId != broadcasterId &&
      userId != moderatorId;

  Future<void> warn(String userId, {required String reason}) async {
    if (!_validTarget(userId) ||
        reason.trim().isEmpty ||
        reason.trim().length > 500) {
      throw const TwitchModerationException('警告需要有效對象與 1–500 字的原因。');
    }
    await _request(
      'POST',
      '/moderation/warnings',
      scope: 'moderator:manage:warnings',
      data: {
        'data': {'user_id': userId, 'reason': reason.trim()},
      },
    );
  }

  void _validateSettings(Map<String, dynamic> changes) {
    const modes = {
      'emote_mode',
      'subscriber_mode',
      'follower_mode',
      'slow_mode',
      'unique_chat_mode',
      'non_moderator_chat_delay',
    };
    const durations = {
      'slow_mode_wait_time': ('slow_mode', 3, 120),
      'follower_mode_duration': ('follower_mode', 0, 129600),
      'non_moderator_chat_delay_duration': ('non_moderator_chat_delay', 2, 6),
    };
    if (changes.isEmpty) throw const TwitchModerationException('聊天室設定值無效。');
    for (final entry in changes.entries) {
      if (modes.contains(entry.key)) {
        if (entry.value is bool) continue;
      } else {
        final spec = durations[entry.key];
        if (spec != null &&
            entry.value is int &&
            changes[spec.$1] == true &&
            entry.value >= spec.$2 &&
            entry.value <= spec.$3 &&
            (entry.key != 'non_moderator_chat_delay_duration' ||
                const {2, 4, 6}.contains(entry.value))) {
          continue;
        }
      }
      throw const TwitchModerationException('聊天室設定值無效。');
    }
  }

  Future<void> unban(String userId) async {
    if (!_validTarget(userId)) {
      throw const TwitchModerationException('管理操作的使用者或時間無效。');
    }
    await _request(
      'DELETE',
      '/moderation/bans',
      scope: 'moderator:manage:banned_users',
      query: {'user_id': userId},
    );
  }

  Future<TwitchBlockedTermsPage> blockedTerms({String? after}) async {
    final response = await _request(
      'GET',
      '/moderation/blocked_terms',
      scope: 'moderator:read:blocked_terms',
      alternateScope: 'moderator:manage:blocked_terms',
      query: {'first': 100, 'after': ?after},
    );
    final terms = _blockedRows(response);
    final pagination = response.data['pagination'];
    final cursor = pagination is Map ? pagination['cursor']?.toString() : null;
    return TwitchBlockedTermsPage(
      terms,
      cursor == null || cursor.isEmpty ? null : cursor,
    );
  }

  Future<TwitchBlockedTerm> addBlockedTerm(String text) async {
    final clean = text.trim();
    if (clean.runes.length < 2 || clean.runes.length > 500) {
      throw const TwitchModerationException('封鎖詞需為 2–500 字。');
    }
    final response = await _request(
      'POST',
      '/moderation/blocked_terms',
      scope: 'moderator:manage:blocked_terms',
      data: {'text': clean},
    );
    final rows = _blockedRows(response);
    if (rows.length != 1) {
      throw const TwitchModerationException('封鎖詞回應不完整，請重新整理後確認；不要直接重送。');
    }
    return rows.single;
  }

  Future<void> removeBlockedTerm(String id) async {
    if (id.trim().isEmpty) throw const TwitchModerationException('封鎖詞 ID 無效。');
    await _request(
      'DELETE',
      '/moderation/blocked_terms',
      scope: 'moderator:manage:blocked_terms',
      query: {'id': id},
    );
  }

  Future<List<TwitchPinnedChatMessage>> pinnedMessages() async {
    final response = await _request(
      'GET',
      '/chat/pins',
      scope: 'moderator:read:chat_messages',
      alternateScope: 'moderator:manage:chat_messages',
    );
    final rows = response.data is Map ? response.data['data'] : null;
    if (rows is! List ||
        rows.any(
          (row) =>
              row is! Map ||
              row['broadcaster_id']?.toString() != broadcasterId ||
              (row['message_id']?.toString().trim().isEmpty ?? true) ||
              row['message'] is! Map ||
              row['message']['text'] is! String,
        )) {
      throw const TwitchModerationException('釘選回應不完整，請重新整理確認。');
    }
    _checkCurrentPermission();
    final pins = rows
        .map(
          (row) => TwitchPinnedChatMessage.fromHelixJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
    onPinsLoaded?.call(pins);
    return pins;
  }

  Future<void> pinMessage(
    String messageId, {
    int? seconds,
    bool update = false,
  }) async {
    if (messageId.trim().isEmpty ||
        (seconds != null && (seconds < 30 || seconds > 1800))) {
      throw const TwitchModerationException('釘選需要官方訊息 ID 與 30–1800 秒，或直到直播結束。');
    }
    await _request(
      update ? 'PATCH' : 'PUT',
      '/chat/pins',
      scope: 'moderator:manage:chat_messages',
      query: {'message_id': messageId, 'duration_seconds': ?seconds},
    );
  }

  Future<void> unpinMessage(String messageId) async {
    if (messageId.trim().isEmpty) {
      throw const TwitchModerationException('釘選訊息 ID 無效。');
    }
    await _request(
      'DELETE',
      '/chat/pins',
      scope: 'moderator:manage:chat_messages',
      query: {'message_id': messageId},
    );
  }

  Future<TwitchModerationSession> automodSession() async {
    _checkCurrentPermission();
    if (broadcasterId.isEmpty || moderatorId.isEmpty) {
      throw const TwitchModerationException('請先登入並等待聊天室連線。');
    }
    for (final provider in tokenProviders) {
      String? token;
      TwitchTokenValidation validation;
      try {
        token = await provider();
        if (token == null || token.trim().isEmpty) continue;
        validation = await TwitchAuthApiService(
          client: client,
        ).validateToken(token);
      } catch (_) {
        continue;
      }
      _checkCurrentPermission();
      if (validation.userId == moderatorId &&
          validation.scopes.contains('moderator:manage:automod')) {
        return TwitchModerationSession(token.trim(), validation);
      }
    }
    throw const TwitchModerationException(
      '目前登入缺少管理授權：moderator:manage:automod',
    );
  }

  Future<TwitchCheermoteCatalog> automodCheermotes() async {
    final response = await _request('GET', '/bits/cheermotes');
    _checkCurrentPermission();
    final data = response.data is Map ? response.data['data'] : null;
    if (response.statusCode != 200 || data is! List) {
      throw const TwitchModerationException('Bits 圖片資料不完整，原文字仍保留。');
    }
    return TwitchCheermoteCatalog.parse(data);
  }

  // channel.moderate v2 requires every group; alternatives apply within a group.
  static const _moderationLogScopes = [
    ['moderator:read:blocked_terms', 'moderator:manage:blocked_terms'],
    ['moderator:read:chat_settings', 'moderator:manage:chat_settings'],
    ['moderator:read:unban_requests', 'moderator:manage:unban_requests'],
    ['moderator:read:banned_users', 'moderator:manage:banned_users'],
    ['moderator:read:chat_messages', 'moderator:manage:chat_messages'],
    ['moderator:read:warnings', 'moderator:manage:warnings'],
    ['moderator:read:moderators'],
    ['moderator:read:vips'],
  ];

  bool _hasModerationLogScopes(TwitchTokenValidation validation) =>
      _moderationLogScopes.every(
        (group) => group.any(validation.scopes.contains),
      );

  Future<TwitchModerationSession> moderationLogSession() async {
    _checkCurrentPermission();
    if (broadcasterId.isEmpty || moderatorId.isEmpty) {
      throw const TwitchModerationException('請先登入並等待聊天室連線。');
    }
    for (final provider in tokenProviders) {
      String? token;
      TwitchTokenValidation validation;
      try {
        token = await provider();
        if (token == null || token.trim().isEmpty) continue;
        validation = await TwitchAuthApiService(
          client: client,
        ).validateToken(token);
      } catch (_) {
        continue;
      }
      _checkCurrentPermission();
      if (validation.userId == moderatorId &&
          validation.clientId.isNotEmpty &&
          _hasModerationLogScopes(validation)) {
        return TwitchModerationSession(token.trim(), validation);
      }
    }
    throw const TwitchModerationException(
      '目前登入缺少即時管理紀錄所需授權；未連線，不代表沒有管理事件。',
      terminal: true,
    );
  }

  Future<void> subscribeModerationLog(
    TwitchModerationSession auth,
    String sessionId,
  ) async {
    _checkCurrentPermission();
    if (sessionId.trim().isEmpty ||
        broadcasterId.isEmpty ||
        moderatorId.isEmpty ||
        auth.token.trim().isEmpty ||
        auth.validation.clientId.isEmpty ||
        auth.validation.userId != moderatorId ||
        !_hasModerationLogScopes(auth.validation)) {
      throw const TwitchModerationException('管理紀錄收件授權無效。', terminal: true);
    }
    final response = await client.dio.post<dynamic>(
      '${TwitchApiConstants.helixBaseUrl}/eventsub/subscriptions',
      data: {
        'type': 'channel.moderate',
        'version': '2',
        'condition': {
          'broadcaster_user_id': broadcasterId,
          'moderator_user_id': moderatorId,
        },
        'transport': {'method': 'websocket', 'session_id': sessionId},
      },
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'Client-ID': auth.validation.clientId,
          'Authorization': 'Bearer ${auth.token}',
        },
      ),
    );
    _checkCurrentPermission();
    if (response.statusCode != 202) {
      throw TwitchModerationException(
        '管理紀錄收件訂閱失敗，請確認授權後重新連線。',
        terminal: response.statusCode == 401 || response.statusCode == 403,
      );
    }
  }

  /// Authenticate before opening the socket; welcome has a short subscribe deadline.
  Future<void> subscribeAutomod(
    TwitchModerationSession auth,
    String sessionId,
  ) async {
    _checkCurrentPermission();
    if (sessionId.isEmpty ||
        auth.validation.userId != moderatorId ||
        !auth.validation.scopes.contains('moderator:manage:automod')) {
      throw const TwitchModerationException('AutoMod 收件授權無效。');
    }
    for (final type in const [
      'automod.message.hold',
      'automod.message.update',
    ]) {
      _checkCurrentPermission();
      final response = await client.dio.post<dynamic>(
        '${TwitchApiConstants.helixBaseUrl}/eventsub/subscriptions',
        data: {
          'type': type,
          'version': '2',
          'condition': {
            'broadcaster_user_id': broadcasterId,
            'moderator_user_id': moderatorId,
          },
          'transport': {'method': 'websocket', 'session_id': sessionId},
        },
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Client-ID': auth.validation.clientId,
            'Authorization': 'Bearer ${auth.token}',
          },
        ),
      );
      if (response.statusCode != 202) {
        throw TwitchModerationException(
          'AutoMod 收件訂閱失敗，請確認授權後重新連線。',
          terminal: response.statusCode == 401 || response.statusCode == 403,
        );
      }
    }
    _checkCurrentPermission();
  }

  Future<void> resolveAutomod(String messageId, {required bool allow}) async {
    if (messageId.trim().isEmpty) {
      throw const TwitchModerationException('待審訊息 ID 無效。');
    }
    await _request(
      'POST',
      '/moderation/automod/message',
      scope: 'moderator:manage:automod',
      includeChannelQuery: false,
      data: {
        'user_id': moderatorId,
        'msg_id': messageId,
        'action': allow ? 'ALLOW' : 'DENY',
      },
    );
  }

  List<TwitchBlockedTerm> _blockedRows(Response<dynamic> response) {
    final rows = response.data is Map ? response.data['data'] : null;
    if (rows is! List ||
        rows.any(
          (row) =>
              row is! Map ||
              row['broadcaster_id']?.toString() != broadcasterId ||
              (row['id']?.toString().isEmpty ?? true) ||
              row['text'] is! String,
        )) {
      throw const TwitchModerationException('封鎖詞回應不完整，請重新整理後確認；不要直接重送。');
    }
    return rows
        .map(
          (row) =>
              TwitchBlockedTerm.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  /// These official reads require the broadcaster's own token, not a MOD's.
  Future<bool> userHasRole(String userId, {required bool vip}) async {
    _checkRoleTarget(userId);
    final response = await _request(
      'GET',
      vip ? '/channels/vips' : '/moderation/moderators',
      scope: vip ? 'channel:read:vips' : 'moderation:read',
      alternateScope: vip ? 'channel:manage:vips' : 'channel:manage:moderators',
      broadcasterOnly: true,
      query: {'user_id': userId},
    );
    return _targetRows(response, userId).isNotEmpty;
  }

  /// null means Twitch reports no active ban/timeout, not a failed read.
  Future<Map<String, dynamic>?> userBanStatus(String userId) async {
    _checkRoleTarget(userId);
    final response = await _request(
      'GET',
      '/moderation/banned',
      scope: 'moderation:read',
      alternateScope: 'moderator:manage:banned_users',
      broadcasterOnly: true,
      query: {'user_id': userId},
    );
    final rows = _targetRows(response, userId);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> setUserRole(
    String userId, {
    required bool vip,
    required bool enabled,
  }) async {
    _checkRoleTarget(userId);
    // Twitch validates conflicting roles/bans. Do not require extra read
    // scopes, silently demote/unban, or replay a rejected write.
    await _request(
      enabled ? 'POST' : 'DELETE',
      vip ? '/channels/vips' : '/moderation/moderators',
      scope: vip ? 'channel:manage:vips' : 'channel:manage:moderators',
      broadcasterOnly: true,
      query: {'user_id': userId},
    );
  }

  void _checkRoleTarget(String userId) {
    if (moderatorId != broadcasterId) {
      throw const TwitchModerationException('此功能需要台主本人登入。');
    }
    if (!_validTarget(userId)) {
      throw const TwitchModerationException('管理操作的使用者或時間無效。');
    }
    _checkCurrentPermission();
  }

  List<Map<String, dynamic>> _targetRows(
    Response<dynamic> response,
    String userId,
  ) {
    final rows = response.data is Map ? response.data['data'] : null;
    if (rows is! List ||
        rows.any(
          (row) => row is! Map || row['user_id']?.toString() != userId,
        )) {
      throw const TwitchModerationException('使用者管理狀態回應不完整，請重新整理。');
    }
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<Response<dynamic>> _request(
    String method,
    String path, {
    String? scope,
    Object? data,
    Map<String, dynamic>? query,
    String? alternateScope,
    bool broadcasterOnly = false,
    bool includeChannelQuery = true,
  }) async {
    if (broadcasterId.isEmpty || moderatorId.isEmpty) {
      throw const TwitchModerationException('請先登入並等待聊天室連線。');
    }
    _checkCurrentPermission();
    for (final provider in tokenProviders) {
      String? token;
      TwitchTokenValidation validation;
      try {
        token = await provider();
        if (token == null || token.trim().isEmpty) continue;
        validation = await TwitchAuthApiService(
          client: client,
        ).validateToken(token);
      } catch (_) {
        continue;
      }
      _checkCurrentPermission();
      if (validation.userId != moderatorId ||
          (broadcasterOnly && validation.userId != broadcasterId) ||
          (scope != null &&
              !validation.scopes.contains(scope) &&
              (alternateScope == null ||
                  !validation.scopes.contains(alternateScope)))) {
        continue;
      }
      final response = await client.dio.request<dynamic>(
        '${TwitchApiConstants.helixBaseUrl}$path',
        queryParameters: {
          if (includeChannelQuery) 'broadcaster_id': broadcasterId,
          if (includeChannelQuery && scope != null && !broadcasterOnly)
            'moderator_id': moderatorId,
          ...?query,
        },
        data: data,
        options: Options(
          method: method,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Client-ID': validation.clientId,
            'Authorization': 'Bearer ${token.trim()}',
          },
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return response;
      if (status == 401) continue;
      if (status == 403) {
        throw const TwitchModerationException('你沒有這個頻道的管理權限。');
      }
      if (status == 429) {
        throw const TwitchModerationException('管理操作太頻繁，請稍候再試。');
      }
      if (path == '/moderation/automod/message' && status == 404) {
        throw const TwitchModerationException('待審訊息已失效或已被處理，請等候官方更新；不會自動重送。');
      }
      if (status == 409) {
        if (path == '/chat/pins') {
          throw const TwitchModerationException('此訊息已被釘選，請重新整理後確認。');
        }
        if (path == '/channels/vips') {
          throw const TwitchModerationException('頻道沒有可用的 VIP 名額，請重新確認。');
        }
        throw const TwitchModerationException('其他管理員正在操作此對象，請稍後重新確認。');
      }
      if (broadcasterOnly && status == 422) {
        throw const TwitchModerationException('角色衝突或已擁有此角色，請重新整理；不會自動撤銷其他角色。');
      }
      if (path == '/channels/vips' && status == 425) {
        throw const TwitchModerationException('頻道尚未符合 Twitch 的 VIP 開放條件。');
      }
      throw const TwitchModerationException('Twitch 未接受管理操作，請確認目標、權限或稍後重試。');
    }
    throw TwitchModerationException(
      '目前登入缺少管理授權${scope == null ? '' : '：$scope'}',
    );
  }

  void _checkCurrentPermission() {
    if (canModerate != null && !canModerate!()) {
      throw const TwitchModerationException('管理身分或頻道已變更，未送出操作。');
    }
  }
}

class TwitchModerationException implements Exception {
  final String message;
  final bool terminal;
  const TwitchModerationException(this.message, {this.terminal = true});
}

class TwitchModerationSession {
  final String token;
  final TwitchTokenValidation validation;
  const TwitchModerationSession(this.token, this.validation);
}
