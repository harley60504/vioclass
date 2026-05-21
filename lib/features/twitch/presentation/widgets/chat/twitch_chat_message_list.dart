// PATCH VERSION: twitch_chat_message_list_stage242_simple_frosty_like

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../services/chat/twitch_chat_runtime.dart';
import '../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../sheets/twitch_chat_message_context_sheet.dart';
import 'twitch_runtime_message_tile.dart';

class TwitchChatMessageList extends StatefulWidget {
  final TwitchChatRuntime runtime;
  final TwitchThirdPartyEmoteCacheService thirdPartyEmoteCache;
  final TwitchOfficialEmoteCacheService? officialEmoteCache;
  final bool showTimestamp;
  final double fontScale;
  final bool compact;
  final ValueChanged<TwitchChatRuntimeMessage>? onOpenMessageContext;

  const TwitchChatMessageList({
    super.key,
    required this.runtime,
    required this.thirdPartyEmoteCache,
    this.officialEmoteCache,
    this.showTimestamp = false,
    this.fontScale = 1.0,
    this.compact = false,
    this.onOpenMessageContext,
  });

  @override
  State<TwitchChatMessageList> createState() => _TwitchChatMessageListState();
}

class _TwitchChatMessageListState extends State<TwitchChatMessageList> {
  static const double _autoScrollThreshold = 36;
  static const double _cheapResumeAnimationDistance = 420;
  static const int _autoFollowRenderMessageLimit = 100;
  static const Duration _bufferFlushInterval = Duration(milliseconds: 200);
  static const Duration _scrollAnimationDuration = Duration(milliseconds: 120);

  final ScrollController _scrollController = ScrollController();
  final Expando<String> _messageFingerprintCache = Expando<String>(
    'twitch-chat-message-fingerprint',
  );

  bool _autoScroll = true;
  bool _programmaticScrollActive = false;
  bool _followLatestScheduled = false;
  int _lastSourceMessageCount = 0;
  int _hiddenNewMessageCount = 0;
  String _lastSourceNewestFingerprint = '';

  Timer? _bufferFlushTimer;
  List<TwitchChatRuntimeMessage>? _pendingBufferedSourceMessages;

  List<TwitchChatRuntimeMessage> _visibleMessages = <TwitchChatRuntimeMessage>[];

  TwitchChatRuntime get runtime => widget.runtime;

  @override
  void initState() {
    super.initState();
    _resetVisibleMessagesFromRuntime(forceAutoScroll: true);
    _scrollController.addListener(_handleScrollChanged);
    _scheduleFollowLatest(animated: false);
  }

  @override
  void didUpdateWidget(covariant TwitchChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.runtime != widget.runtime) {
      _bufferFlushTimer?.cancel();
      _pendingBufferedSourceMessages = null;
      _resetVisibleMessagesFromRuntime(forceAutoScroll: true);
      _scheduleFollowLatest(animated: false);
      return;
    }

