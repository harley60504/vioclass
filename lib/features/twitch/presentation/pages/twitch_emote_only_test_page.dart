import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../api/emotes/twitch_official_emote_api_service.dart';
import '../../api/emotes/twitch_third_party_emote_api_service.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../widgets/watch/chat/twitch_watch_embedded_emote_panel.dart';

const String _defaultEmoteTestChannelLogin = String.fromEnvironment(
  'TWITCH_EMOTE_TEST_CHANNEL_LOGIN',
  defaultValue: '',
);

const String _defaultEmoteTestChannelId = String.fromEnvironment(
  'TWITCH_EMOTE_TEST_CHANNEL_ID',
  defaultValue: '',
);

class TwitchEmoteOnlyTestPage extends StatefulWidget {
  final String initialChannelLogin;
  final String initialChannelId;
  final String initialDisplayName;
  final bool autoLoad;

  const TwitchEmoteOnlyTestPage({
    super.key,
    this.initialChannelLogin = _defaultEmoteTestChannelLogin,
    this.initialChannelId = _defaultEmoteTestChannelId,
    this.initialDisplayName = '',
    this.autoLoad = true,
  });

  @override
  State<TwitchEmoteOnlyTestPage> createState() =>
      _TwitchEmoteOnlyTestPageState();
}

class _TwitchEmoteOnlyTestPageState extends State<TwitchEmoteOnlyTestPage> {
  late final TwitchApiClient apiClient;
  late final TwitchAuthService authService;
  late final TwitchAuthApiService authApi;
  late final TwitchThirdPartyEmoteCacheService thirdPartyCache;
  late final TwitchOfficialEmoteCacheService officialCache;

  late final TextEditingController channelLoginController;
  late final TextEditingController channelIdController;
  final TextEditingController messageController = TextEditingController();

