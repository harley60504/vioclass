import '../emotes/twitch_official_emote.dart';

class TwitchWhisperTextPart {
  final String text;
  final TwitchOfficialEmote? emote;
  const TwitchWhisperTextPart(this.text, [this.emote]);
}

/// Whisper EventSub contains plain text, not authoritative emote positions.
class TwitchWhisperEmoteCatalog {
  final List<TwitchOfficialEmote> emotes;
  final String? userError;
  final Map<String, TwitchOfficialEmote> _byName;
  TwitchWhisperEmoteCatalog(List<TwitchOfficialEmote> emotes, {this.userError})
    : emotes = List.unmodifiable(emotes),
      _byName = _index(emotes);
  const TwitchWhisperEmoteCatalog.empty()
    : emotes = const [],
      userError = null,
      _byName = const {};

  static Map<String, TwitchOfficialEmote> _index(
    List<TwitchOfficialEmote> emotes,
  ) {
    final byName = <String, TwitchOfficialEmote>{};
    final ambiguous = <String>{};
    for (final emote in emotes) {
      final previous = byName[emote.name];
      if (previous != null && previous.id != emote.id) {
        ambiguous.add(emote.name);
      }
      byName[emote.name] = emote;
    }
    for (final name in ambiguous) {
      byName.remove(name);
    }
    return Map.unmodifiable(byName);
  }

  List<TwitchWhisperTextPart> parse(String text) {
    return RegExp(r'\s+|\S+')
        .allMatches(text)
        .map((match) {
          final token = match.group(0)!;
          return TwitchWhisperTextPart(token, _byName[token]);
        })
        .toList(growable: false);
  }
}
