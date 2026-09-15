import './twitch_chat_message.dart';

enum TwitchChatFragmentType { text, twitchEmote, twitchGif, unknownEmote }

class TwitchChatFragment {
  final TwitchChatFragmentType type;
  final String text;
  final String? emoteId;
  final String? gifId;
  final String? imageUrl;
  final int? start;
  final int? end;

  const TwitchChatFragment({
    required this.type,
    required this.text,
    this.emoteId,
    this.gifId,
    this.imageUrl,
    this.start,
    this.end,
  });

  bool get isText => type == TwitchChatFragmentType.text;
  bool get isEmote => type == TwitchChatFragmentType.twitchEmote;
  bool get isGif => type == TwitchChatFragmentType.twitchGif;

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

  factory TwitchChatFragment.twitchGif({
    required String gifId,
    required String gifUrl,
    required String text,
    required int start,
    required int end,
  }) {
    return TwitchChatFragment(
      type: TwitchChatFragmentType.twitchGif,
      text: text,
      gifId: gifId,
      imageUrl: gifUrl,
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
      'gifId': gifId,
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
    final gifsTag = message.tags['gifs']?.trim() ?? '';

    final ranges = <_TwitchChatAssetRange>[
      ..._parseEmoteRanges(emotesTag),
      ..._parseGifRanges(gifsTag),
    ];

    if (ranges.isEmpty) {
      if (text.isEmpty) return const <TwitchChatFragment>[];
      return <TwitchChatFragment>[TwitchChatFragment.text(text)];
    }

    // recent-messages 或部分特殊訊息偶爾會出現 emotes tag 有資料，
    // 但 trailing text 是空的。此時至少把 emote id render 出來，避免 UI 空白。
    if (text.isEmpty) {
      return ranges
          .where((range) => !range.isGif)
          .map(
            (range) => TwitchChatFragment.unknownEmote(emoteId: range.assetId),
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

      final rangeText = text.substring(range.start, range.end + 1);
      if (range.isGif) {
        fragments.add(
          TwitchChatFragment.twitchGif(
            gifId: range.assetId,
            gifUrl: range.imageUrl ?? '',
            text: rangeText,
            start: range.start,
            end: range.end,
          ),
        );
      } else {
        fragments.add(
          TwitchChatFragment.twitchEmote(
            emoteId: range.assetId,
            text: rangeText,
            start: range.start,
            end: range.end,
          ),
        );
      }

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

  static List<_TwitchChatAssetRange> _parseEmoteRanges(String emotesTag) {
    final ranges = <_TwitchChatAssetRange>[];
    if (emotesTag.isEmpty) return ranges;

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

        ranges.add(
          _TwitchChatAssetRange(
            assetId: emoteId,
            start: start,
            end: end,
          ),
        );
      }
    }

    return ranges;
  }

  static List<_TwitchChatAssetRange> _parseGifRanges(String gifsTag) {
    final ranges = <_TwitchChatAssetRange>[];
    if (gifsTag.isEmpty) return ranges;

    // Twitch IRC (2026): comma-separated
    // <start>-<end>|<gifID>|<gifURL>, using inclusive message positions just
    // like the emotes tag. Keep the URL exactly as Twitch sends it.
    for (final entry in gifsTag.split(',')) {
      final firstPipe = entry.indexOf('|');
      if (firstPipe <= 0 || firstPipe >= entry.length - 1) continue;
      final secondPipe = entry.indexOf('|', firstPipe + 1);
      if (secondPipe <= firstPipe + 1 || secondPipe >= entry.length - 1) {
        continue;
      }

      final rangeText = entry.substring(0, firstPipe);
      final gifId = entry.substring(firstPipe + 1, secondPipe).trim();
      final gifUrl = entry.substring(secondPipe + 1).trim();
      final dashIndex = rangeText.indexOf('-');
      if (dashIndex <= 0 || dashIndex >= rangeText.length - 1) continue;

      final start = int.tryParse(rangeText.substring(0, dashIndex));
      final end = int.tryParse(rangeText.substring(dashIndex + 1));
      if (start == null || end == null || gifId.isEmpty || gifUrl.isEmpty) {
        continue;
      }

      ranges.add(
        _TwitchChatAssetRange(
          assetId: gifId,
          imageUrl: gifUrl,
          start: start,
          end: end,
          isGif: true,
        ),
      );
    }

    return ranges;
  }
}

class _TwitchChatAssetRange {
  final String assetId;
  final String? imageUrl;
  final int start;
  final int end;
  final bool isGif;

  const _TwitchChatAssetRange({
    required this.assetId,
    required this.start,
    required this.end,
    this.imageUrl,
    this.isGif = false,
  });
}
