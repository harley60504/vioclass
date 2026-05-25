import './twitch_chat_message.dart';

enum TwitchChatFragmentType { text, twitchEmote, unknownEmote }

class TwitchChatFragment {
  final TwitchChatFragmentType type;
  final String text;
  final String? emoteId;
  final String? imageUrl;
  final int? start;
  final int? end;

  const TwitchChatFragment({
    required this.type,
    required this.text,
    this.emoteId,
    this.imageUrl,
    this.start,
    this.end,
  });

  bool get isText => type == TwitchChatFragmentType.text;
  bool get isEmote => type == TwitchChatFragmentType.twitchEmote;

  factory TwitchChatFragment.text(String text) {
    return TwitchChatFragment(type: TwitchChatFragmentType.text, text: text);
  }

  factory TwitchChatFragment.twitchEmote({
    required String emoteId,
    required String text,
    required int start,
    required int end,
  }) {
    return TwitchChatFragment(
      type: TwitchChatFragmentType.twitchEmote,
      text: text,
      emoteId: emoteId,
      imageUrl: twitchEmoteImageUrl(emoteId),
      start: start,
      end: end,
    );
  }

  factory TwitchChatFragment.unknownEmote({required String emoteId}) {
    return TwitchChatFragment(
      type: TwitchChatFragmentType.unknownEmote,
      text: '',
      emoteId: emoteId,
      imageUrl: twitchEmoteImageUrl(emoteId),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.name,
      'text': text,
      'emoteId': emoteId,
      'imageUrl': imageUrl,
      'start': start,
      'end': end,
    };
  }

  static String twitchEmoteImageUrl(String emoteId, {String scale = '1.0'}) {
    return 'https://static-cdn.jtvnw.net/emoticons/v2/$emoteId/default/dark/$scale';
  }

  static List<TwitchChatFragment> buildFromMessage(TwitchChatMessage message) {
    final text = message.message;
    final emotesTag = message.tags['emotes']?.trim() ?? '';

    if (emotesTag.isEmpty) {
      if (text.isEmpty) return const <TwitchChatFragment>[];
      return <TwitchChatFragment>[TwitchChatFragment.text(text)];
    }

    final ranges = _parseEmoteRanges(emotesTag);

    if (ranges.isEmpty) {
      if (text.isEmpty) return const <TwitchChatFragment>[];
      return <TwitchChatFragment>[TwitchChatFragment.text(text)];
    }

    // recent-messages 或部分特殊訊息偶爾會出現 emotes tag 有資料，
    // 但 trailing text 是空的。此時至少把 emote id render 出來，避免 UI 空白。
    if (text.isEmpty) {
      return ranges
          .map(
            (range) => TwitchChatFragment.unknownEmote(emoteId: range.emoteId),
          )
          .toList(growable: false);
    }

    final sortedRanges = ranges.toList()
      ..sort((a, b) {
        final compareStart = a.start.compareTo(b.start);
        if (compareStart != 0) return compareStart;
        return a.end.compareTo(b.end);
      });

    final fragments = <TwitchChatFragment>[];
    var cursor = 0;

    for (final range in sortedRanges) {
      if (range.start < cursor) continue;
      if (range.start < 0 || range.end < range.start) continue;
      if (range.end >= text.length) continue;

      if (range.start > cursor) {
        fragments.add(
          TwitchChatFragment.text(text.substring(cursor, range.start)),
        );
      }

      fragments.add(
        TwitchChatFragment.twitchEmote(
          emoteId: range.emoteId,
          text: text.substring(range.start, range.end + 1),
          start: range.start,
          end: range.end,
        ),
      );

      cursor = range.end + 1;
    }

    if (cursor < text.length) {
      fragments.add(TwitchChatFragment.text(text.substring(cursor)));
    }

    if (fragments.isEmpty && text.isNotEmpty) {
      fragments.add(TwitchChatFragment.text(text));
    }

    return fragments;
  }

  static List<_TwitchEmoteRange> _parseEmoteRanges(String emotesTag) {
    final ranges = <_TwitchEmoteRange>[];

    for (final group in emotesTag.split('/')) {
      if (group.trim().isEmpty) continue;

      final colonIndex = group.indexOf(':');
      if (colonIndex <= 0 || colonIndex >= group.length - 1) continue;

      final emoteId = group.substring(0, colonIndex);
      final rangeText = group.substring(colonIndex + 1);

      for (final range in rangeText.split(',')) {
        final dashIndex = range.indexOf('-');
        if (dashIndex <= 0 || dashIndex >= range.length - 1) continue;

        final start = int.tryParse(range.substring(0, dashIndex));
        final end = int.tryParse(range.substring(dashIndex + 1));

        if (start == null || end == null) continue;

        ranges.add(_TwitchEmoteRange(emoteId: emoteId, start: start, end: end));
      }
    }

    return ranges;
  }
}

class _TwitchEmoteRange {
  final String emoteId;
  final int start;
  final int end;

  const _TwitchEmoteRange({
    required this.emoteId,
    required this.start,
    required this.end,
  });
}
