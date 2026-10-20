import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';

import '../shared/twitch_emote_image.dart';
import 'twitch_chat_input_emote_state.dart';

/// Renders known codes without changing controller text, drafts or IME ranges.
class TwitchInputEmoteSpanBuilder extends SpecialTextSpanBuilder {
  final TextEditingController controller;
  final TwitchChatInputEmote? Function(String)? resolve;
  final double emoteSize;

  TwitchInputEmoteSpanBuilder({
    required this.controller,
    this.resolve,
    this.emoteSize = 20,
  });

  @override
  TextSpan build(
    String data, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
  }) {
    final value = controller.value;
    var sourceStart = 0;
    var fullSource = data;
    if (data != value.text && value.composing.isValid) {
      final before = value.composing.textBefore(value.text);
      final after = value.composing.textAfter(value.text);
      if (data == before || data == after) fullSource = value.text;
      if (data == after && data != before) sourceStart = value.composing.end;
    }
    final style = textStyle ?? const TextStyle();
    final spans = <InlineSpan>[];
    for (final match in RegExp(r'\s+|\S+').allMatches(data)) {
      final token = match.group(0)!;
      final start = sourceStart + match.start;
      final end = start + token.length;
      final completeToken =
          (start == 0 || RegExp(r'\s').hasMatch(fullSource[start - 1])) &&
          (end == fullSource.length || RegExp(r'\s').hasMatch(fullSource[end]));
      final composing =
          fullSource == value.text &&
          value.composing.isValid &&
          !value.composing.isCollapsed &&
          start < value.composing.end &&
          end > value.composing.start;
      final emote = completeToken && !composing ? resolve?.call(token) : null;
      if (emote == null) {
        spans.add(
          TwitchChatInputEmoteState.buildTextSpanForSource(
            controller,
            token,
            style,
            sourceStart: start,
            emoteSize: emoteSize,
          ),
        );
      } else {
        spans.add(
          ExtendedWidgetSpan(
            actualText: token,
            start: start,
            alignment: PlaceholderAlignment.middle,
            child: TwitchEmoteImage(
              id: emote.id,
              name: emote.name,
              imageUrl: emote.imageUrl,
              staticImageUrl: emote.staticImageUrl,
              providerLabel: emote.providerLabel,
              isOfficial: emote.isOfficial,
              isAnimated: emote.isAnimated,
              width: emoteSize,
              height: emoteSize,
              errorPlaceholder: Text(token, style: style),
            ),
          ),
        );
      }
    }
    return TextSpan(style: style, children: spans);
  }

  @override
  SpecialText? createSpecialText(
    String flag, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
    required int index,
  }) => null;
}
