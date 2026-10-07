import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../models/chat/twitch_whisper_conversation.dart';
import '../../services/chat/twitch_whisper_inbox_controller.dart';
import '../../services/chat/twitch_whisper_archive_store.dart';
import '../localization/vioclass_localizations.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import '../widgets/chat/twitch_selectable_emote.dart';
import '../widgets/chat/twitch_whisper_selection.dart';
import '../widgets/shared/twitch_notice.dart';
import '../widgets/shared/twitch_emote_image.dart';
import '../widgets/shared/twitch_emote_picker_flow.dart';
import '../widgets/shared/twitch_emote_picker_panel.dart';
import '../widgets/shared/twitch_emoji_picker.dart';
import '../../models/emotes/twitch_official_emote.dart';

Future<void> showTwitchWhisperSheet({
  required BuildContext context,
  required TwitchWhisperInboxController controller,
  Future<void> Function()? onAuthorize,
  bool automaticSync = true,
}) async {
  controller.setPanelVisible(true);
  try {
    await showTwitchResponsiveSheet<void>(
      context: context,
      size: TwitchUnifiedSheetSize.large,
      builder: (_) => _WhisperSheet(
        controller: controller,
        onAuthorize: onAuthorize,
        automaticSync: automaticSync,
      ),
    );
  } finally {
    controller.setPanelVisible(false);
    await controller.flushDrafts();
  }
}

class _WhisperSheet extends StatefulWidget {
  final TwitchWhisperInboxController controller;
  final Future<void> Function()? onAuthorize;
  final bool automaticSync;
  const _WhisperSheet({
    required this.controller,
    this.onAuthorize,
    required this.automaticSync,
  });
  @override
  State<_WhisperSheet> createState() => _WhisperSheetState();
}

class _WhisperSheetState extends State<_WhisperSheet> {
  final _message = TextEditingController();
  final _filter = TextEditingController();
  final _scroll = ScrollController(keepScrollOffset: false);
  String? _displayedPeer;
  int _messageCount = 0;
  Set<String> _observedIds = {};
  Set<String> _observedHistoricalIds = {};
  int _latestCount = 0;
  GlobalKey _lastBubbleKey = GlobalKey();
  String? _historyCenterId;
  int _scrollRequest = 0;
  bool _seekingLatest = false;
  bool _userDragging = false;
  bool _metricsPending = false;
  String _sort = 'recent';
  bool _authorizing = false;
  bool _showEmotes = false;
  bool _emojiOnly = false;
  bool _openingSync = false;
  bool _historyQueued = false;
  bool _enteredAtLatest = false;

  bool _canAutoSync(String? owner) =>
      mounted && inbox.panelVisible && owner != null && inbox.ownerId == owner;

  Future<void> _syncOnOpen() async {
    if (!widget.automaticSync || _openingSync) return;
    final owner = inbox.ownerId;
    if (!_canAutoSync(owner)) return;
    _openingSync = true;
    try {
      if (inbox.threadsApi != null &&
          !inbox.syncingThreads &&
          !inbox.syncingHistory) {
        await inbox.syncThreads();
        // Bound automatic pagination; a long inbox continues when scrolled.
        for (
          var page = 1;
          page < 10 &&
              _canAutoSync(owner) &&
              !inbox.threadsComplete &&
              inbox.threadsError == null;
          page++
        ) {
          await inbox.syncThreads(more: true);
        }
      }
    } finally {
      _openingSync = false;
      if (_canAutoSync(owner)) {
        _historyQueued = true;
        unawaited(_syncOpenedHistory());
      } else if (mounted && inbox.panelVisible && inbox.ownerId != null) {
        // A changed account starts its own request, never reuses the old page.
        unawaited(_syncOnOpen());
      }
    }
  }

  bool _historyAutoBusy = false;
  void _onAutomaticSyncIdle() {
    if (_historyQueued &&
        !_openingSync &&
        !_historyAutoBusy &&
        !inbox.syncingThreads &&
        !inbox.syncingHistory) {
      unawaited(_syncOpenedHistory());
    }
  }

  Future<void> _syncOpenedHistory() async {
    if (!widget.automaticSync || _openingSync || _historyAutoBusy) return;
    _historyAutoBusy = true;
    try {
      while (_historyQueued && mounted && inbox.panelVisible) {
        if (inbox.syncingHistory || inbox.syncingThreads) return;
        _historyQueued = false;
        final owner = inbox.ownerId;
        final peer = inbox.activePeerId;
        if (!_canAutoSync(owner) ||
            peer == null ||
            inbox.historyApi == null ||
            inbox.syncingHistory ||
            inbox.syncingThreads) {
          return;
        }
        await inbox.syncActiveHistory();
        if (!_canAutoSync(owner)) return;
      }
    } finally {
      _historyAutoBusy = false;
    }
  }

  TwitchWhisperInboxController get inbox => widget.controller;

  bool get _showReceiveStatus =>
      inbox.receiveStatus != '私訊收件已連線' && inbox.receiveStatus != '私訊收件尚未連線';

  bool get _showStatusRow =>
      _showReceiveStatus ||
      (inbox.canRecoverHistory && !widget.automaticSync) ||
      inbox.recoveringHistory ||
      inbox.recoveryError != null ||
      (!widget.automaticSync && inbox.recoveryStatus != null) ||
      (widget.onAuthorize != null && !inbox.sessionReady);

  bool get _canAuthorize =>
      !_authorizing &&
      !inbox.loading &&
      !inbox.sending &&
      !inbox.managingHistory &&
      !inbox.syncingHistory &&
      !inbox.syncingThreads;

