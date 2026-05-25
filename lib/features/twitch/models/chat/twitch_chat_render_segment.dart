import './twitch_chat_fragment.dart';
import './twitch_chat_message.dart';

enum TwitchChatRenderSegmentType { text, twitchEmote, link, emoji, cheermote }

class TwitchChatRenderSegment {
  final TwitchChatRenderSegmentType type;
  final String content;
  final String? url;
  final String? emoteId;
  final bool isZeroWidth;
  final int? bitsAmount;

  const TwitchChatRenderSegment({
    required this.type,
    required this.content,
    this.url,
    this.emoteId,
    this.isZeroWidth = false,
    this.bitsAmount,
  });

  bool get isText => type == TwitchChatRenderSegmentType.text;
  bool get isEmote => type == TwitchChatRenderSegmentType.twitchEmote;
  bool get isLink => type == TwitchChatRenderSegmentType.link;

  factory TwitchChatRenderSegment.text(String content) {
    return TwitchChatRenderSegment(
      type: TwitchChatRenderSegmentType.text,
      content: content,
    );
  }

  factory TwitchChatRenderSegment.link(String content) {
    return TwitchChatRenderSegment(
      type: TwitchChatRenderSegmentType.link,
      content: content,
      url: content,
    );
  }

  factory TwitchChatRenderSegment.twitchEmote({
    required String content,
    required String emoteId,
    required String url,
  }) {
    return TwitchChatRenderSegment(
      type: TwitchChatRenderSegmentType.twitchEmote,
      content: content,
      emoteId: emoteId,
      url: url,
    );
  }

  factory TwitchChatRenderSegment.cheermote({
    required String content,
    required int bitsAmount,
  }) {
    return TwitchChatRenderSegment(
      type: TwitchChatRenderSegmentType.cheermote,
      content: content,
      bitsAmount: bitsAmount,
    );
  }

  static List<TwitchChatRenderSegment> buildFromMessage(
    TwitchChatMessage message,
    List<TwitchChatFragment> fragments,
  ) {
    final output = <TwitchChatRenderSegment>[];

    for (final fragment in fragments) {
      if (fragment.isText) {
        output.addAll(_splitTextSegment(fragment.text));
      } else if (fragment.isEmote) {
        final imageUrl = fragment.imageUrl;
        final emoteId = fragment.emoteId;

        if (imageUrl != null &&
            imageUrl.isNotEmpty &&
            emoteId != null &&
            emoteId.isNotEmpty) {
          output.add(
            TwitchChatRenderSegment.twitchEmote(
              content: fragment.text,
              emoteId: emoteId,
              url: imageUrl,
            ),
          );
        } else if (fragment.text.isNotEmpty) {
          output.add(TwitchChatRenderSegment.text(fragment.text));
        }
      } else {
        final imageUrl = fragment.imageUrl;
        final emoteId = fragment.emoteId;

        if (imageUrl != null &&
            imageUrl.isNotEmpty &&
            emoteId != null &&
            emoteId.isNotEmpty) {
          output.add(
            TwitchChatRenderSegment.twitchEmote(
              content: fragment.text.isEmpty ? emoteId : fragment.text,
              emoteId: emoteId,
              url: imageUrl,
            ),
          );
        }
      }
    }

    if (output.isEmpty && message.message.isNotEmpty) {
      output.addAll(_splitTextSegment(message.message));
    }

    return output;
  }

  static List<TwitchChatRenderSegment> _splitTextSegment(String text) {
    if (text.isEmpty) return const <TwitchChatRenderSegment>[];

    final output = <TwitchChatRenderSegment>[];
    final linkRegex = RegExp(
      r'(https?:\/\/[^\s]+|www\.[^\s]+)',
      caseSensitive: false,
    );
    var cursor = 0;

    for (final match in linkRegex.allMatches(text)) {
      if (match.start > cursor) {
        output.add(
          TwitchChatRenderSegment.text(text.substring(cursor, match.start)),
        );
      }

      output.add(TwitchChatRenderSegment.link(match.group(0)!));
      cursor = match.end;
    }

    if (cursor < text.length) {
      output.add(TwitchChatRenderSegment.text(text.substring(cursor)));
    }

    if (output.isEmpty) {
      output.add(TwitchChatRenderSegment.text(text));
    }

    return output;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.name,
      'content': content,
      'url': url,
      'emoteId': emoteId,
      'isZeroWidth': isZeroWidth,
      'bitsAmount': bitsAmount,
    };
  }
}
