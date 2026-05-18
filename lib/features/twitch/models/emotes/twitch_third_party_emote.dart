enum TwitchThirdPartyEmoteProvider {
  bttv,
  ffz,
  sevenTv,
}

enum TwitchThirdPartyEmoteScope {
  global,
  channel,
  shared,
  other,
}

class TwitchThirdPartyEmote {
  final String id;
  final String name;
  final String imageUrl;
  final TwitchThirdPartyEmoteProvider provider;
  final TwitchThirdPartyEmoteScope scope;
  final bool isZeroWidth;
  final int? width;
  final int? height;

  const TwitchThirdPartyEmote({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.provider,
    this.scope = TwitchThirdPartyEmoteScope.other,
    this.isZeroWidth = false,
    this.width,
    this.height,
  });

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
      'provider': provider.name,
      'scope': scope.name,
      'isZeroWidth': isZeroWidth,
      'width': width,
      'height': height,
    };
  }
}