  Future<bool> _reauthorize() async {
    final authorize = widget.onAuthorize;
    if (authorize == null || !_canAuthorize) return false;
    setState(() => _authorizing = true);
    try {
      await inbox.flushDrafts();
      if (!mounted) return false;
      await authorize();
      if (!mounted) return false;
      await inbox.refreshSession(afterCurrent: true);
      if (mounted) await inbox.loadOfficialEmotes();
      if (mounted) unawaited(_syncOnOpen());
      return mounted && inbox.ownerId != null;
    } catch (_) {
      if (mounted) {
        showTwitchNotice(
          context,
          context.vio.t('私訊重新授權未完成，原本對話與草稿仍保留。'),
          tone: TwitchNoticeTone.error,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _authorizing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    inbox.addListener(_onAutomaticSyncIdle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (inbox.ownerId == null) {
        unawaited(
          inbox.refreshSession().then((_) {
            if (mounted) {
              unawaited(inbox.loadOfficialEmotes());
              unawaited(_syncOnOpen());
            }
          }),
        );
      } else {
        unawaited(inbox.selectConversation(inbox.activePeerId));
        unawaited(inbox.loadOfficialEmotes());
        unawaited(_syncOnOpen());
      }
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients || !mounted) return;
    if (_seekingLatest) return;
    final latest =
        _scroll.position.extentBefore <= 36 &&
        (_messageCount == 0 || _lastBubbleKey.currentContext != null);
    final changed = inbox.readingLatest != latest;
    inbox.setReadingLatest(latest);
    if (latest) _enteredAtLatest = true;
    if (widget.automaticSync &&
        _enteredAtLatest &&
        !latest &&
        _scroll.position.extentAfter <= 24 &&
        inbox.historyApi != null &&
        inbox.historyError == null &&
        !_openingSync &&
        !_historyAutoBusy &&
        !inbox.syncingThreads &&
        !inbox.syncingHistory &&
        inbox.activeConversation?.remoteHistoryComplete == false) {
      unawaited(inbox.syncActiveHistory(older: true));
    }
    if (changed || (latest && _latestCount != 0)) {
      setState(() {
        if (latest) _latestCount = 0;
      });
    }
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentBefore <= .5 &&
        (_messageCount == 0 || _lastBubbleKey.currentContext != null)) {
      _onScroll();
      return;
    }
    final request = ++_scrollRequest;
    final peer = _displayedPeer;
    _seekingLatest = true;
    void settle(int attempt) {
      if (!mounted ||
          request != _scrollRequest ||
          _displayedPeer != peer ||
          !_scroll.hasClients) {
        return;
      }
      // Lazy variable-height rows revise the estimated maximum after layout.
      // Do not clear unread at an estimated end before the actual tail exists.
      _scroll.jumpTo(_scroll.position.minScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            request != _scrollRequest ||
            _displayedPeer != peer ||
            !_scroll.hasClients) {
          return;
        }
        final atTail =
            _scroll.position.extentBefore <= 0.5 &&
            (_messageCount == 0 || _lastBubbleKey.currentContext != null);
        if (atTail || attempt >= 32) {
          _seekingLatest = false;
          _onScroll();
        } else {
          settle(attempt + 1);
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    }

    settle(0);
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0 || _metricsPending) return false;
    _metricsPending = true;
    final peer = _displayedPeer;
    final request = _scrollRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsPending = false;
      if (!mounted || peer != _displayedPeer || !_scroll.hasClients) return;
      if (request != _scrollRequest) return;
      if (_seekingLatest || _userDragging) return;
      _onScroll();
    });
    WidgetsBinding.instance.scheduleFrame();
    return false;
  }

  bool _onUserScroll(ScrollNotification notification) {
    if (notification.depth == 0 &&
        notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      ++_scrollRequest;
      _seekingLatest = false;
      _userDragging = true;
    } else if (notification.depth == 0 &&
        notification is ScrollEndNotification &&
        _userDragging) {
      _userDragging = false;
      _onScroll();
    }
    return false;
  }

  void _cancelLatestSeek() {
    ++_scrollRequest;
    _seekingLatest = false;
    _onScroll();
  }

  @override
  void dispose() {
    inbox.removeListener(_onAutomaticSyncIdle);
    _message.dispose();
    _filter.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _recoveryLabel {
    if (inbox.savingRecovery) return '正在保存恢復資料與進度…';
    if (inbox.recoveringHistory) {
      final work = inbox.recoveryProgress;
      return work?.phase == 'history'
          ? '正在恢復對話 ${(work!.peerIndex + 1)}/${work.peerIds.length}…'
          : '正在列舉全部對話…';
    }
    return inbox.recoveryError ??
        inbox.recoveryStatus ??
        (inbox.recoveryProgress?.complete == false
            ? '有未完成的歷史恢復，可從保存進度續接。'
            : '恢復全部對話歷史');
  }

  Widget _recoveryMenu() => PopupMenuButton<String>(
    key: const ValueKey('whisper-recovery-menu'),
    tooltip: context.vio.t(_recoveryLabel),
    icon: const Icon(Icons.history_rounded),
    enabled: inbox.ownerId != null && !inbox.loading,
    onSelected: _historyAction,
    itemBuilder: (_) => [
      PopupMenuItem(enabled: false, child: Text(context.vio.t(_recoveryLabel))),
      PopupMenuItem(
        value: 'recoverAll',
        enabled:
            !inbox.managingHistory &&
            !inbox.sending &&
            !inbox.syncingHistory &&
            !inbox.syncingThreads,
        child: Text(context.vio.t('恢復全部對話歷史／續接')),
      ),
      if (inbox.recoveringHistory)
        PopupMenuItem(
          value: 'cancelRecovery',
          enabled: inbox.canCancelRecovery,
          child: Text(context.vio.t('取消恢復，保留進度')),
        ),
    ],
  );

  Future<void> _newConversation() async {
    final recipient = TextEditingController();
    final login = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.vio.t('新增對話')),
        content: TextField(
          controller: recipient,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.vio.t('收件者 Twitch 帳號'),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.vio.t('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, recipient.text),
            child: Text(context.vio.t('開啟對話')),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), recipient.dispose);
    if (mounted && login != null) await inbox.startConversation(login);
  }

