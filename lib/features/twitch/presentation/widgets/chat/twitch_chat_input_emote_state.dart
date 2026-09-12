import 'dart:convert';

import 'package:flutter/material.dart';

import '../shared/twitch_emote_image.dart';

class TwitchChatInputEmote {
  final String id;
  final String name;
  final String imageUrl;
  final String staticImageUrl;
  final String providerLabel;
  final bool isOfficial;
  final bool isAnimated;

  const TwitchChatInputEmote({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.staticImageUrl = '',
    this.providerLabel = '',
    this.isOfficial = false,
    this.isAnimated = false,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'staticImageUrl': staticImageUrl,
    'providerLabel': providerLabel,
    'isOfficial': isOfficial,
    'isAnimated': isAnimated,
  };

  factory TwitchChatInputEmote.fromJson(Map<String, dynamic> json) {
    return TwitchChatInputEmote(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      staticImageUrl: json['staticImageUrl']?.toString() ?? '',
      providerLabel: json['providerLabel']?.toString() ?? '',
      isOfficial: json['isOfficial'] == true,
      isAnimated: json['isAnimated'] == true,
    );
  }
}

class TwitchChatInputEmotePayload {
  static const String _prefix = '\u{E000}vioclass-emote:';

  static String encode(TwitchChatInputEmote emote) {
    final raw = jsonEncode(emote.toJson());
    return '$_prefix${base64Url.encode(utf8.encode(raw))}';
  }

  static TwitchChatInputEmote? tryDecode(String value) {
    if (!value.startsWith(_prefix)) return null;
    try {
      final encoded = value.substring(_prefix.length);
      final raw = utf8.decode(base64Url.decode(encoded));
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final emote = TwitchChatInputEmote.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return emote.name.trim().isEmpty ? null : emote;
    } catch (_) {
      return null;
    }
  }
}

class TwitchChatInputEmoteState {
  static const String placeholder = '\uFFFC';
  static final Expando<_InputControllerState> _states =
      Expando<_InputControllerState>('twitch-chat-input-emotes');

  static void insert(
    TextEditingController controller,
    TwitchChatInputEmote emote, {
    bool appendSpace = true,
  }) {
    final state = _state(controller);
    _reconcile(controller, state);

    final current = controller.value;
    final text = current.text;
    final selection = current.selection;
    final rawStart = selection.start < 0 ? text.length : selection.start;
    final rawEnd = selection.end < 0 ? text.length : selection.end;
    final start = rawStart > text.length ? text.length : rawStart;
    final end = rawEnd < start
        ? start
        : (rawEnd > text.length ? text.length : rawEnd);
    final replacement = '$placeholder${appendSpace ? ' ' : ''}';
    final delta = replacement.length - (end - start);

    final nextMarkers = <_InputEmoteMarker>[];
    for (final marker in state.markers) {
      if (marker.offset < start) {
        nextMarkers.add(marker);
      } else if (marker.offset >= end) {
        nextMarkers.add(marker.copyWith(offset: marker.offset + delta));
      }
    }
    nextMarkers.add(_InputEmoteMarker(offset: start, emote: emote));
    nextMarkers.sort((a, b) => a.offset.compareTo(b.offset));

    final nextText = text.replaceRange(start, end, replacement);
    state
      ..markers = nextMarkers
      ..lastText = nextText;

    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
      composing: TextRange.empty,
    );
  }

  static String serialize(TextEditingController controller) {
    final state = _state(controller);
    _reconcile(controller, state);
    final text = controller.text;
    if (state.markers.isEmpty) return text;

    final buffer = StringBuffer();
    var cursor = 0;
    for (final marker in state.markers) {
      if (marker.offset < cursor || marker.offset >= text.length) continue;
      if (text[marker.offset] != placeholder) continue;
      buffer.write(text.substring(cursor, marker.offset));
      buffer.write(marker.emote.name);
      cursor = marker.offset + placeholder.length;
    }
    buffer.write(text.substring(cursor));
    return buffer.toString();
  }

  static TextSpan buildTextSpan(
    TextEditingController controller,
    TextStyle style, {
    double emoteSize = 20,
  }) {
    final state = _state(controller);
    _reconcile(controller, state);
    final text = controller.text;
    if (state.markers.isEmpty) return TextSpan(text: text, style: style);

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final marker in state.markers) {
      if (marker.offset < cursor || marker.offset >= text.length) continue;
      if (text[marker.offset] != placeholder) continue;
      if (marker.offset > cursor) {
        children.add(TextSpan(text: text.substring(cursor, marker.offset)));
      }
      final emote = marker.emote;
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: SizedBox(
              width: emoteSize,
              height: emoteSize,
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
                fit: BoxFit.contain,
                memCacheWidth: 64,
                memCacheHeight: 64,
                placeholder: SizedBox(width: emoteSize, height: emoteSize),
                errorPlaceholder: Icon(
                  Icons.broken_image_rounded,
                  size: emoteSize * 0.72,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        ),
      );
      cursor = marker.offset + placeholder.length;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }

  static _InputControllerState _state(TextEditingController controller) {
    return _states[controller] ??= _InputControllerState(lastText: controller.text);
  }

  static void _reconcile(
    TextEditingController controller,
    _InputControllerState state,
  ) {
    final oldText = state.lastText;
    final newText = controller.text;
    if (oldText == newText) return;

    var prefix = 0;
    final minLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < minLength && oldText[prefix] == newText[prefix]) {
      prefix++;
    }

    var suffix = 0;
    while (
        suffix < oldText.length - prefix &&
        suffix < newText.length - prefix &&
        oldText[oldText.length - 1 - suffix] ==
            newText[newText.length - 1 - suffix]) {
      suffix++;
    }

    final oldChangedEnd = oldText.length - suffix;
    final newChangedEnd = newText.length - suffix;
    final delta = newChangedEnd - oldChangedEnd;
    final nextMarkers = <_InputEmoteMarker>[];

    for (final marker in state.markers) {
      if (marker.offset < prefix) {
        nextMarkers.add(marker);
      } else if (marker.offset >= oldChangedEnd) {
        nextMarkers.add(marker.copyWith(offset: marker.offset + delta));
      }
    }

    state
      ..markers = nextMarkers
      ..lastText = newText;
  }
}

class _InputControllerState {
  String lastText;
  List<_InputEmoteMarker> markers;

  _InputControllerState({
    required this.lastText,
    this.markers = const <_InputEmoteMarker>[],
  });
}

class _InputEmoteMarker {
  final int offset;
  final TwitchChatInputEmote emote;

  const _InputEmoteMarker({required this.offset, required this.emote});

  _InputEmoteMarker copyWith({int? offset}) {
    return _InputEmoteMarker(offset: offset ?? this.offset, emote: emote);
  }
}
