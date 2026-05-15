// PATCH VERSION: chat_message_list_context_sheet_emotes_v58
// Place at: lib/features/twitch/presentation/widgets/chat/twitch_chat_message_list.dart
//
// Stage 98:
// - Keeps Stage 97 context-sheet emote rendering.
// - Adds an optional onOpenMessageContext named parameter for compatibility
//   with TwitchWatchChatPanel versions that already pass this callback.

import 'package:flutter/material.dart';

import '../../../models/chat/twitch_chat_message.dart';
import '../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../services/chat/twitch_chat_runtime.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../sheets/twitch_chat_message_context_sheet.dart';
import 'twitch_runtime_message_tile.dart';

class TwitchChatMessageList extends StatefulWidget {
  final TwitchChatRuntime runtime;
  final TwitchThirdPartyEmoteCacheService thirdPartyEmoteCache;
  final bool showTimestamp;
  final double fontScale;
  final bool compact;
  final ValueChanged<TwitchChatRuntimeMessage>? onOpenMessageContext;

  const TwitchChatMessageList({
    super.key,
    required this.runtime,
    required this.thirdPartyEmoteCache,
    this.showTimestamp = false,
    this.fontScale = 1.0,
    this.compact = false,
    this.onOpenMessageContext,
  });

  @override
  State<TwitchChatMessageList> createState() => _TwitchChatMessageListState();
}

class _TwitchChatMessageListState extends State<TwitchChatMessageList> {
  static const double _autoScrollThreshold = 72;
  static const Duration _scrollAnimationDuration = Duration(milliseconds: 140);

  final ScrollController _scrollController = ScrollController();

  bool _autoScroll = true;
  int _lastSourceMessageCount = 0;
  int _hiddenNewMessageCount = 0;

  List<TwitchChatRuntimeMessage> _visibleMessages = <TwitchChatRuntimeMessage>[];

  TwitchChatRuntime get runtime => widget.runtime;