  Future<void> _historyAction(String action) async {
    if (action == 'recoverAll') {
      await inbox.recoverHistory();
      return;
    }
    if (action == 'cancelRecovery') {
      inbox.cancelRecovery();
      return;
    }
    if (action == 'gapHistory') {
      await inbox.syncActiveHistory();
      return;
    }
    if (action == 'authorizeSync') {
      final owner = inbox.ownerId;
      final authorized = await _reauthorize();
      if (authorized && mounted && owner != null && inbox.ownerId == owner) {
        await inbox.syncThreads();
      }
      return;
    }
    if (action == 'syncThreads' || action == 'moreThreads') {
      await inbox.syncThreads(more: action == 'moreThreads');
      return;
    }
    if (action == 'export') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.vio.t('複製私訊備份')),
          content: Text(context.vio.t('備份包含私人對話，將複製到剪貼簿。請妥善保存，不要貼到公開場合。')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.vio.t('取消')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.vio.t('複製')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      try {
        final raw = await inbox.exportBackup();
        if (raw != null && mounted) {
          await Clipboard.setData(ClipboardData(text: raw));
          if (mounted) await _showHistoryResult('私訊備份已複製到剪貼簿。');
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                context.vio.t(
                  error is TwitchWhisperArchiveException
                      ? error.message
                      : '私訊草稿或歷史儲存失敗，請稍後再試。',
                ),
              ),
            ),
          );
        }
      }
      return;
    }
    final input = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.vio.t('匯入私訊備份')),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: input,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: context.vio.t(
                '貼上目前 Twitch 帳號的 VioClass 私訊備份；只合併本機歷史，不向 Twitch 發送。',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.vio.t('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, input.text),
            child: Text(context.vio.t('匯入')),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), input.dispose);
    if (mounted && raw != null) {
      final added = await inbox.importBackup(raw);
      if (mounted && added != null) {
        await _showHistoryResult(
          '${context.vio.t('已合併本機私訊')}：$added ${context.vio.t('則新訊息')}',
        );
      }
    }
  }

  Future<void> _showHistoryResult(String message) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(context.vio.t(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.vio.t('關閉')),
        ),
      ],
    ),
  );

  void _insertEmoji(String emoji, TwitchWhisperConversation peer) {
    final selection = _message.selection;
    final start = selection.isValid ? selection.start : _message.text.length;
    final end = selection.isValid ? selection.end : _message.text.length;
    final text = _message.text.replaceRange(start, end, emoji);
    if (text.length > peer.messageLimit) return;
    _message.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    inbox.updateDraft(peer.userId, text);
    setState(() {});
  }

  void _toggleEmotes({required bool emojiOnly}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _showEmotes = !_showEmotes || _emojiOnly != emojiOnly;
      _emojiOnly = emojiOnly;
    });
    if (_showEmotes) unawaited(inbox.loadOfficialEmotes());
  }

  void _insertOfficialEmote(
    TwitchOfficialEmote chosen,
    TwitchWhisperConversation peer,
    String? owner,
  ) {
    final selection = _message.selection;
    if (!mounted ||
        inbox.ownerId != owner ||
        inbox.activePeerId != peer.userId ||
        inbox.activeConversation?.draft != _message.text ||
        inbox.emoteError != null ||
        inbox.loadingEmotes ||
        !inbox.emoteCatalog.emotes.any(
          (emote) => emote.id == chosen.id && emote.name == chosen.name,
        )) {
      return;
    }
    final start = selection.isValid ? selection.start : _message.text.length;
    final end = selection.isValid ? selection.end : _message.text.length;
    if (start > _message.text.length || end > _message.text.length) return;
    final before = _message.text.substring(0, start);
    final after = _message.text.substring(end);
    final inserted =
        '${before.isNotEmpty && !RegExp(r'\s$').hasMatch(before) ? ' ' : ''}${chosen.name}${after.isNotEmpty && !RegExp(r'^\s').hasMatch(after) ? ' ' : ''}';
    _message.selection = TextSelection(baseOffset: start, extentOffset: end);
    _insertEmoji(inserted, inbox.activeConversation!);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: inbox,
    builder: (context, _) {
      final peer = inbox.activeConversation;
      final peerKey = peer == null ? null : '${inbox.ownerId}:${peer.userId}';
      final changed = _displayedPeer != peerKey;
      if (changed) {
        _enteredAtLatest = false;
        _showEmotes = false;
        ++_scrollRequest;
        _seekingLatest = false;
        _userDragging = false;
        _lastBubbleKey = GlobalKey();
        _historyCenterId = peer?.displayMessages.lastOrNull?.id;
      }
      final wasNearEnd =
          !_scroll.hasClients || inbox.readingLatest || _seekingLatest;
      if (changed || wasNearEnd) {
        _latestCount = 0;
      } else if (peer != null) {
        _latestCount += peer.messages
            .where(
              (message) =>
                  (!_observedIds.contains(message.id) ||
                      _observedHistoricalIds.contains(message.id)) &&
                  !inbox.isHistoricalMessage(message.id) &&
                  message.fromUserId == peer.userId &&
                  message.toUserId == inbox.ownerId &&
                  message.state == TwitchWhisperMessageState.received,
            )
            .length;
      }
      _observedIds = peer?.messages.map((message) => message.id).toSet() ?? {};
      _observedHistoricalIds =
          peer?.messages
              .where((message) => inbox.isHistoricalMessage(message.id))
              .map((message) => message.id)
              .toSet() ??
          {};
      _displayedPeer = peerKey;
      _messageCount = peer?.displayMessages.length ?? 0;
      if (changed && peer != null) {
        final request = _scrollRequest;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _displayedPeer == peerKey &&
              request == _scrollRequest &&
              inbox.readingLatest) {
            // The initial tail is anchored during layout, not sought afterwards.
            _onScroll();
            _historyQueued = true;
            unawaited(_syncOpenedHistory());
          }
        });
      }
      if (_message.text != (peer?.draft ?? '')) {
        final text = peer?.draft ?? '';
        _message.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight = MediaQuery.textScalerOf(
            context,
          ).scale(400).clamp(400.0, double.infinity);
          final media = MediaQuery.of(context);
          final usableHeight =
              media.size.height -
              media.viewInsets.bottom -
              media.padding.vertical;
          final useCompact =
              constraints.maxHeight < compactHeight ||
              usableHeight < compactHeight;
          final showingBoth = constraints.maxWidth >= 620 && !useCompact;
          return PopScope<void>(
            canPop: showingBoth || peer == null,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && !showingBoth && inbox.activePeerId != null) {
                unawaited(inbox.selectConversation(null));
              }
            },
            child: Builder(
              builder: (context) {
                if (useCompact) {
                  return Material(
                    color: TwitchUiColors.surfacePanel,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 44,
                          child: Row(
                            children: [
                              if (peer != null)
                                IconButton(
                                  tooltip: context.vio.t('返回對話列表'),
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () =>
                                      inbox.selectConversation(null),
                                ),
                              Expanded(
                                child: inbox.errorText != null
                                    ? Tooltip(
                                        message: context.vio.t('私訊錯誤詳情'),
                                        child: TextButton(
                                          onPressed: () {
                                            final error = inbox.errorText!;
                                            showDialog<void>(
                                              context: context,
                                              builder: (dialogContext) =>
                                                  AlertDialog(
                                                    scrollable: true,
                                                    title: Text(
                                                      context.vio.t('私訊錯誤詳情'),
                                                    ),
                                                    content: Text(
                                                      context.vio.t(error),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop(),
                                                        child: Text(
                                                          context.vio.t('關閉'),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            );
                                          },
                                          child: Text(
                                            context.vio.t('私訊發生問題（點此查看）'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        peer?.displayName ??
                                            context.vio.t('Twitch 私訊'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                              if (inbox.canRecoverHistory &&
                                  !widget.automaticSync)
                                _recoveryMenu(),
                              if (inbox.historyRecoveryNeeded &&
                                  !widget.automaticSync)
                                PopupMenuButton<String>(
                                  key: const ValueKey('whisper-gap-menu'),
                                  tooltip: context.vio.t(
                                    '可能有未恢復的收件區間；連線不代表歷史已補齊。',
                                  ),
                                  icon: const Icon(Icons.warning_amber_rounded),
                                  enabled:
                                      !inbox.loading &&
                                      !inbox.sending &&
                                      !inbox.managingHistory &&
                                      !inbox.syncingThreads &&
                                      !inbox.syncingHistory,
                                  onSelected: _historyAction,
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      key: const ValueKey(
                                        'whisper-gap-threads',
                                      ),
                                      value: 'syncThreads',
                                      enabled: inbox.threadsApi != null,
                                      child: Text(context.vio.t('同步對話列表')),
                                    ),
                                    if (peer != null)
                                      PopupMenuItem(
                                        key: const ValueKey(
                                          'whisper-gap-history',
                                        ),
                                        value: 'gapHistory',
                                        enabled: inbox.historyApi != null,
                                        child: Text(context.vio.t('同步此對話歷史')),
                                      ),
                                  ],
                                ),
                              if (peer != null) _historyMenu(peer),
                              if (widget.onAuthorize != null &&
                                  !inbox.sessionReady)
                                IconButton(
                                  tooltip: context.vio.t('重新授權私訊'),
                                  onPressed: _canAuthorize
                                      ? _reauthorize
                                      : null,
                                  icon: const Icon(Icons.login_rounded),
                                ),
                              IconButton(
                                tooltip: context.vio.t('關閉'),
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: peer == null
                              ? _conversationList()
                              : _conversation(
                                  peer,
                                  showBack: false,
                                  compact: true,
                                ),
                        ),
                      ],
                    ),
                  );
                }
                return TwitchUnifiedSheetScaffold(
                  showRefresh: false,
                  onClose: () => Navigator.of(context).pop(),
                  title: context.vio.t('Twitch 私訊'),
                  subtitle: inbox.ownerId == null
                      ? context.vio.t('請先登入 Twitch 再使用私訊。')
                      : '@${inbox.ownerName}',
                  icon: Icons.chat_bubble_outline,
                  loading:
                      inbox.loading || inbox.searching || inbox.managingHistory,
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        if (inbox.errorText != null)
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              context.vio.t(inbox.errorText!),
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        if (_showStatusRow)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.start,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                if (_showReceiveStatus)
                                  Text(
                                    context.vio.t(inbox.receiveStatus),
                                    style: const TextStyle(
                                      color: TwitchUiColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (inbox.canRecoverHistory &&
                                    !widget.automaticSync)
                                  _recoveryMenu(),
                                if (inbox.recoveringHistory ||
                                    inbox.recoveryError != null ||
                                    (!widget.automaticSync &&
                                        inbox.recoveryStatus != null))
                                  Text(
                                    context.vio.t(_recoveryLabel),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: TwitchUiColors.textSecondary,
                                    ),
                                  ),
                                if (widget.onAuthorize != null &&
                                    !inbox.sessionReady)
                                  TextButton.icon(
                                    onPressed: _canAuthorize
                                        ? _reauthorize
                                        : null,
                                    icon: const Icon(
                                      Icons.login_rounded,
                                      size: 16,
                                    ),
                                    label: Text(context.vio.t('重新授權私訊')),
                                  ),
                              ],
                            ),
                          ),
                        if (inbox.historyRecoveryNeeded &&
                            !widget.automaticSync)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                Text(
                                  context.vio.t('可能有未恢復的收件區間；連線不代表歷史已補齊。'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TwitchUiColors.textSecondary,
                                  ),
                                ),
                                if (!widget.automaticSync)
                                  TextButton(
                                    key: const ValueKey('whisper-gap-threads'),
                                    onPressed:
                                        inbox.threadsApi != null &&
                                            !inbox.loading &&
                                            !inbox.sending &&
                                            !inbox.managingHistory &&
                                            !inbox.syncingThreads &&
                                            !inbox.syncingHistory
                                        ? () => _historyAction('syncThreads')
                                        : null,
                                    child: Text(context.vio.t('同步對話列表')),
                                  ),
                                if (inbox.activeConversation != null &&
                                    !widget.automaticSync)
                                  TextButton(
                                    key: const ValueKey('whisper-gap-history'),
                                    onPressed:
                                        inbox.historyApi != null &&
                                            !inbox.loading &&
                                            !inbox.sending &&
                                            !inbox.managingHistory &&
                                            !inbox.syncingThreads &&
                                            !inbox.syncingHistory
                                        ? inbox.syncActiveHistory
                                        : null,
                                    child: Text(context.vio.t('同步此對話歷史')),
                                  ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 620;
                              if (wide) {
                                return Row(
                                  children: [
                                    SizedBox(
                                      width: 260,
                                      child: _conversationList(),
                                    ),
                                    const VerticalDivider(width: 1),
                                    Expanded(
                                      child: _conversation(
                                        peer,
                                        showBack: false,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return peer == null
                                  ? _conversationList()
                                  : _conversation(peer, showBack: true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );

  Widget _conversationList() {
    final query = _filter.text.trim().toLowerCase();
    final peers = inbox.conversations
        .where(
          (peer) =>
              peer.login.toLowerCase().contains(query) ||
              peer.displayName.toLowerCase().contains(query),
        )
        .toList();
    peers.sort((a, b) {
      if (_sort == 'name') {
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      }
      if (_sort == 'unread' && a.unreadCount != b.unreadCount) {
        return b.unreadCount.compareTo(a.unreadCount);
      }
      return (b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    });
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (widget.automaticSync &&
            notification.depth == 0 &&
            notification is ScrollUpdateNotification &&
            notification.scrollDelta != 0 &&
            notification.metrics.extentAfter < 160 &&
            !_openingSync &&
            !_historyAutoBusy &&
            !inbox.syncingThreads &&
            !inbox.syncingHistory &&
            !inbox.threadsComplete &&
            inbox.threadsError == null) {
          unawaited(inbox.syncThreads(more: true));
        }
        return false;
      },
      child: CustomScrollView(
        key: const PageStorageKey('whisper-conversation-list'),
        primary: false,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _filter,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.vio.t('搜尋對話'),
                  filled: true,
                  fillColor: TwitchUiColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed:
                          inbox.ownerId == null ||
                              inbox.searching ||
                              inbox.managingHistory
                          ? null
                          : _newConversation,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.vio.t('新增對話')),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: context.vio.t('對話排序'),
                    icon: const Icon(Icons.sort),
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'recent',
                        child: Text(context.vio.t('最近對話')),
                      ),
                      PopupMenuItem(
                        value: 'name',
                        child: Text(context.vio.t('依名字')),
                      ),
                      PopupMenuItem(
                        value: 'unread',
                        child: Text(context.vio.t('未讀優先')),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: context.vio.t('本機私訊歷史'),
                    enabled:
                        inbox.ownerId != null &&
                        !inbox.sending &&
                        !inbox.managingHistory &&
                        !inbox.syncingHistory &&
                        !inbox.syncingThreads,
                    icon: const Icon(Icons.more_vert),
                    onSelected: _historyAction,
                    itemBuilder: (_) => [
                      if (inbox.threadsApi != null &&
                          !widget.automaticSync) ...[
                        if (widget.onAuthorize != null)
                          PopupMenuItem(
                            value: 'authorizeSync',
                            enabled: _canAuthorize,
                            child: Text(context.vio.t('授權並重試對話同步')),
                          ),
                        PopupMenuItem(
                          value: 'syncThreads',
                          child: Text(context.vio.t('同步 Twitch 對話')),
                        ),
                        PopupMenuItem(
                          value: 'moreThreads',
                          enabled: !inbox.threadsComplete,
                          child: Text(context.vio.t('載入更多對話')),
                        ),
                        const PopupMenuDivider(),
                      ],
                      PopupMenuItem(
                        value: 'export',
                        child: Text(context.vio.t('複製私訊備份')),
                      ),
                      PopupMenuItem(
                        value: 'import',
                        child: Text(context.vio.t('匯入私訊備份')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if ((!inbox.syncingThreads && inbox.threadsError != null) ||
              (!widget.automaticSync &&
                  (inbox.syncingThreads || inbox.threadsStatus != null)))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.vio.t(
                        inbox.syncingThreads
                            ? '正在同步 Twitch 對話…'
                            : inbox.threadsError ?? inbox.threadsStatus!,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (inbox.canCancelThreadsSync)
                      TextButton(
                        onPressed: inbox.cancelThreadsSync,
                        child: Text(context.vio.t('取消對話同步')),
                      ),
                    if (inbox.threadsError != null && !inbox.syncingThreads)
                      TextButton(
                        onPressed: widget.automaticSync
                            ? _syncOnOpen
                            : inbox.retryThreadsSync,
                        child: Text(context.vio.t('重試對話同步')),
                      ),
                  ],
                ),
              ),
            ),
          if (peers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  context.vio.t(
                    query.isNotEmpty
                        ? '沒有符合搜尋的對話。'
                        : inbox.threadsApi == null
                        ? '尚無本機對話，點新增對話開始。'
                        : widget.automaticSync
                        ? '尚無對話，可新增對話開始。'
                        : '尚無本機對話，可從選單同步 Twitch 對話或新增對話。',
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: peers.length,
              itemBuilder: (context, index) {
                final peer = peers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    selectedTileColor: TwitchUiColors.primarySoft.withValues(
                      alpha: .14,
                    ),
                    tileColor: TwitchUiColors.surfaceAlt.withValues(alpha: .35),
                    selected: peer.userId == inbox.activePeerId,
                    leading: _avatar(peer),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            peer.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (peer.lastMessageAt != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _conversationTime(peer.lastMessageAt!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: TwitchUiColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      (peer.messages.isEmpty
                              ? context.vio.t('新對話')
                              : peer.messages.last.text) +
                          (peer.remoteUnreadCount > 0
                              ? '\n${context.vio.t('Twitch 未讀')} ${peer.remoteUnreadCount}（${context.vio.t('上次同步')}）'
                              : ''),
                      maxLines: peer.remoteUnreadCount > 0 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: peer.unreadCount > 0
                        ? Badge.count(count: peer.unreadCount)
                        : null,
                    onTap: () => inbox.selectConversation(peer.userId),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _conversationTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return TimeOfDay.fromDateTime(local).format(context);
    }
    return '${local.month}/${local.day}';
  }

  Widget _avatar(TwitchWhisperConversation peer) => CircleAvatar(
    radius: 18,
    child: peer.avatarUrl == null || peer.avatarUrl!.isEmpty
        ? const Icon(Icons.person_outline)
        : ClipOval(
            child: Image.network(
              peer.avatarUrl!,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
            ),
          ),
  );

  Widget _historyMenu(TwitchWhisperConversation peer) {
    if (inbox.historyApi == null ||
        (widget.automaticSync &&
            !(inbox.historyError != null &&
                inbox.historyPeerId == peer.userId))) {
      return const SizedBox.shrink();
    }
    final owner = inbox.ownerId;
    return PopupMenuButton<String>(
      tooltip: context.vio.t(
        widget.automaticSync || inbox.historyApi == null
            ? '對話操作'
            : '同步 Twitch 私訊歷史',
      ),
      enabled:
          !inbox.loading &&
          !inbox.managingHistory &&
          !inbox.syncingThreads &&
          (!inbox.syncingHistory || inbox.canCancelHistorySync),
      icon: Icon(
        widget.automaticSync &&
                inbox.historyError != null &&
                inbox.historyPeerId == peer.userId
            ? Icons.error_outline
            : widget.automaticSync || inbox.historyApi == null
            ? Icons.more_vert
            : Icons.history,
      ),
      itemBuilder: (_) => [
        if (widget.automaticSync &&
            inbox.historyError != null &&
            inbox.historyPeerId == peer.userId)
          PopupMenuItem(value: 'retry', child: Text(context.vio.t('重試歷史同步'))),
        if (inbox.historyApi != null && !widget.automaticSync) ...[
          if (inbox.canCancelHistorySync)
            PopupMenuItem(
              value: 'cancel',
              child: Text(context.vio.t('取消歷史同步')),
            ),
          if (!inbox.syncingHistory &&
              inbox.historyError != null &&
              inbox.historyPeerId == peer.userId)
            PopupMenuItem(value: 'retry', child: Text(context.vio.t('重試歷史同步'))),
          PopupMenuItem(
            value: 'recent',
            enabled: !inbox.syncingHistory,
            child: Text(context.vio.t('同步近期歷史')),
          ),
          PopupMenuItem(
            value: 'older',
            enabled: !peer.remoteHistoryComplete && !inbox.syncingHistory,
            child: Text(
              context.vio.t(peer.remoteHistoryComplete ? '已讀取更早歷史' : '載入更早訊息'),
            ),
          ),
        ],
      ],
      onSelected: (value) async {
        if (owner == null || inbox.ownerId != owner) return;
        if (value == 'cancel') {
          inbox.cancelHistorySync();
          return;
        }
        if (value == 'retry') {
          await inbox.retryHistorySync();
        } else {
          await inbox.syncActiveHistory(older: value == 'older');
        }
        if (mounted && inbox.historyError != null) {
          showTwitchNotice(
            context,
            inbox.historyError!,
            tone: TwitchNoticeTone.error,
          );
        }
      },
    );
  }

  Widget _conversation(
    TwitchWhisperConversation? peer, {
    required bool showBack,
    bool compact = false,
  }) {
    if (peer == null) return Center(child: Text(context.vio.t('選擇對話或新增對話')));
    final latestButton = TextButton.icon(
      onPressed: _jumpToLatest,
      icon: const Icon(Icons.arrow_downward, size: 16),
      label: Text(
        _latestCount > 0
            ? '${context.vio.t('新私訊')} · $_latestCount · ${context.vio.t('返回最新訊息')}'
            : context.vio.t('返回最新訊息'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final owner = inbox.ownerId;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (!compact)
            ListTile(
              leading: showBack
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: context.vio.t('返回對話列表'),
                      onPressed: () => inbox.selectConversation(null),
                    )
                  : _avatar(peer),
              title: Text(peer.displayName),
              subtitle: Text('@${peer.login}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [_historyMenu(peer)],
              ),
            ),
          if (!compact) const Divider(height: 1),
          if (!compact &&
              inbox.historyPeerId == peer.userId &&
              inbox.historyError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    inbox.historyError!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.automaticSync && inbox.historyError != null)
                    TextButton(
                      onPressed: inbox.syncingHistory
                          ? null
                          : inbox.retryHistorySync,
                      child: Text(context.vio.t('重試歷史同步')),
                    ),
                ],
              ),
            ),
          Expanded(
            key: const ValueKey('whisper-message-viewport'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                NotificationListener<ScrollMetricsNotification>(
                  onNotification: _onMetrics,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onUserScroll,
                    child: Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent &&
                            event.scrollDelta.dy != 0) {
                          _cancelLatestSeek();
                        }
                      },
                      onPointerPanZoomStart: (_) => _cancelLatestSeek(),
                      child: _messageScroll(peer),
                    ),
                  ),
                ),
                if (compact && (_latestCount > 0 || !inbox.readingLatest))
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 4,
                    child: Material(
                      color: TwitchUiColors.surfacePanel,
                      child: latestButton,
                    ),
                  ),
              ],
            ),
          ),
          if (!compact && (_latestCount > 0 || !inbox.readingLatest))
            latestButton,
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: context.vio.t('聊天表情'),
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  onPressed: inbox.loading || inbox.managingHistory
                      ? null
                      : () => _toggleEmotes(emojiOnly: false),
                ),
                Expanded(
                  child: TextField(
                    controller: _message,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !inbox.loading,
                    decoration: InputDecoration(
                      hintText: context.vio.t('私訊內容'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      counterText:
                          _message.text.length >= peer.messageLimit * .8
                          ? '${_message.text.length}/${peer.messageLimit}'
                          : '',
                      errorText: _message.text.length > peer.messageLimit
                          ? context.vio.t('內容超過目前私訊額度，草稿已保留；不會截短送出。')
                          : null,
                    ),
                    onChanged: (text) {
                      inbox.updateDraft(peer.userId, text);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed:
                      inbox.sending ||
                          inbox.loading ||
                          inbox.managingHistory ||
                          _message.text.trim().isEmpty ||
                          _message.text.length > peer.messageLimit
                      ? null
                      : inbox.sendActiveMessage,
                  tooltip: context.vio.t('傳送私訊'),
                  icon: inbox.sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
          if (_showEmotes)
            SizedBox(
              key: const ValueKey('whisper-emote-panel'),
              height: (constraints.maxHeight * .35).clamp(0.0, 260.0),
              child: _WhisperEmotePicker(
                key: ValueKey('emotes:$owner:${peer.userId}:$_emojiOnly'),
                inbox: inbox,
                emojiOnly: _emojiOnly,
                onClose: () => setState(() => _showEmotes = false),
                onEmoji: (emoji) {
                  if (inbox.ownerId == owner &&
                      inbox.activePeerId == peer.userId) {
                    _insertEmoji(emoji, inbox.activeConversation!);
                  }
                },
                onSelected: (emote) => _insertOfficialEmote(emote, peer, owner),
              ),
            ),
        ],
      ),
    );
  }

  Widget _messageScroll(TwitchWhisperConversation peer) {
    final messages = peer.displayMessages;
    var pivot = messages.indexWhere(
      (message) => message.id == _historyCenterId,
    );
    if (pivot < 0) {
      pivot = messages.length - 1;
      _historyCenterId = messages.lastOrNull?.id;
    }
    const center = ValueKey('whisper-history-center');
    Widget row(int index) => KeyedSubtree(
      key: index == messages.length - 1
          ? _lastBubbleKey
          : ValueKey(messages[index].id),
      child: _bubble(messages[index]),
    );
    return KeyedSubtree(
      key: ValueKey('whisper-peer-$_displayedPeer'),
      child: CustomScrollView(
        key: const ValueKey('whisper-message-list'),
        controller: _scroll,
        center: center,
        reverse: true,
        semanticChildCount: messages.length,
        physics: _WhisperDragRangePhysics(keepDragGap: () => _userDragging),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, index) => row(pivot + index + 1),
                childCount: messages.length - pivot - 1,
                semanticIndexOffset: pivot + 1,
              ),
            ),
          ),
          SliverPadding(
            key: center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, index) => row(pivot - index),
                childCount: pivot + 1,
                semanticIndexCallback: (_, index) => pivot - index,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(TwitchWhisperMessage message) {
    final outgoing = message.fromUserId == inbox.ownerId;
    final time = TimeOfDay.fromDateTime(
      message.timestamp.toLocal(),
    ).format(context);
    final state = switch (message.state) {
      TwitchWhisperMessageState.received => '',
      TwitchWhisperMessageState.sending => context.vio.t('發送中'),
      TwitchWhisperMessageState.submitted =>
        inbox.hasUnsavedSubmission(message)
            ? '${context.vio.t('已提交')} · ${context.vio.t('尚未儲存')}'
            : context.vio.t('已提交'),
      TwitchWhisperMessageState.failed => context.vio.t('發送失敗'),
      TwitchWhisperMessageState.unconfirmed => context.vio.t('送出結果未確認'),
    };
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: outgoing
                ? TwitchUiColors.primarySoft.withValues(alpha: .16)
                : TwitchUiColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: TwitchUiColors.textMuted.withValues(alpha: .12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _whisperBody(message.text),
              const SizedBox(height: 4),
              Text(
                '$time${state.isEmpty ? '' : ' · $state'}',
                style: TextStyle(
                  fontSize: 10,
                  color: message.state == TwitchWhisperMessageState.failed
                      ? Colors.redAccent
                      : TwitchUiColors.textMuted,
                ),
              ),
              if (inbox.emoteCatalog
                  .parse(message.text)
                  .any((part) => part.emote != null))
                IconButton(
                  tooltip: context.vio.t('複製原始訊息'),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: message.text)),
                  icon: const Icon(Icons.copy_rounded, size: 15),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whisperBody(String text) {
    final parts = inbox.emoteCatalog.parse(text);
    if (!parts.any((part) => part.emote != null)) return SelectableText(text);
    return SelectionArea(
      child: TwitchWhisperSelection(
        parts: parts,
        span: TextSpan(
          children: [
            for (final part in parts)
              if (part.emote == null)
                TextSpan(text: part.text)
              else
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: TwitchSelectableEmote(
                    text: part.text,
                    child: Tooltip(
                      message: part.text,
                      child: TwitchEmoteImage(
                        id: part.emote!.id,
                        name: part.text,
                        imageUrl: part.emote!.preferredImageUrl(),
                        staticImageUrl: part.emote!.officialStaticImageUrl(),
                        isOfficial: true,
                        isAnimated: part.emote!.supportsAnimation,
                        width: 28,
                        height: 28,
                        errorPlaceholder: Text(part.text),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// Preserve the user's distance from the end when a lazy list revises an
// overestimated end during an interrupted seek. Normal platform physics stay
// in control for viewport changes, ordinary scrolling and overscroll.
class _WhisperDragRangePhysics extends ScrollPhysics {
  final bool Function() keepDragGap;
  const _WhisperDragRangePhysics({required this.keepDragGap, super.parent});

  @override
  _WhisperDragRangePhysics applyTo(ScrollPhysics? ancestor) =>
      _WhisperDragRangePhysics(
        keepDragGap: keepDragGap,
        parent: buildParent(ancestor),
      );

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (keepDragGap() &&
        isScrolling &&
        oldPosition.viewportDimension == newPosition.viewportDimension &&
        newPosition.maxScrollExtent < oldPosition.maxScrollExtent &&
        newPosition.pixels > newPosition.maxScrollExtent &&
        oldPosition.pixels <= oldPosition.maxScrollExtent &&
        oldPosition.pixels >= oldPosition.minScrollExtent) {
      final gap = oldPosition.maxScrollExtent - newPosition.pixels;
      return (newPosition.maxScrollExtent - gap).clamp(
        newPosition.minScrollExtent,
        newPosition.maxScrollExtent,
      );
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}

class _WhisperEmotePicker extends StatefulWidget {
  final TwitchWhisperInboxController inbox;
  final bool emojiOnly;
  final VoidCallback onClose;
  final ValueChanged<String> onEmoji;
  final ValueChanged<TwitchOfficialEmote> onSelected;
  const _WhisperEmotePicker({
    super.key,
    required this.inbox,
    required this.emojiOnly,
    required this.onClose,
    required this.onEmoji,
    required this.onSelected,
  });
  @override
  State<_WhisperEmotePicker> createState() => _WhisperEmotePickerState();
}

class _WhisperEmotePickerState extends State<_WhisperEmotePicker> {
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.inbox,
    builder: (context, _) {
      final inbox = widget.inbox;
      return TwitchEmotePickerPanel(
        initialCategory: widget.emojiOnly ? 'emoji' : 'official',
        onClose: widget.onClose,
        loading: inbox.loadingEmotes,
        error: inbox.emoteError ?? inbox.emoteCatalog.userError,
        categories: [
          TwitchEmotePickerCategory(
            id: 'official',
            label: 'Twitch',
            count: inbox.emoteCatalog.emotes.length,
          ),
          TwitchEmotePickerCategory(
            id: 'emoji',
            label: context.vio.t('聊天表情'),
            count: twitchPickerEmoji.length,
          ),
        ],
        categoryBuilder: (context, id, query) {
          if (id == 'emoji') {
            return TwitchEmojiPicker(query: query, onSelected: widget.onEmoji);
          }
          final emotes = inbox.emoteCatalog.emotes
              .where((emote) => emote.name.toLowerCase().contains(query))
              .toList();
          if (emotes.isEmpty) {
            return Center(child: Text(context.vio.t('目前沒有可用的官方貼圖')));
          }
          return TwitchEmotePickerFlow(
            itemCount: emotes.length,
            itemBuilder: (context, index) {
              final emote = emotes[index];
              return TwitchEmotePickerTile(
                id: emote.id,
                name: emote.name,
                imageUrl: emote.preferredImageUrl(),
                staticImageUrl: emote.officialStaticImageUrl(),
                isOfficial: true,
                isAnimated: emote.supportsAnimation,
                locked: emote.locked,
                onTap: inbox.loadingEmotes || inbox.emoteError != null
                    ? null
                    : () => widget.onSelected(emote),
              );
            },
          );
        },
      );
    },
  );
}
