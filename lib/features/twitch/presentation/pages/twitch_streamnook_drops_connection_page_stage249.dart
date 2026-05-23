import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/core/twitch_api_client.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/drops/twitch_streamnook_drops_connection_check_stage249.dart';
import '../../services/drops/twitch_streamnook_drops_connection_service_stage249.dart';
import '../../services/notifications/twitch_app_notification_service_stage249.dart';

const Color _kStage249Purple = Color(0xFF9146FF);
const Color _kStage249Panel = Color(0xFF18181B);
const Color _kStage249Background = Color(0xFF0E0E10);

class TwitchStreamNookDropsConnectionPageStage249 extends StatefulWidget {
  final TwitchApiClient apiClient;
  final TwitchDropsAuthService dropsAuthService;

  const TwitchStreamNookDropsConnectionPageStage249({
    super.key,
    required this.apiClient,
    required this.dropsAuthService,
  });

  @override
  State<TwitchStreamNookDropsConnectionPageStage249> createState() =>
      _TwitchStreamNookDropsConnectionPageStage249State();
}

class _TwitchStreamNookDropsConnectionPageStage249State
    extends State<TwitchStreamNookDropsConnectionPageStage249> {
  late final TwitchStreamNookDropsConnectionServiceStage249 service;

  TwitchStreamNookDropsConnectionCheckStage249? result;
  bool checking = false;
  String statusText = '尚未測試 StreamNook-style Drops 連線。';

  @override
  void initState() {
    super.initState();
    service = TwitchStreamNookDropsConnectionServiceStage249(
      apiClient: widget.apiClient,
      dropsAuthService: widget.dropsAuthService,
    );
  }

  Future<void> runCheck() async {
    if (checking) return;

    setState(() {
      checking = true;
      statusText = '正在測試 Drops token、Inventory、Campaigns...';
    });

    final next = await service.checkConnection();

    if (!mounted) return;

    setState(() {
      result = next;
      checking = false;
      statusText = next.title;
    });

    if (next.connected) {
      twitchAppNotificationCenter.showSuccess(
        title: 'StreamNook Drops 連線成功',
        message: 'Drops token、Inventory、Campaigns 都已連上。',
      );
    } else {
      twitchAppNotificationCenter.showWarning(
        title: next.title,
        message: next.summary,
        duration: const Duration(seconds: 8),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = result;
    final connected = current?.connected ?? false;

    return Scaffold(
      backgroundColor: _kStage249Background,
      appBar: AppBar(
        backgroundColor: _kStage249Panel,
        foregroundColor: Colors.white,
        title: const Text('StreamNook Drops Connector'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          _StatusCard(
            connected: connected,
            checking: checking,
            statusText: statusText,
            summary: current?.summary,
          ),
          const SizedBox(height: 14),
          _ActionCard(
            checking: checking,
            onRunCheck: runCheck,
          ),
          const SizedBox(height: 14),
          _ResultCard(current: current),
          if (current != null) ...<Widget>[
            const SizedBox(height: 14),
            _PreviewCard(
              title: 'Inventory response preview',
              subtitle: current.inventoryRootSummary,
              text: current.inventoryPreview,
            ),
            const SizedBox(height: 14),
            _PreviewCard(
              title: 'Campaigns response preview',
              subtitle: current.campaignsRootSummary,
              text: current.campaignsPreview,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool connected;
  final bool checking;
  final String statusText;
  final String? summary;

  const _StatusCard({
    required this.connected,
    required this.checking,
    required this.statusText,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kStage249Panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: connected
              ? const Color(0xFF5CFFB1).withOpacity(0.35)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            connected ? Icons.check_circle_rounded : Icons.cable_rounded,
            color: connected ? const Color(0xFF5CFFB1) : _kStage249Purple,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary ??
                      '這個頁面只做最小連線測試：validate token → inventory → campaigns。',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (checking)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.3,
                color: _kStage249Purple,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final bool checking;
  final Future<void> Function() onRunCheck;

  const _ActionCard({
    required this.checking,
    required this.onRunCheck,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kStage249Panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              '測試 StreamNook-style Drops 連線',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: checking ? null : () => unawaited(onRunCheck()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kStage249Purple,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.link_rounded),
            label: Text(checking ? '測試中' : '開始測試'),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final TwitchStreamNookDropsConnectionCheckStage249? current;

  const _ResultCard({
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kStage249Panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Result',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            current?.prettyJson ?? '尚無結果。',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String text;

  const _PreviewCard({
    required this.title,
    required this.subtitle,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kStage249Panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            text.isEmpty ? '沒有 response preview。' : text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.35,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
