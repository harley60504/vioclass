import 'dart:async';

import 'package:flutter/material.dart';

import '../../localization/vioclass_localizations.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../shared/twitch_notice.dart';
import 'twitch_chat_input_emote_state.dart';
import 'twitch_chat_text_style.dart';

class TwitchChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final bool compact;
  final FutureOr<void> Function() onSend;
  final VoidCallback onOpenEmotes;

  const TwitchChatInputBar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.compact,
    required this.onSend,
    required this.onOpenEmotes,
  });

  static const double _normalInputRowHeight = 40;
  static const double _compactInputRowHeight = 36;
  static const double _normalInputFontSize = 14;
  static const double _compactInputFontSize = 13;
  static const double _inputLineHeight = 1.20;

  double get _inputRowHeight =>
      compact ? _compactInputRowHeight : _normalInputRowHeight;
  double get _inputFontSize =>
      compact ? _compactInputFontSize : _normalInputFontSize;
  double get _inputVerticalPadding =>
      (_inputRowHeight - _inputFontSize * _inputLineHeight) / 2;

  Future<void> _submitIfPossible(BuildContext context) async {
    if (!enabled ||
        sending ||
        TwitchChatInputEmoteState.serialize(controller).trim().isEmpty) {
      return;
    }
    try {
      await Future<void>.sync(onSend);
    } catch (error, stackTrace) {
      debugPrint('Twitch chat send failed: $error');
      debugPrint('$stackTrace');
      if (!context.mounted) return;
      final message = _formatSendError(error);
      if (message.isEmpty) return;
      showTwitchNotice(
        context,
        message,
        tone: TwitchNoticeTone.error,
        duration: const Duration(seconds: 3),
      );
    }
  }

  String _formatSendError(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return '聊天室訊息送出失敗';
    return raw
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
        .replaceFirst(RegExp(r'^StateError:\s*'), '')
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight = _inputRowHeight;
    final fontSize = _inputFontSize;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        TwitchUiSpacing.space12,
        compact ? TwitchUiSpacing.space4 : TwitchUiSpacing.space8,
        TwitchUiSpacing.space12,
        compact ? TwitchUiSpacing.space8 : TwitchUiSpacing.space12,
      ),
      child: SizedBox(
        height: rowHeight,
        child: Row(
          children: [
            _InputActionButton(
              height: rowHeight,
              tooltip: context.vio.t('表情符號'),
              icon: Icons.emoji_emotions_outlined,
              enabled: enabled && !sending,
              onTap: onOpenEmotes,
            ),
            const SizedBox(width: TwitchUiSpacing.space8),
            Expanded(
              child: _SelfDrawnInputField(
                height: rowHeight,
                controller: controller,
                enabled: enabled && !sending,
                fontSize: fontSize,
                lineHeight: _inputLineHeight,
                verticalPadding: _inputVerticalPadding,
                onSubmit: () => unawaited(_submitIfPossible(context)),
              ),
            ),
            const SizedBox(width: TwitchUiSpacing.space8),
            _SelfDrawnSendButton(
              height: rowHeight,
              minWidth: compact ? rowHeight : 86,
              compact: compact,
              enabled: enabled && !sending,
              sending: sending,
              onTap: () => unawaited(_submitIfPossible(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputActionButton extends StatelessWidget {
  final double height;
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _InputActionButton({
    required this.height,
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: height,
        height: height,
        child: IconButton(
          onPressed: enabled ? onTap : null,
          icon: Icon(icon, size: 19),
          style: IconButton.styleFrom(
            backgroundColor: TwitchUiColors.surfaceInteractive,
            foregroundColor: TwitchUiColors.textSecondary,
            disabledForegroundColor: TwitchUiColors.disabledForeground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TwitchUiRadius.md),
              side: const BorderSide(color: TwitchUiColors.borderSubtle),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelfDrawnInputField extends StatelessWidget {
  final double height;
  final TextEditingController controller;
  final bool enabled;
  final double fontSize;
  final double lineHeight;
  final double verticalPadding;
  final VoidCallback onSubmit;

  const _SelfDrawnInputField({
    required this.height,
    required this.controller,
    required this.enabled,
    required this.fontSize,
    required this.lineHeight,
    required this.verticalPadding,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final textStyle = twitchChatTextStyle(
      TextStyle(
        color: enabled
            ? TwitchUiColors.textPrimary
            : TwitchUiColors.disabledForeground,
        fontSize: fontSize,
        height: lineHeight,
        fontWeight: TwitchUiFontWeight.regular,
      ),
    );
    final transparentInputStyle = textStyle.copyWith(
      color: Colors.transparent,
      decorationColor: Colors.transparent,
    );

    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TwitchUiColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(TwitchUiRadius.md),
        border: Border.all(
          color: enabled ? TwitchUiColors.border : TwitchUiColors.borderSubtle,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: TwitchUiSpacing.space12,
                vertical: verticalPadding,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    return RichText(
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      strutStyle: StrutStyle(
                        fontSize: fontSize,
                        height: lineHeight,
                        forceStrutHeight: true,
                      ),
                      text: TwitchChatInputEmoteState.buildTextSpan(
                        controller,
                        textStyle,
                        emoteSize: fontSize * 1.45,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          TextField(
            controller: controller,
            enabled: enabled,
            maxLines: 1,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSubmit(),
            textAlignVertical: TextAlignVertical.center,
            style: transparentInputStyle,
            strutStyle: StrutStyle(
              fontSize: fontSize,
              height: lineHeight,
              forceStrutHeight: true,
            ),
            cursorColor: TwitchUiColors.primarySoft,
            selectionControls: materialTextSelectionControls,
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              hintText: l10n.t('輸入聊天室訊息...'),
              hintStyle: textStyle.copyWith(color: TwitchUiColors.textMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: TwitchUiSpacing.space12,
                vertical: verticalPadding,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelfDrawnSendButton extends StatelessWidget {
  final double height;
  final double minWidth;
  final bool compact;
  final bool enabled;
  final bool sending;
  final VoidCallback onTap;

  const _SelfDrawnSendButton({
    required this.height,
    required this.minWidth,
    required this.compact,
    required this.enabled,
    required this.sending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? TwitchUiColors.textOnAccent
        : TwitchUiColors.disabledForeground;
    return Material(
      color: enabled ? TwitchUiColors.primary : TwitchUiColors.surfaceInteractive,
      borderRadius: BorderRadius.circular(TwitchUiRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: height,
          constraints: BoxConstraints(minWidth: minWidth),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? TwitchUiSpacing.space8 : TwitchUiSpacing.space12,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TwitchUiRadius.md),
            border: Border.all(
              color: enabled
                  ? TwitchUiColors.primarySoft.withValues(alpha: 0.34)
                  : TwitchUiColors.borderSubtle,
            ),
          ),
          child: sending
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send_rounded, size: compact ? 16 : 17, color: foreground),
                    if (!compact) ...[
                      const SizedBox(width: TwitchUiSpacing.space8),
                      Text(
                        context.vio.t('送出'),
                        style: twitchChatTextStyle(
                          TextStyle(
                            color: foreground,
                            fontSize: TwitchUiFontSize.bodyCompact,
                            fontWeight: TwitchUiFontWeight.strong,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
