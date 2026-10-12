//
// Central visual sizing for runtime chat messages. Adjust chat text / emote /
// badge sizes here instead of editing the whole message tile file.

class TwitchChatMessageVisualMetrics {
  final double scale;
  final bool compact;

  const TwitchChatMessageVisualMetrics(double rawScale, {this.compact = false})
    : scale = rawScale < 0.82
          ? 0.82
          : rawScale > 1.45
          ? 1.45
          : rawScale;

  double get compactFactor => compact ? 0.92 : 1.0;

  double get messageFontSize => 14 * scale * compactFactor;
  double get compactMessageFontSize => 13.4 * scale * compactFactor;
  double get nameFontSize => 14 * scale * compactFactor;
  double get compactNameFontSize => 13.2 * scale * compactFactor;
  double get metaFontSize => 10.5 * scale * compactFactor;
  double get chipFontSize => 10 * scale * compactFactor;
  double get badgeSize => 18 * scale * compactFactor;
  double get compactBadgeSize => 16 * scale * compactFactor;
  double get emoteSize => 28 * scale * compactFactor;
  double get thirdPartyEmoteSize => 28 * scale * compactFactor;
  double get zeroWidthEmoteSize => 24 * scale * compactFactor;
  double get lineHeight => compact ? 1.18 : 1.25;
}
