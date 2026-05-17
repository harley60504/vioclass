// PATCH VERSION: chat_message_list_stage200_live_divider_boundary_fix
// Place at: lib/features/twitch/presentation/widgets/chat/twitch_chat_message_list.dart
//
// Stage 190:
// - Fixes chat list freezing after the runtime reaches maxMessages.
// - Previous logic only compared message count. Once TwitchChatRuntime hits the
//   capped length, every new message removes one old message, so the count stays
//   unchanged and the UI can stop syncing.
// - This version also tracks the newest message fingerprint so rollover updates
//   still refresh the visible list.
//
// Stage 197:
// - Chat list no longer paints its own solid #0E0E10 background, so Watch chat
//   panel has one unified background instead of stacked dark blocks.
// - Purple accents are reduced to softer blue-purple tones.
//
// Stage 200:
// - Moves the live divider from the first live message to the last old/history
//   message. This keeps the divider at the same visual boundary, but prevents
//   the first live IRC message tile from owning the divider and appearing twice
//   in some rollover / rebuild cases.

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
  static const double _autoScrollThreshold = 120;
  static const Duration _scrollAnimationDuration = Duration(milliseconds: 120);

  final ScrollController _scrollController = ScrollController();

  bool _autoScroll = true;
  bool _programmaticScrollActive = false;
  int _lastSourceMessageCount = 0;
  int _hiddenNewMessageCount = 0;
  String _lastSourceNewestFingerprint = '';

  List<TwitchChatRuntimeMessage> _visibleMessages = <TwitchChatRuntimeMessage>[];

  TwitchChatRuntime get runtime => widget.runtime;

  @override
  void initState() {
    super.initState();

    _resetVisibleMessagesFromRuntime(forceAutoScroll: true);

    _scrollController.addListener(_handleScrollChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToLatest();
    });
  }

  @override
  void didUpdateWidget(covariant TwitchChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.runtime != widget.runtime) {
      _resetVisibleMessagesFromRuntime(forceAutoScroll: true);

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

  void _resetVisibleMessagesFromRuntime({required bool forceAutoScroll}) {
    final sourceMessages = runtime.messages;
    _visibleMessages = List<TwitchChatRuntimeMessage>.of(sourceMessages);
    _lastSourceMessageCount = sourceMessages.length;
    _lastSourceNewestFingerprint = _newestMessageFingerprint(sourceMessages);
    _hiddenNewMessageCount = 0;
    if (forceAutoScroll) _autoScroll = true;
  }

  void _syncVisibleMessagesFromRuntime() {
    final sourceMessages = runtime.messages;
    final sourceCount = sourceMessages.length;
    final sourceNewestFingerprint = _newestMessageFingerprint(sourceMessages);

    // Count alone is not enough: runtime.messages is capped. When the cap is
    // reached, a new incoming message removes the oldest item, so the total
    // length stays unchanged. Without this fingerprint check, the chat UI can
    // look frozen while IRC is still receiving messages.
    final sourceChanged = sourceCount != _lastSourceMessageCount ||
        sourceNewestFingerprint != _lastSourceNewestFingerprint;

    if (!sourceChanged) return;

    final previousCount = _lastSourceMessageCount;
    final previousNewestFingerprint = _lastSourceNewestFingerprint;
    final estimatedAddedCount = _estimateAddedMessageCount(
      sourceMessages: sourceMessages,
      previousCount: previousCount,
      previousNewestFingerprint: previousNewestFingerprint,
    );

    _lastSourceMessageCount = sourceCount;
    _lastSourceNewestFingerprint = sourceNewestFingerprint;

    if (_autoScroll || _isNearLatest) {
      _visibleMessages = List<TwitchChatRuntimeMessage>.of(sourceMessages);
      _hiddenNewMessageCount = 0;
      _autoScroll = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateToLatest();
      });
      return;
    }

    if (estimatedAddedCount > 0) {
      _hiddenNewMessageCount += estimatedAddedCount;
    }
  }

  String _newestMessageFingerprint(List<TwitchChatRuntimeMessage> messages) {
    if (messages.isEmpty) return '';
    return _messageFingerprint(messages.last);
  }

  String _messageFingerprint(TwitchChatRuntimeMessage message) {
    final id = message.id.trim();
    if (id.isNotEmpty) return 'id:$id';

    final login = message.userLogin.trim().toLowerCase();
    final text = message.message.trim();
    final micros = message.receivedAt.microsecondsSinceEpoch;
    return 'fallback:$micros|$login|$text';
  }

  int _estimateAddedMessageCount({
    required List<TwitchChatRuntimeMessage> sourceMessages,
    required int previousCount,
    required String previousNewestFingerprint,
  }) {
    if (sourceMessages.isEmpty) return 0;

    final countDelta = sourceMessages.length - previousCount;
    if (countDelta > 0) return countDelta;

    if (previousNewestFingerprint.isEmpty) return sourceMessages.length;

    var messagesAfterPreviousNewest = 0;
    for (var index = sourceMessages.length - 1; index >= 0; index -= 1) {
      if (_messageFingerprint(sourceMessages[index]) == previousNewestFingerprint) {
        return messagesAfterPreviousNewest;
      }
      messagesAfterPreviousNewest += 1;
    }

    // The previous newest message is already outside the capped runtime list.
    // This usually means a very active chat. Do not show a misleading huge
    // number; just show that there are new messages and resume correctly when
    // tapped.
    return 1;
  }

  bool get _isNearLatest {
    if (!_scrollController.hasClients) return true;
    return _scrollController.offset <= _autoScrollThreshold;
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients || _programmaticScrollActive) return;

    final nearLatest = _isNearLatest;

    if (nearLatest && !_autoScroll) {
      setState(() {
        _autoScroll = true;
        _visibleMessages = List<TwitchChatRuntimeMessage>.of(runtime.messages);
        _lastSourceMessageCount = runtime.messages.length;
        _lastSourceNewestFingerprint = _newestMessageFingerprint(runtime.messages);
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
    _programmaticScrollActive = true;
    _scrollController.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _programmaticScrollActive = false;
    });
  }

  void _animateToLatest() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.offset <= 1) {
      _programmaticScrollActive = false;
      return;
    }

    _programmaticScrollActive = true;
    _scrollController
        .animateTo(
          0,
          duration: _scrollAnimationDuration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
      _programmaticScrollActive = false;
      if (!mounted) return;
      if (_isNearLatest && !_autoScroll) {
        setState(() => _autoScroll = true);
      }
    });
  }

  void _resumeLatest() {
    setState(() {
      _autoScroll = true;
      _visibleMessages = List<TwitchChatRuntimeMessage>.of(runtime.messages);
      _lastSourceMessageCount = runtime.messages.length;
      _lastSourceNewestFingerprint = _newestMessageFingerprint(runtime.messages);
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

  bool _shouldShowLiveDividerAfter(
    List<TwitchChatRuntimeMessage> messages,
    int chronologicalIndex,
  ) {
    if (chronologicalIndex < 0 || chronologicalIndex >= messages.length - 1) {
      return false;
    }

    final current = messages[chronologicalIndex];
    final next = messages[chronologicalIndex + 1];

    return !_isLiveMessage(current) && _isLiveMessage(next);
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

    return ColoredBox(
      color: Colors.transparent,
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
                final showLiveDividerAfter = _shouldShowLiveDividerAfter(
                  visibleMessages,
                  chronologicalIndex,
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TwitchRuntimeMessageTile(
                      message: message,
                      thirdPartyEmotes: widget.thirdPartyEmoteCache,
                      showTimestamp: widget.showTimestamp,
                      fontScale: widget.fontScale,
                      compact: widget.compact,
                      onOpenContext: () => _openContextSheet(message),
                    ),
                    if (showLiveDividerAfter)
                      _LiveMessageDivider(fontScale: widget.fontScale),
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
          Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.07))),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF7C6AA8).withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF8F7CC0).withOpacity(0.24)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.flash_on_rounded,
                  color: Color(0xFFB6A4E2),
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  '以下是即時訊息',
                  style: TextStyle(
                    color: const Color(0xFFC9BDEC),
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.07))),
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
            color: const Color(0xFF6D5A9E),
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