  @override
  void initState() {
    super.initState();

    _visibleMessages = List<TwitchChatRuntimeMessage>.of(runtime.messages);
    _lastSourceMessageCount = runtime.messages.length;

    _scrollController.addListener(_handleScrollChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToLatest();
    });
  }

  @override
  void didUpdateWidget(covariant TwitchChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.runtime != widget.runtime) {
      _visibleMessages = List<TwitchChatRuntimeMessage>.of(runtime.messages);
      _lastSourceMessageCount = runtime.messages.length;
      _hiddenNewMessageCount = 0;
      _autoScroll = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToLatest();
      });
      return;
    }

    _syncVisibleMessagesFromRuntime();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _syncVisibleMessagesFromRuntime() {
    final sourceMessages = runtime.messages;
    final sourceCount = sourceMessages.length;
    final addedCount = sourceCount - _lastSourceMessageCount;

    if (addedCount == 0) {
      return;
    }

    if (addedCount < 0) {
      setState(() {
        _visibleMessages = List<TwitchChatRuntimeMessage>.of(sourceMessages);
        _lastSourceMessageCount = sourceCount;
        _hiddenNewMessageCount = 0;
      });
      return;
    }

    _lastSourceMessageCount = sourceCount;

    if (_autoScroll || _isNearLatest) {
      _visibleMessages = List<TwitchChatRuntimeMessage>.of(sourceMessages);
      _hiddenNewMessageCount = 0;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateToLatest();
      });
      return;
    }

    _hiddenNewMessageCount += addedCount;
  }

  bool get _isNearLatest {
    if (!_scrollController.hasClients) return true;
    return _scrollController.offset <= _autoScrollThreshold;
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients) return;

    final nearLatest = _isNearLatest;

    if (nearLatest && !_autoScroll) {
      setState(() {
        _autoScroll = true;
        _visibleMessages = List<TwitchChatRuntimeMessage>.of(runtime.messages);
        _lastSourceMessageCount = runtime.messages.length;
        _hiddenNewMessageCount = 0;
      });
      return;
    }

    if (!nearLatest && _autoScroll) {
      setState(() {
        _autoScroll = false;
      });
    }
  }

  void _jumpToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
  }

  void _animateToLatest() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.offset <= 1) return;

    _scrollController.animateTo(
      0,
      duration: _scrollAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _resumeLatest() {
    setState(() {
      _autoScroll = true;
      _visibleMessages = List<TwitchChatRuntimeMessage>.of(runtime.messages);
      _lastSourceMessageCount = runtime.messages.length;
      _hiddenNewMessageCount = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateToLatest();
    });
  }

  bool _isLiveMessage(TwitchChatRuntimeMessage message) {
    final source = message.source.source;
    return source == TwitchChatMessageSource.liveIrc ||
        source == TwitchChatMessageSource.localEcho;
  }

  bool _shouldShowLiveDivider(
    List<TwitchChatRuntimeMessage> messages,
    int chronologicalIndex,
  ) {
    if (chronologicalIndex <= 0 || chronologicalIndex >= messages.length) {
      return false;
    }

    final current = messages[chronologicalIndex];
    final previous = messages[chronologicalIndex - 1];

    return _isLiveMessage(current) && !_isLiveMessage(previous);
  }

  void _openContextSheet(TwitchChatRuntimeMessage message) {
    final externalHandler = widget.onOpenMessageContext;
    if (externalHandler != null) {
      externalHandler(message);
      return;
    }

    final contextMessages = runtime.messages.isEmpty
        ? _visibleMessages
        : runtime.messages;

    showTwitchChatMessageContextSheet(
      context: context,
      selectedMessage: message,
      messages: contextMessages,
      thirdPartyEmotes: widget.thirdPartyEmoteCache,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleMessages = _visibleMessages;

    if (visibleMessages.isEmpty) {
      return const Center(
        child: Text(
          '等待聊天室訊息...',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Container(
      color: const Color(0xFF0E0E10),
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is UserScrollNotification ||
                  notification is ScrollEndNotification) {
                _handleScrollChanged();
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              itemCount: visibleMessages.length,
              itemBuilder: (context, index) {
                final chronologicalIndex = visibleMessages.length - 1 - index;
                final message = visibleMessages[chronologicalIndex];
                final showLiveDivider = _shouldShowLiveDivider(
                  visibleMessages,
                  chronologicalIndex,
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showLiveDivider)
                      _LiveMessageDivider(fontScale: widget.fontScale),
                    TwitchRuntimeMessageTile(
                      message: message,
                      thirdPartyEmotes: widget.thirdPartyEmoteCache,
                      showTimestamp: widget.showTimestamp,
                      fontScale: widget.fontScale,
                      compact: widget.compact,
                      onOpenContext: () => _openContextSheet(message),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: IgnorePointer(
              ignoring: _hiddenNewMessageCount <= 0 && _autoScroll,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _hiddenNewMessageCount > 0 || !_autoScroll ? 1 : 0,
                child: Center(
                  child: _ScrollResumePill(
                    hiddenNewMessageCount: _hiddenNewMessageCount,
                    onPressed: _resumeLatest,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMessageDivider extends StatelessWidget {
  final double fontScale;

  const _LiveMessageDivider({
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    final scale = fontScale < 0.85
        ? 0.85
        : fontScale > 1.25
            ? 1.25
            : fontScale;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.08))),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF9146FF).withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.32)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.flash_on_rounded,
                  color: Color(0xFFBF94FF),
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  '以下是即時訊息',
                  style: TextStyle(
                    color: const Color(0xFFD8C3FF),
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.08))),
        ],
      ),
    );
  }
}

class _ScrollResumePill extends StatelessWidget {
  final int hiddenNewMessageCount;
  final VoidCallback onPressed;

  const _ScrollResumePill({
    required this.hiddenNewMessageCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = hiddenNewMessageCount > 0
        ? '$hiddenNewMessageCount 則新訊息'
        : '回到最新訊息';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF9146FF),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                blurRadius: 14,
                offset: Offset(0, 4),
                color: Color(0x66000000),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
