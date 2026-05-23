import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../api/drops/twitch_drops_probe_api_service_stage249.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/auth/twitch_web_gql_auth_service.dart';
import '../../services/notifications/twitch_app_notification_service_stage249.dart';

const Color _kStage249Purple = Color(0xFF9146FF);
const Color _kStage249PurpleLight = Color(0xFFBF94FF);
const Color _kStage249Background = Color(0xFF0E0E10);
const Color _kStage249Panel = Color(0xFF18181B);

class TwitchDropsProbePageStage249 extends StatefulWidget {
  final TwitchApiClient apiClient;
  final TwitchDropsAuthService dropsAuthService;
  final TwitchWebGqlAuthService webGqlAuthService;

  const TwitchDropsProbePageStage249({
    super.key,
    required this.apiClient,
    required this.dropsAuthService,
    required this.webGqlAuthService,
  });

  @override
  State<TwitchDropsProbePageStage249> createState() =>
      _TwitchDropsProbePageStage249State();
}

class _TwitchDropsProbePageStage249State
    extends State<TwitchDropsProbePageStage249> {
  late final TwitchDropsProbeApiServiceStage249 probeApi;

  bool loadingState = true;
  bool probingWebGql = false;
  bool probingDrops = false;

  String statusText = '正在讀取 Stage 249 Drops probe 狀態...';
  String? errorText;
  TwitchDropsProbeResultStage249? lastResult;

  String? webToken;
  String? dropsToken;

  @override
  void initState() {
    super.initState();
    probeApi = TwitchDropsProbeApiServiceStage249(client: widget.apiClient);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(loadTokenState());
    });
  }

  Future<void> loadTokenState() async {
    if (!mounted) return;

    setState(() {
      loadingState = true;
      errorText = null;
      statusText = '正在讀取 Web/GQL 與 Drops/Android token...';
    });

    try {
      await Future.wait<void>(<Future<void>>[
        widget.webGqlAuthService.loadStoredSession(),
        widget.dropsAuthService.loadStoredSession(),
      ]);

      final nextWebToken = await widget.webGqlAuthService.getToken();
      final nextDropsToken = await widget.dropsAuthService.getToken();

      if (!mounted) return;
      setState(() {
        webToken = nextWebToken;
        dropsToken = nextDropsToken;
        loadingState = false;
        statusText = 'Token 狀態已讀取。先用 currentUser GQL 驗證哪個 token 可用。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingState = false;
        errorText = '讀取 token 狀態失敗：$error';
        statusText = 'Stage 249 Drops probe 無法讀取 token。';
      });
    }
  }

  Future<void> runProbe(TwitchDropsProbeTokenSlotStage249 tokenSlot) async {
    final isWeb = tokenSlot == TwitchDropsProbeTokenSlotStage249.webGql;
    final token = isWeb ? webToken : dropsToken;
    final clientId = isWeb
        ? TwitchApiConstants.twitchWebClientId
        : widget.dropsAuthService.dropsClientId;

    if (token == null || token.trim().isEmpty) {
      twitchAppNotificationCenter.showWarning(
        title: isWeb ? '缺少 Web/GQL token' : '缺少 Drops/Android token',
        message: isWeb
            ? '請先完成完整登入，或重新取得官方 Web/GQL token。'
            : '請先完成 Drops / Android device flow 登入。',
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      if (isWeb) {
        probingWebGql = true;
      } else {
        probingDrops = true;
      }
      errorText = null;
      statusText = isWeb
          ? '正在用 Web/GQL token 測試 Twitch GQL currentUser...'
          : '正在用 Drops/Android token 測試 Twitch GQL currentUser...';
    });

    try {
      final result = await probeApi.probeCurrentUser(
        tokenSlot: tokenSlot,
        accessToken: token,
        clientId: clientId,
      );

      if (!mounted) return;
      setState(() {
        lastResult = result;
        statusText = result.hasGraphQLErrors
            ? 'GQL 有回應，但包含 errors。請看 raw response。'
            : 'GQL currentUser 測試成功。下一步才適合找 Drops inventory operation。';
      });

      if (result.hasGraphQLErrors) {
        twitchAppNotificationCenter.showWarning(
          title: 'Stage 249 GQL probe 有 errors',
          message: isWeb
              ? 'Web/GQL token 有回應但不是乾淨成功，請看 raw response。'
              : 'Drops/Android token 有回應但不是乾淨成功，請看 raw response。',
        );
      } else {
        twitchAppNotificationCenter.showSuccess(
          title: 'Stage 249 GQL probe 成功',
          message: isWeb
              ? 'Web/GQL token 可打 Twitch GQL currentUser。'
              : 'Drops/Android token 可打 Twitch GQL currentUser。',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = 'GQL probe 失敗：$error';
        statusText = 'GQL probe 失敗。';
      });
      twitchAppNotificationCenter.showError(
        title: 'Stage 249 GQL probe 失敗',
        message: '$error',
      );
    } finally {
      if (!mounted) return;
      setState(() {
        if (isWeb) {
          probingWebGql = false;
        } else {
          probingDrops = false;
        }
      });
    }
  }

  void sendClaimableMockNotification() {
    twitchAppNotificationCenter.showSuccess(
      title: 'Drops 可以領取（模擬）',
      message: '這是 Stage 249 內部通知模擬。真正 Drops inventory 接上後會用同一個通知中心。',
      duration: const Duration(seconds: 7),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kStage249Background,
      appBar: AppBar(
        backgroundColor: _kStage249Panel,
        foregroundColor: Colors.white,
        title: const Text('Stage 249 Drops Probe'),
        actions: <Widget>[
          IconButton(
            tooltip: '重新讀取 token 狀態',
            onPressed: loadingState ? null : () => unawaited(loadTokenState()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildHeader(),
          if (errorText != null) _buildErrorBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _buildTokenCard(),
                const SizedBox(height: 14),
                _buildProbeActions(),
                const SizedBox(height: 14),
                _buildRawResultCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        color: _kStage249Panel,
        border: Border(
          bottom: BorderSide(color: _kStage249Purple.withOpacity(0.26)),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.science_rounded, color: _kStage249PurpleLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              statusText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (loadingState || probingWebGql || probingDrops)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: _kStage249PurpleLight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      color: Colors.redAccent.withOpacity(0.16),
      child: SelectableText(
        errorText!,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 12.5,
          height: 1.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildTokenCard() {
    return _Stage249Card(
      title: 'Token 狀態',
      icon: Icons.key_rounded,
      child: Column(
        children: <Widget>[
          _TokenRow(
            label: 'Web/GQL token',
            hasToken: webToken != null && webToken!.trim().isNotEmpty,
            clientId: TwitchApiConstants.twitchWebClientId,
          ),
          const Divider(color: Color(0xFF2D2D35)),
          _TokenRow(
            label: 'Drops/Android token',
            hasToken: dropsToken != null && dropsToken!.trim().isNotEmpty,
            clientId: widget.dropsAuthService.dropsClientId,
          ),
        ],
      ),
    );
  }

  Widget _buildProbeActions() {
    return _Stage249Card(
      title: 'Probe 動作',
      icon: Icons.bug_report_rounded,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          ElevatedButton.icon(
            onPressed: loadingState || probingWebGql
                ? null
                : () => unawaited(
                      runProbe(TwitchDropsProbeTokenSlotStage249.webGql),
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kStage249Purple,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.public_rounded),
            label: const Text('測 Web/GQL currentUser'),
          ),
          ElevatedButton.icon(
            onPressed: loadingState || probingDrops
                ? null
                : () => unawaited(
                      runProbe(TwitchDropsProbeTokenSlotStage249.dropsAndroid),
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D2D35),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.android_rounded),
            label: const Text('測 Drops/Android currentUser'),
          ),
          OutlinedButton.icon(
            onPressed: sendClaimableMockNotification,
            style: OutlinedButton.styleFrom(
              foregroundColor: _kStage249PurpleLight,
              side: const BorderSide(color: _kStage249Purple),
            ),
            icon: const Icon(Icons.notifications_active_rounded),
            label: const Text('模擬可領取通知'),
          ),
        ],
      ),
    );
  }

  Widget _buildRawResultCard() {
    final result = lastResult;
    final title = result == null
        ? 'Raw response'
        : 'Raw response｜${result.operationName}｜HTTP ${result.statusCode ?? '-'}';

    return _Stage249Card(
      title: title,
      icon: Icons.data_object_rounded,
      child: result == null
          ? const Text(
              '尚未執行 probe。先按上方 Web/GQL 或 Drops/Android 測試。',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            )
          : SelectableText(
              result.prettyJson,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.32,
                fontFamily: 'monospace',
              ),
            ),
    );
  }
}

class _Stage249Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Stage249Card({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kStage249Panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: _kStage249PurpleLight, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  final String label;
  final bool hasToken;
  final String clientId;

  const _TokenRow({
    required this.label,
    required this.hasToken,
    required this.clientId,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          hasToken ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: hasToken ? const Color(0xFF5CFFB1) : Colors.orangeAccent,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Client-ID: $clientId',
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
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: hasToken
                ? const Color(0xFF5CFFB1).withOpacity(0.12)
                : Colors.orangeAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: hasToken
                  ? const Color(0xFF5CFFB1).withOpacity(0.32)
                  : Colors.orangeAccent.withOpacity(0.32),
            ),
          ),
          child: Text(
            hasToken ? '有 token' : '缺 token',
            style: TextStyle(
              color: hasToken ? const Color(0xFF5CFFB1) : Colors.orangeAccent,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
