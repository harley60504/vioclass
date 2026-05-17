// PATCH VERSION: twitch_chat_input_bar_stage191_unified_glass

import 'package:flutter/material.dart';

class TwitchChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final bool compact;
  final VoidCallback onSend;
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

  static const double _normalInputRowHeight = 38.0;
  static const double _compactInputRowHeight = 34.0;
  static const double _normalInputFontSize = 14.0;
  static const double _compactInputFontSize = 13.0;
  static const double _inputLineHeight = 1.20;

  double get _inputRowHeight =>
      compact ? _compactInputRowHeight : _normalInputRowHeight;

  double get _inputFontSize =>
      compact ? _compactInputFontSize : _normalInputFontSize;

  double get _inputVerticalPadding =>
      (_inputRowHeight - _inputFontSize * _inputLineHeight) / 2;

  void _submitIfPossible() {
    if (enabled && !sending && controller.text.trim().isNotEmpty) {
      onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight = _inputRowHeight;
    final fontSize = _inputFontSize;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, compact ? 6 : 7, 10, compact ? 8 : 9),
      child: SizedBox(
        height: rowHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _SelfDrawnInputField(
                height: rowHeight,
                controller: controller,
                enabled: enabled && !sending,
                fontSize: fontSize,
                lineHeight: _inputLineHeight,
                verticalPadding: _inputVerticalPadding,
                onSubmit: _submitIfPossible,
              ),
            ),
            const SizedBox(width: 10),
            _SelfDrawnSendButton(
              height: rowHeight,
              minWidth: compact ? rowHeight : 98,
              compact: compact,
              enabled: enabled && !sending,
              sending: sending,
              onTap: _submitIfPossible,
            ),
          ],
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
    final textStyle = TextStyle(
      color: enabled ? Colors.white : Colors.white38,
      fontSize: fontSize,
      height: lineHeight,
      fontWeight: FontWeight.w700,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: enabled ? () => FocusScope.of(context).requestFocus() : null,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.060),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: enabled
                ? const Color(0xFFBF94FF).withOpacity(0.22)
                : Colors.white.withOpacity(0.065),
          ),
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF9146FF).withOpacity(0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: TextField(
          controller: controller,
          enabled: enabled,
          maxLines: 1,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => onSubmit(),
          textAlignVertical: TextAlignVertical.center,
          style: textStyle,
          strutStyle: StrutStyle(
            fontSize: fontSize,
            height: lineHeight,
            forceStrutHeight: true,
          ),
          cursorColor: const Color(0xFFBF94FF),
          decoration: InputDecoration(
            isCollapsed: true,
            hintText: '輸入聊天室訊息...',
            hintStyle: textStyle.copyWith(color: Colors.white38),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 13,
              vertical: verticalPadding,
            ),
          ),
        ),
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
    final foreground = enabled ? Colors.white : Colors.white38;
    final background = enabled
        ? const Color(0xFF9146FF).withOpacity(0.38)
        : Colors.white.withOpacity(0.070);
    final borderColor = enabled
        ? const Color(0xFFBF94FF).withOpacity(0.46)
        : Colors.white.withOpacity(0.085);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Container(
          height: height,
          constraints: BoxConstraints(minWidth: minWidth),
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF9146FF).withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: sending
              ? SizedBox(
                  width: compact ? 13 : 14,
                  height: compact ? 13 : 14,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: compact ? 16 : 18, color: foreground),
                    if (!compact) ...[
                      const SizedBox(width: 7),
                      Text(
                        'Send',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 14,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
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