    _syncVisibleMessagesFromRuntime();
  }

  @override
  void dispose() {
    _bufferFlushTimer?.cancel();
    _scrollController.removeListener(_handleScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _resetVisibleMessagesFromRuntime({required bool forceAutoScroll}) {
    final sourceMessages = runtime.messages;
    if (forceAutoScroll) _autoScroll = true;
    _visibleMessages = _renderMessagesForCurrentMode(sourceMessages);
    _lastSourceMessageCount = sourceMessages.length;
    _lastSourceNewestFingerprint = _newestMessageFingerprint(sourceMessages);
    _hiddenNewMessageCount = 0;
  }

  List<TwitchChatRuntimeMessage> _renderMessagesForCurrentMode(
    List<TwitchChatRuntimeMessage> sourceMessages,
  ) {
    if (!_autoScroll || sourceMessages.length <= _autoFollowRenderMessageLimit) {
      return List<TwitchChatRuntimeMessage>.of(sourceMessages);
    }

    return sourceMessages
        .sublist(sourceMessages.length - _autoFollowRenderMessageLimit)
        .toList(growable: false);
  }

  void _syncVisibleMessagesFromRuntime() {
    final sourceMessages = runtime.messages;
    final sourceCount = sourceMessages.length;
    final sourceNewestFingerprint = _newestMessageFingerprint(sourceMessages);

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

    final nearLatest = _isNearLatest;
    final shouldAutoFollow = _autoScroll || nearLatest;

    if (shouldAutoFollow) {
      _autoScroll = true;
      _hiddenNewMessageCount = 0;
      _pendingBufferedSourceMessages = sourceMessages;
      _scheduleBufferedViewFlush();
      return;
    }

    if (estimatedAddedCount > 0) {
      _hiddenNewMessageCount += estimatedAddedCount;
    }
  }

  void _scheduleBufferedViewFlush() {
    if (_bufferFlushTimer?.isActive ?? false) return;

    _bufferFlushTimer = Timer(_bufferFlushInterval, () {
      final sourceMessages = _pendingBufferedSourceMessages ?? runtime.messages;
      _pendingBufferedSourceMessages = null;
      if (!mounted) return;
      if (!_autoScroll && !_isNearLatest) return;

      setState(() {
        _autoScroll = true;
        _hiddenNewMessageCount = 0;
        _visibleMessages = _renderMessagesForCurrentMode(sourceMessages);
      });

      _scheduleFollowLatest(animated: false);
    });
  }

  String _newestMessageFingerprint(List<TwitchChatRuntimeMessage> messages) {
    if (messages.isEmpty) return '';
    return _messageFingerprint(messages.last);
  }

  String _messageFingerprint(TwitchChatRuntimeMessage message) {
    final cached = _messageFingerprintCache[message];
    if (cached != null) return cached;

    final id = message.id.trim();
    final fingerprint = id.isNotEmpty
        ? 'id:$id'
        : 'fallback:${message.receivedAt.microsecondsSinceEpoch}|'
            '${message.userLogin.trim().toLowerCase()}|'
            '${message.message.trim()}';

    _messageFingerprintCache[message] = fingerprint;
    return fingerprint;
  }

  String _messageStableKey(TwitchChatRuntimeMessage message) {
    return _messageFingerprint(message);
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
        _visibleMessages = _renderMessagesForCurrentMode(runtime.messages);
        _lastSourceMessageCount = runtime.messages.length;
        _lastSourceNewestFingerprint = _newestMessageFingerprint(runtime.messages);
        _hiddenNewMessageCount = 0;
      });
      _scheduleFollowLatest(animated: false);
      return;
    }

    if (!nearLatest && _autoScroll) {
      _bufferFlushTimer?.cancel();
      _pendingBufferedSourceMessages = null;
      setState(() {
        _autoScroll = false;
        _visibleMessages = _renderMessagesForCurrentMode(runtime.messages);
      });
    }
  }

  void _scheduleFollowLatest({required bool animated}) {
    if (_followLatestScheduled) return;
    _followLatestScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followLatestScheduled = false;
      if (!mounted) return;
      if (animated) {
        _animateOrJumpToLatest();
      } else {
        _jumpToLatest();
      }
    });
  }

  void _jumpToLatest() {
    if (!_scrollController.hasClients) return;
    _programmaticScrollActive = true;
    _scrollController.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _programmaticScrollActive = false;
    });
  }

  void _animateOrJumpToLatest() {
    if (!_scrollController.hasClients) return;

    final distance = _scrollController.offset.abs();
    if (distance <= 1) {
      _programmaticScrollActive = false;
      return;
    }

    if (distance > _cheapResumeAnimationDistance) {
      _jumpToLatest();
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
    _bufferFlushTimer?.cancel();
    _pendingBufferedSourceMessages = null;

    setState(() {
      _autoScroll = true;
      _visibleMessages = _renderMessagesForCurrentMode(runtime.messages);
      _lastSourceMessageCount = runtime.messages.length;
      _lastSourceNewestFingerprint = _newestMessageFingerprint(runtime.messages);
      _hiddenNewMessageCount = 0;
    });

    _scheduleFollowLatest(animated: true);
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
          ListView.builder(
            controller: _scrollController,
            reverse: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            itemCount: visibleMessages.length,
            itemBuilder: (context, index) {
              final chronologicalIndex = visibleMessages.length - 1 - index;
              final message = visibleMessages[chronologicalIndex];
              final messageKey = _messageStableKey(message);

              return TwitchRuntimeMessageTile(
                key: ValueKey<String>(messageKey),
                message: message,
                thirdPartyEmotes: widget.thirdPartyEmoteCache,
                officialEmotes: widget.officialEmoteCache,
                showTimestamp: widget.showTimestamp,
                fontScale: widget.fontScale,
                compact: widget.compact,
                animateEmotes: true,
                onOpenContext: () => _openContextSheet(message),
              );
            },
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
