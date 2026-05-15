import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/chat/twitch_chat_runtime.dart';
import 'twitch_runtime_message_tile.dart';

class TwitchRuntimeChatPanel extends StatefulWidget {
  final TwitchChatRuntime runtime;
  final VoidCallback? onReconnect;

  const TwitchRuntimeChatPanel({
    super.key,
    required this.runtime,
    this.onReconnect,
  });

  @override
  State<TwitchRuntimeChatPanel> createState() => _TwitchRuntimeChatPanelState();
}

class _TwitchRuntimeChatPanelState extends State<TwitchRuntimeChatPanel> {
  final ScrollController _scrollController = ScrollController();

  int _lastMessageCount = 0;
  bool _nearBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant TwitchRuntimeChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.runtime != widget.runtime) {
      _lastMessageCount = 0;
      _nearBottom = true;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final distanceToBottom = position.maxScrollExtent - position.pixels;
    final nextNearBottom = distanceToBottom < 96;

    if (nextNearBottom != _nearBottom && mounted) {
      setState(() => _nearBottom = nextNearBottom);
    }
  }

  void _scheduleAutoScroll({
    required int messageCount,
  }) {
    if (messageCount == _lastMessageCount) return;

    final previousCount = _lastMessageCount;
    _lastMessageCount = messageCount;

    final shouldFollowBottom = _nearBottom || previousCount == 0;
    if (!shouldFollowBottom) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final target = _scrollController.position.maxScrollExtent;
      if (previousCount == 0) {
        _scrollController.jumpTo(target);
        return;
      }

      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;

    setState(() => _nearBottom = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.runtime,
      builder: (context, _) {
        final runtime = widget.runtime;
        final messages = runtime.messages;
        _scheduleAutoScroll(messageCount: messages.length);

        return Container(
          color: const Color(0xFF0E0E10),
          child: Column(
            children: [
              _RuntimeChatHeader(
                runtime: runtime,
                onReconnect: widget.onReconnect,
              ),
              if (runtime.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: Colors.redAccent.withOpacity(0.14),
                  child: Text(
                    runtime.error.toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    if (messages.isEmpty)
                      const Center(
                        child: Text(
                          '等待聊天室訊息...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: messages.length,
                        cacheExtent: 900,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        itemBuilder: (context, index) {
                          final message = messages[index];

                          return RepaintBoundary(
                            key: ValueKey<String>(
                              message.id.isEmpty
                                  ? '${message.receivedAt.microsecondsSinceEpoch}-$index'
                                  : message.id,
                            ),
                            child: TwitchRuntimeMessageTile(
                              message: message,
                            ),
                          );
                        },
                      ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: IgnorePointer(
                        ignoring: _nearBottom || messages.isEmpty,
                        child: AnimatedOpacity(
                          opacity: !_nearBottom && messages.isNotEmpty ? 1 : 0,
                          duration: const Duration(milliseconds: 120),
                          child: ElevatedButton.icon(
                            onPressed: _jumpToBottom,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            label: const Text('最新'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9146FF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RuntimeChatHeader extends StatelessWidget {
  final TwitchChatRuntime runtime;
  final VoidCallback? onReconnect;

  const _RuntimeChatHeader({
    required this.runtime,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2D)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              runtime.channelLogin.isEmpty ? '聊天室' : '#${runtime.channelLogin}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '${runtime.messages.length}/${runtime.maxMessages}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          if (runtime.connecting)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              runtime.connected ? Icons.circle : Icons.circle_outlined,
              size: 12,
              color: runtime.connected ? Colors.greenAccent : Colors.white38,
            ),
          if (onReconnect != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: '重新連線聊天室',
              onPressed: runtime.connecting ? null : onReconnect,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ],
      ),
    );
  }
}
