enum TwitchThirdPartyEmoteProvider { bttv, ffz, sevenTv }

enum TwitchThirdPartyEmoteScope { global, channel, shared, other }

class TwitchThirdPartyEmote {
  final String id;
  final String name;

  /// Preferred animated/render URL for normal visible chat rendering.
  final String imageUrl;

  /// Static fallback URL used while chat is scrolling or when the row is not
  /// actively rendered. This avoids creating animated image codecs for 7TV/BTTV
  /// emotes while the user is rapidly scanning chat.
  final String staticImageUrl;

  final TwitchThirdPartyEmoteProvider provider;
  final TwitchThirdPartyEmoteScope scope;
  final bool isZeroWidth;
  final bool isAnimated;
  final int? width;
  final int? height;

  const TwitchThirdPartyEmote({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.staticImageUrl = '',
    required this.provider,
    this.scope = TwitchThirdPartyEmoteScope.other,
    this.isZeroWidth = false,
    this.isAnimated = false,
    this.width,
    this.height,
  });

  String get effectiveStaticImageUrl {
    final staticUrl = staticImageUrl.trim();
    if (staticUrl.isNotEmpty) return staticUrl;
    return imageUrl;
  }

  double get aspectRatio {
    final w = width ?? 0;
    final h = height ?? 0;
    if (w <= 0 || h <= 0) return 1.0;
    return (w / h).clamp(0.5, 4.0).toDouble();
  }

  String get providerLabel {
    switch (provider) {
      case TwitchThirdPartyEmoteProvider.bttv:
        return 'BTTV';
      case TwitchThirdPartyEmoteProvider.ffz:
        return 'FFZ';
      case TwitchThirdPartyEmoteProvider.sevenTv:
        return '7TV';
    }
  }

  String get scopeLabel {
    switch (scope) {
      case TwitchThirdPartyEmoteScope.global:
        return 'Global';
      case TwitchThirdPartyEmoteScope.channel:
        return 'Channel';
      case TwitchThirdPartyEmoteScope.shared:
        return 'Shared';
      case TwitchThirdPartyEmoteScope.other:
        return 'Other';
    }
  }

  bool get isChannelLike {
    return scope == TwitchThirdPartyEmoteScope.channel ||
        scope == TwitchThirdPartyEmoteScope.shared ||
        scope == TwitchThirdPartyEmoteScope.other;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'staticImageUrl': staticImageUrl,
      'provider': provider.name,
      'scope': scope.name,
      'isZeroWidth': isZeroWidth,
      'isAnimated': isAnimated,
      'width': width,
      'height': height,
    };
  }
}