  String status =
      '輸入 channel login / id 後按 Load。這頁不建立 watch page、player、chat list。';
  String viewerId = '';
  String activeChannelId = '';
  String activeChannelLogin = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    channelLoginController = TextEditingController(
      text: widget.initialChannelLogin.trim().isNotEmpty
          ? widget.initialChannelLogin.trim().toLowerCase()
          : _defaultEmoteTestChannelLogin,
    );
    channelIdController = TextEditingController(
      text: widget.initialChannelId.trim().isNotEmpty
          ? widget.initialChannelId.trim()
          : _defaultEmoteTestChannelId,
    );
    apiClient = TwitchApiClient();
    authService = TwitchAuthService(apiClient: apiClient);
    authApi = TwitchAuthApiService(client: apiClient);
    thirdPartyCache = TwitchThirdPartyEmoteCacheService(
      api: TwitchThirdPartyEmoteApiService(client: apiClient),
    );
    officialCache = TwitchOfficialEmoteCacheService(
      api: TwitchOfficialEmoteApiService(client: apiClient),
      accessTokenProvider: () => authService.getValidAccessToken(),
      clientIdProvider: () async {
        final stored = authService.clientId?.trim() ?? '';
        if (stored.isNotEmpty) return stored;
        return TwitchApiConstants.twitchWebClientId;
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    channelLoginController.dispose();
    channelIdController.dispose();
    messageController.dispose();
    thirdPartyCache.dispose();
    officialCache.dispose();
    authService.dispose();
    apiClient.close(force: true);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await authService.loadStoredSession();
    final token = await authService.getValidAccessToken();
    if (token != null && token.trim().isNotEmpty) {
      try {
        final validation = await authApi.validateToken(token);
        viewerId = validation.userId;
      } catch (_) {
        viewerId = '';
      }
    }

    if (!mounted) return;
    setState(() {
      status = viewerId.isEmpty
          ? '未取得登入 viewerId；第三方貼圖可測，官方 user emote 可能為空。'
          : '已載入登入狀態 viewerId=$viewerId。';
    });

    final hasInitialChannel =
        channelLoginController.text.trim().isNotEmpty ||
        channelIdController.text.trim().isNotEmpty;
    if (widget.autoLoad && hasInitialChannel) {
      await _loadEmotes();
    }
  }

  Future<void> _loadEmotes() async {
    if (loading) return;

    final inputLogin = channelLoginController.text.trim().toLowerCase();
    var inputId = channelIdController.text.trim();

    if (inputLogin.isEmpty && inputId.isEmpty) {
      setState(() => status = '請至少輸入 channel login 或 channel id。');
      return;
    }

    setState(() {
      loading = true;
      status = '載入 emotes 中...';
    });

    try {
      final token = await authService.getValidAccessToken();
      final clientId = authService.clientId?.trim().isNotEmpty == true
          ? authService.clientId!.trim()
          : TwitchApiConstants.twitchWebClientId;

      var resolvedLogin = inputLogin;
      if (inputId.isEmpty && resolvedLogin.isNotEmpty && token != null) {
        final resolved = await _resolveUserByLogin(
          login: resolvedLogin,
          accessToken: token,
          clientId: clientId,
        );
        inputId = resolved.id;
        resolvedLogin = resolved.login;
        channelIdController.text = inputId;
      }

      if (inputId.isEmpty) {
        throw StateError('缺少 channel id；如果只輸入 login，需要已登入 token 才能解析。');
      }

      activeChannelId = inputId;
      activeChannelLogin = resolvedLogin;

      await Future.wait<void>([
        thirdPartyCache.loadForChannel(
          channelId: activeChannelId,
          channelLogin: activeChannelLogin,
        ),
        officialCache.loadForChannel(
          channelId: activeChannelId,
          viewerId: viewerId,
          forceRefresh: true,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        final label = activeChannelLogin.isEmpty
            ? activeChannelId
            : activeChannelLogin;
        status =
            '載入完成：$label｜third-party=${thirdPartyCache.count}，official=${officialCache.visibleCount}。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        status = '載入失敗：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<_ResolvedTwitchUser> _resolveUserByLogin({
    required String login,
    required String accessToken,
    required String clientId,
  }) async {
    final raw = await apiClient.getJson<Map<String, dynamic>>(
      '${TwitchApiConstants.helixBaseUrl}/users',
      queryParameters: <String, dynamic>{'login': login},
      headers: <String, String>{
        'Client-ID': clientId,
        'Authorization': 'Bearer ${accessToken.trim()}',
      },
    );

    final data = raw['data'];
    if (data is! List || data.isEmpty || data.first is! Map) {
      throw StateError('找不到 channel login：$login');
    }

    final first = Map<String, dynamic>.from(data.first as Map);
    return _ResolvedTwitchUser(
      id: first['id']?.toString() ?? '',
      login: first['login']?.toString() ?? login,
      displayName: first['display_name']?.toString() ?? login,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([thirdPartyCache, officialCache]),
                builder: (context, _) {
                  return TwitchWatchEmbeddedEmotePanel(
                    thirdPartyCache: thirdPartyCache,
                    officialCache: officialCache,
                    loading:
                        loading ||
                        thirdPartyCache.loading ||
                        officialCache.loading,
                    messageController: messageController,
                    onRefresh: () => unawaited(_loadEmotes()),
                  );
                },
              ),
            ),
            _buildOutputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final displayName = widget.initialDisplayName.trim();
    final subtitle = displayName.isEmpty
        ? '不建立 watch page、player、chat list'
        : '$displayName｜不建立 watch page、player、chat list';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_emotions_rounded,
                color: Color(0xFFBF94FF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emote-only Test Page',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                loading ? 'Loading' : 'Isolated',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 190,
                child: TextField(
                  controller: channelLoginController,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'channel login',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: TextField(
                  controller: channelIdController,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'channel id',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: loading ? null : () => unawaited(_loadEmotes()),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Load'),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            status,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: TextField(
        controller: messageController,
        minLines: 1,
        maxLines: 2,
        decoration: const InputDecoration(
          isDense: true,
          labelText: '點貼圖後會插到這裡，用來確認插入邏輯',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _ResolvedTwitchUser {
  final String id;
  final String login;
  final String displayName;

  const _ResolvedTwitchUser({
    required this.id,
    required this.login,
    required this.displayName,
  });
}
