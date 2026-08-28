class TwitchChatTextPart {
  final String text;
  final bool isLink;

  const TwitchChatTextPart({required this.text, required this.isLink});
}

class TwitchChatPreviewUrl {
  final String url;
  final bool trusted;

  const TwitchChatPreviewUrl({required this.url, required this.trusted});
}

class TwitchChatLinkPreviewData {
  final String url;
  final String kind;
  final String host;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final String? author;
  final String? videoId;

  const TwitchChatLinkPreviewData({
    required this.url,
    required this.kind,
    required this.host,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.author,
    this.videoId,
  });

  bool get hasContent {
    return (title?.trim().isNotEmpty ?? false) ||
        (description?.trim().isNotEmpty ?? false) ||
        (imageUrl?.trim().isNotEmpty ?? false);
  }
}
