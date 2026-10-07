import 'package:flutter/material.dart';

import '../../../models/chat/twitch_automod_highlight.dart';
import '../../../models/chat/twitch_automod_queue.dart';
import '../../../models/chat/twitch_whisper_emote_catalog.dart';
import '../../../models/emotes/twitch_cheermote_catalog.dart';
import '../../../models/emotes/twitch_official_emote.dart';
import '../../localization/vioclass_localizations.dart';
import 'twitch_selectable_emote.dart';
import 'twitch_whisper_selection.dart';

class TwitchAutomodMessageText extends StatelessWidget {
  final TwitchHeldAutomodMessage message;
  final TwitchCheermoteCatalog cheermotes;
  const TwitchAutomodMessageText({
    super.key,
    required this.message,
    this.cheermotes = const TwitchCheermoteCatalog.empty(),
  });

  Widget _image(List<String> urls, String text, [int index = 0]) =>
      Image.network(
        urls[index],
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stack) => index + 1 < urls.length
            ? _image(urls, text, index + 1)
            : Text(text),
      );

  @override
  Widget build(BuildContext context) {
    final mapping = TwitchAutomodHighlight.map(
      message.text,
      message.boundaries,
    );
    final colors = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    final fragments =
        message.fragments.isNotEmpty &&
            message.fragments.map((part) => part.text).join() == message.text
        ? message.fragments
        : [TwitchAutomodFragment(message.text)];
    final parts = fragments.map((part) {
      final url =
          part.bits == null ||
              part.cheerPrefix == null ||
              part.cheerTier == null
          ? null
          : cheermotes.image(
              part.cheerPrefix!,
              part.cheerTier!,
              part.bits!,
              dark: Theme.of(context).brightness == Brightness.dark,
            );
      return TwitchWhisperTextPart(
        part.text,
        part.emote ??
            (url == null
                ? null
                : TwitchOfficialEmote(
                    id: 'cheer_${part.cheerPrefix}_${part.cheerTier}',
                    name: part.text,
                    imageUrl: url,
                    emoteType: '',
                    tier: '',
                    emoteSetId: '',
                    ownerId: '',
                    source: TwitchOfficialEmoteSource.channel,
                    unlocked: false,
                  )),
      );
    }).toList();
    var offset = 0;
    final highlightStyle = TextStyle(
      backgroundColor: colors.errorContainer,
      color: colors.onErrorContainer,
      decoration: TextDecoration.underline,
    );
    for (var index = 0; index < fragments.length; index++) {
      final fragment = fragments[index];
      final image = parts[index].emote;
      final end = offset + fragment.text.length;
      final hits = mapping.ranges
          .where((range) => range.$1 < end && range.$2 > offset)
          .toList();
      if (image != null) {
        final urls = fragment.emote != null
            ? [image.imageUrl]
            : cheermotes.imageUrls(
                fragment.cheerPrefix!,
                fragment.cheerTier!,
                fragment.bits!,
                dark: Theme.of(context).brightness == Brightness.dark,
              );
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: TwitchSelectableEmote(
              text: fragment.text,
              child: Tooltip(
                message: fragment.text,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: hits.isEmpty ? null : colors.errorContainer,
                    border: hits.isEmpty
                        ? null
                        : Border.all(color: colors.error),
                  ),
                  child: _image(urls, fragment.text),
                ),
              ),
            ),
          ),
        );
      } else {
        var cursor = offset;
        for (final (start, hitEnd) in hits) {
          final begin = start < offset ? offset : start;
          final stop = hitEnd > end ? end : hitEnd;
          if (begin > cursor) {
            spans.add(TextSpan(text: message.text.substring(cursor, begin)));
          }
          spans.add(
            TextSpan(
              text: message.text.substring(begin, stop),
              style: highlightStyle,
            ),
          );
          cursor = stop;
        }
        if (cursor < end) {
          spans.add(TextSpan(text: message.text.substring(cursor, end)));
        }
      }
      offset = end;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parts.any((part) => part.emote != null))
          SelectionArea(
            child: TwitchWhisperSelection(
              parts: parts,
              span: TextSpan(children: spans),
            ),
          )
        else
          SelectableText.rich(TextSpan(children: spans)),
        for (final fragment in fragments.where((part) => part.bits != null))
          Text(
            '${fragment.text} · ${fragment.bits} Bits',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (message.boundaries.isNotEmpty && mapping.candidates.isEmpty)
          Text(
            context.vio.t('官方命中位置無法對應原文，請核對完整訊息。'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (mapping.ambiguous) ...[
          Text(
            context.vio.t('命中位置有不同解讀，請核對原文。'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final candidate in mapping.candidates)
            Text(
              '${candidate.units.join(" / ")}：${candidate.ranges.map((range) => message.text.substring(range.$1, range.$2)).join(" … ")}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}
