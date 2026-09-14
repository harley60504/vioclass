import 'dart:async';

import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';

import '../../localization/vioclass_localizations.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../shared/twitch_notice.dart';
import '../shared/twitch_text_field.dart';
import 'twitch_chat_composer_button_style.dart';
import 'twitch_chat_input_emote_state.dart';
import 'twitch_chat_text_style.dart';

class TwitchChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final String? hintText;
  final Color? hintColor;
  final Widget? leadingActions;
  final FutureOr<void> Function() onSend;

  const TwitchChatInputBar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.sending,
    this.hintText,
    this.hintColor,
    this.leadingActions,
    required this.onSend,
  });

  static const double _inputRowHeight = 48;
  static const double _inputFontSize = 13;
  static const double _inputLineHeight = 1.20;

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
      padding: const EdgeInsets.fromLTRB(
        TwitchUiSpacing.space12,
        TwitchUiSpacing.space4,
        TwitchUiSpacing.space12,
        TwitchUiSpacing.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SelfDrawnInputField(
            height: rowHeight,
            controller: controller,
            enabled: enabled && !sending,
            fontSize: fontSize,
            lineHeight: _inputLineHeight,
            verticalPadding: _inputVerticalPadding,
            hintText: hintText,
            hintColor: hintColor,
            onSubmit: () => unawaited(_submitIfPossible(context)),
          ),
          const SizedBox(height: TwitchUiSpacing.space8),
          Row(
            children: [
              Expanded(child: leadingActions ?? const SizedBox.shrink()),
              const SizedBox(width: TwitchUiSpacing.space8),
              _SelfDrawnSendButton(
                enabled: enabled && !sending,
                sending: sending,
                onTap: () => unawaited(_submitIfPossible(context)),
              ),
            ],
          ),
        ],
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
  final String? hintText;
  final Color? hintColor;
  final VoidCallback onSubmit;

  const _SelfDrawnInputField({
    required this.height,
    required this.controller,
    required this.enabled,
    required this.fontSize,
    required this.lineHeight,
    required this.verticalPadding,
    required this.hintText,
    required this.hintColor,
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
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(TwitchUiRadius.md),
      borderSide: BorderSide(
        color: enabled ? TwitchUiColors.border : TwitchUiColors.borderSubtle,
      ),
    );

    return TwitchTextField(
      height: height,
      controller: controller,
      enabled: enabled,
      maxLines: 1,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onSubmit(),
      style: textStyle,
      strutStyle: StrutStyle(
        fontSize: fontSize,
        height: lineHeight,
        forceStrutHeight: true,
      ),
      specialTextSpanBuilder: _ChatInputSpanBuilder(
        controller: controller,
        emoteSize: fontSize * 1.45,
      ),
      selectionControls: materialTextSelectionControls,
      decoration: InputDecoration(
        constraints: BoxConstraints.tightFor(height: height),
        hintText: hintText?.trim().isNotEmpty == true
            ? hintText
            : l10n.t('輸入聊天室訊息...'),
        hintStyle: textStyle.copyWith(
          color: hintColor ?? TwitchUiColors.textMuted,
        ),
        filled: true,
        fillColor: TwitchUiColors.surfaceInteractive,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: TwitchUiColors.primarySoft),
        ),
        disabledBorder: border.copyWith(
          borderSide: const BorderSide(color: TwitchUiColors.borderSubtle),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: TwitchUiSpacing.space12,
          vertical: verticalPadding,
        ),
      ),
    );
  }
}

class _ChatInputSpanBuilder extends SpecialTextSpanBuilder {
  final TextEditingController controller;
  final double emoteSize;

  _ChatInputSpanBuilder({required this.controller, required this.emoteSize});

  @override
  TextSpan build(
    String data, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
  }) {
    final value = controller.value;
    var sourceStart = 0;
    if (data != value.text && value.composing.isValid) {
      final before = value.composing.textBefore(value.text);
      final after = value.composing.textAfter(value.text);
      if (data == after && data != before) {
        sourceStart = value.composing.end;
      }
    }
    return TwitchChatInputEmoteState.buildTextSpanForSource(
      controller,
      data,
      textStyle ?? const TextStyle(),
      sourceStart: sourceStart,
      emoteSize: emoteSize,
    );
  }

  @override
  SpecialText? createSpecialText(
    String flag, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
    required int index,
  }) {
    return null;
  }
}

class _SelfDrawnSendButton extends StatelessWidget {
  final bool enabled;
  final bool sending;
  final VoidCallback onTap;

  const _SelfDrawnSendButton({
    required this.enabled,
    required this.sending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      style: twitchChatComposerButtonStyle(enabled: enabled, emphasized: true),
      icon: SizedBox.square(
        dimension: 16,
        child: Center(
          child: sending
              ? SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: enabled
                        ? TwitchUiColors.textOnAccent
                        : TwitchUiColors.disabledForeground,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 16),
        ),
      ),
    );
  }
}
