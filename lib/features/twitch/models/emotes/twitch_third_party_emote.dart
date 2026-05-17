enum TwitchThirdPartyEmoteProvider {
  bttv,
  ffz,
  sevenTv,
}

class TwitchThirdPartyEmote {
  final String id;
  final String name;
  final String imageUrl;
  final TwitchThirdPartyEmoteProvider provider;
  final bool isZeroWidth;
  final int? width;
  final int? height;

  const TwitchThirdPartyEmote({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.provider,
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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'provider': provider.name,
      'isZeroWidth': isZeroWidth,
      'width': width,
      'height': height,
    };
  }
}
