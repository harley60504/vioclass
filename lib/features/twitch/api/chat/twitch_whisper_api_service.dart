import 'package:dio/dio.dart';
import '../auth/twitch_auth_api_service.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../../models/chat/twitch_whisper_conversation.dart';
import '../../models/chat/twitch_whisper_emote_catalog.dart';
import '../../models/emotes/twitch_official_emote.dart';

class TwitchWhisperSession {
  final String token;
  final TwitchTokenValidation validation;
  const TwitchWhisperSession(this.token, this.validation);
  Map<String, String> get headers => {
    'Client-ID': validation.clientId,
    'Authorization': 'Bearer $token',
  };
}

class TwitchWhisperApiService {
  final TwitchApiClient client;
  final List<Future<String?> Function()> tokenProviders;
  const TwitchWhisperApiService({
    required this.client,
    required this.tokenProviders,
  });

  /// The first provider establishes identity. Secondary providers may supply
  /// scopes for that identity, but may not silently establish a new account.
  Future<TwitchWhisperSession> session({String? ownerId, String? scope}) async {
    String? primaryId = ownerId;
    var primaryChanged = false;
    for (var index = 0; index < tokenProviders.length; index++) {
      final provider = tokenProviders[index];
      try {
        final token = (await provider())?.trim();
        if (token == null || token.isEmpty) {
          if (primaryId == null) break;
          continue;
        }
        final validation = await TwitchAuthApiService(
          client: client,
        ).validateToken(token);
        if (!RegExp(r'^\d+$').hasMatch(validation.userId) ||
            validation.clientId.isEmpty) {
          if (primaryId == null) break;
          continue;
        }
        if (index == 0 && primaryId != null && validation.userId != primaryId) {
          primaryChanged = true;
          break;
        }
        primaryId ??= validation.userId;
        if (validation.userId != primaryId ||
            (scope != null && !validation.scopes.contains(scope))) {
          continue;
        }
        return TwitchWhisperSession(token, validation);
      } catch (_) {
        if (primaryId == null) break;
        // A caller-bound owner may use another verified token for that owner.
        // No tokens are stored, refreshed or changed by this selection logic.
      }
    }
    throw TwitchWhisperException(
      primaryChanged
          ? '主登入帳號已變更，未使用其他連結帳號執行私訊。'
          : primaryId == null
          ? '無法確認主登入帳號，請重新登入 Twitch 再使用私訊。'
          : scope == null
          ? '請先登入 Twitch 再使用私訊。'
          : '目前登入缺少私訊所需授權：$scope',
    );
  }

  Future<TwitchWhisperSession> receiveSession(String ownerId) async {
    try {
      return await session(ownerId: ownerId, scope: 'user:read:whispers');
    } on TwitchWhisperException {
      return session(ownerId: ownerId, scope: 'user:manage:whispers');
    }
  }

  Future<void> subscribe(TwitchWhisperSession auth, String sessionId) async {
    if (sessionId.trim().isEmpty ||
        auth.validation.userId.isEmpty ||
        !auth.validation.scopes.any(
          const {'user:read:whispers', 'user:manage:whispers'}.contains,
        )) {
      throw const TwitchWhisperException('私訊收件授權無效。');
    }
    await client.postJson<dynamic>(
      '${TwitchApiConstants.helixBaseUrl}/eventsub/subscriptions',
      headers: auth.headers,
      data: {
        'type': 'user.whisper.message',
        'version': '1',
        'condition': {'user_id': auth.validation.userId},
        'transport': {'method': 'websocket', 'session_id': sessionId},
      },
    );
  }

  Future<TwitchWhisperConversation> findUser(
    String login,
    String ownerId,
  ) async {
    final clean = login.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{1,25}$').hasMatch(clean)) {
      throw const TwitchWhisperException('請輸入有效的 Twitch 帳號與訊息。');
    }
    final auth = await session(ownerId: ownerId);
    final result = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/users',
      queryParameters: {'login': clean},
      headers: auth.headers,
    );
    final users = result['data'];
    if (users is! List || users.length != 1 || users.first is! Map) {
      throw const TwitchWhisperException('找不到這個 Twitch 帳號。');
    }
    final user = users.first as Map;
    final id = user['id']?.toString() ?? '';
    if (!RegExp(r'^\d+$').hasMatch(id) ||
        user['login']?.toString().toLowerCase() != clean) {
      throw const TwitchWhisperException('私訊收件者資料不符，未開啟對話。');
    }
    if (id == ownerId) {
      throw const TwitchWhisperException('不能傳送私訊給自己。');
    }
    return TwitchWhisperConversation(
      userId: id,
      login: user['login']?.toString() ?? clean,
      displayName: user['display_name']?.toString() ?? clean,
      avatarUrl: user['profile_image_url']?.toString(),
    );
  }

  Future<TwitchWhisperConversation> getUserById({
    required String ownerId,
    required String peerId,
    bool Function()? canRead,
  }) async {
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(ownerId) ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(peerId) ||
        ownerId == peerId) {
      throw const TwitchWhisperException('私訊對象 ID 無效。');
    }
    final auth = await session(ownerId: ownerId);
    if (canRead != null && !canRead()) {
      throw const TwitchWhisperException('私訊帳號或對話已變更，未讀取資料。');
    }
    final result = await client.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/users',
      queryParameters: {'id': peerId},
      headers: auth.headers,
    );
    final users = result['data'];
    if (users is! List || users.length != 1 || users.first is! Map) {
      throw const TwitchWhisperException('找不到這個 Twitch 使用者；原本對話仍保留。');
    }
    final user = users.first as Map;
    final login = user['login'];
    final name = user['display_name'];
    final image = user['profile_image_url'];
    if (user['id'] != peerId ||
        login is! String ||
        !RegExp(r'^[a-z0-9_]{1,25}$').hasMatch(login) ||
        name is! String ||
        name.trim().isEmpty ||
        image is! String) {
      throw const TwitchWhisperException('私訊對象資料不符；原本對話仍保留。');
    }
    final uri = image.isEmpty ? null : Uri.tryParse(image);
    if (image.isNotEmpty &&
        (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty)) {
      throw const TwitchWhisperException('私訊頭像網址無效；原本資料仍保留。');
    }
    return TwitchWhisperConversation(
      userId: peerId,
      login: login,
      displayName: name,
      avatarUrl: image.isEmpty ? null : image,
    );
  }

  Future<TwitchWhisperEmoteCatalog> fetchWhisperEmotes({
    required String ownerId,
    required bool Function() canRead,
  }) async {
    final auth = await session(ownerId: ownerId);
    void checkContext() {
      if (!canRead()) {
        throw const TwitchWhisperException('私訊帳號已變更，未載入貼圖。');
      }
    }

    List<TwitchOfficialEmote> parse(
      Map<String, dynamic> raw,
      TwitchOfficialEmoteSource source,
    ) {
      final data = raw['data'];
      if (data is! List) throw const TwitchWhisperException('官方貼圖回應格式無效。');
      return data
          .whereType<Map>()
          .map(
            (row) => TwitchOfficialEmote.fromHelixJson(
              Map<String, dynamic>.from(row),
              source: source,
              unlocked: true,
            ),
          )
          .where(
            (emote) =>
                RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(emote.id) &&
                emote.name.isNotEmpty &&
                !RegExp(r'\s').hasMatch(emote.name),
          )
          .map(
            (emote) => emote.copyWith(
              imageUrl:
                  'https://static-cdn.jtvnw.net/emoticons/v2/${emote.id}/default/dark/2.0',
            ),
          )
          .toList();
    }

    checkContext();
    final global = parse(
      await client.getJson<Map<String, dynamic>>(
        '${TwitchApiConstants.helixBaseUrl}/chat/emotes/global',
        headers: auth.headers,
      ),
      TwitchOfficialEmoteSource.global,
    );
    checkContext();
    final user = <TwitchOfficialEmote>[];
    String? userError;
    try {
      final userAuth = await session(
        ownerId: ownerId,
        scope: 'user:read:emotes',
      );
      final cursors = <String>{};
      String? cursor;
      do {
        checkContext();
        final raw = await client.getJson<Map<String, dynamic>>(
          '${TwitchApiConstants.helixBaseUrl}/chat/emotes/user',
          headers: userAuth.headers,
          queryParameters: {'user_id': ownerId, 'after': ?cursor},
        );
        user.addAll(parse(raw, TwitchOfficialEmoteSource.user));
        final pagination = raw['pagination'];
        cursor = pagination is Map ? pagination['cursor'] as String? : null;
        if (cursor != null && cursor.isNotEmpty && !cursors.add(cursor)) {
          throw const TwitchWhisperException('官方貼圖分頁重複，請重新載入。');
        }
        if (cursors.length > 100) {
          throw const TwitchWhisperException('官方貼圖分頁超過安全上限，請重新載入。');
        }
      } while (cursor != null && cursor.isNotEmpty);
    } on TwitchWhisperException catch (error) {
      user.clear();
      userError = error.message;
    } catch (_) {
      user.clear();
      userError = '個人官方貼圖暫時無法載入；仍可使用全域貼圖。';
    }
    checkContext();
    final byId = <String, TwitchOfficialEmote>{};
    for (final emote in [...global, ...user]) {
      byId[emote.id] = emote;
    }
    return TwitchWhisperEmoteCatalog(
      List.unmodifiable(byId.values),
      userError: userError,
    );
  }

  Future<void> send({
    required String ownerId,
    required String peerId,
    required String text,
    bool Function()? canSend,
    bool hasReceivedWhisper = false,
  }) async {
    if (text.trim().isEmpty ||
        text.length > TwitchWhisperConversation.sendLimit(hasReceivedWhisper) ||
        !RegExp(r'^\d+$').hasMatch(ownerId) ||
        !RegExp(r'^\d+$').hasMatch(peerId) ||
        peerId == ownerId) {
      throw const TwitchWhisperException('請輸入有效的 Twitch 帳號與訊息。');
    }
    final auth = await session(ownerId: ownerId, scope: 'user:manage:whispers');
    if (canSend != null && !canSend()) {
      throw const TwitchWhisperException('登入帳號已變更，未發送私訊。');
    }
    try {
      final response = await client.dio.post<dynamic>(
        '${TwitchApiConstants.helixBaseUrl}/whispers',
        options: Options(
          headers: auth.headers,
          validateStatus: (status) => status != null,
        ),
        queryParameters: {'from_user_id': ownerId, 'to_user_id': peerId},
        data: {'message': text},
      );
      final status = response.statusCode;
      if (status == 204) return;
      final message = switch (status) {
        400 => 'Twitch 未接受私訊；對方可能不允許陌生人私訊、帳號停權或收件者無效。',
        401 => '私訊授權失效或缺少電話驗證，請檢查目前 Twitch 帳號。',
        403 => '目前 Twitch 帳號不允許傳送私訊，請檢查帳號限制。',
        404 => '找不到私訊收件者，請重新確認帳號。',
        429 => '私訊傳送過於頻繁或已達 Twitch 上限，請稍候再試；不會自動重送。',
        _ => '私訊送出結果未確認，請先向對方確認；不要直接重送。',
      };
      throw TwitchWhisperException(
        message,
        outcomeUnknown: !const {400, 401, 403, 404, 429}.contains(status),
      );
    } on DioException {
      throw const TwitchWhisperException(
        '私訊送出結果未確認，請先向對方確認；不要直接重送。',
        outcomeUnknown: true,
      );
    }
  }
}

class TwitchWhisperException implements Exception {
  final String message;
  final bool outcomeUnknown;
  const TwitchWhisperException(this.message, {this.outcomeUnknown = false});
}
