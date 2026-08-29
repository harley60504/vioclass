class TwitchLiveStream {
  final String id;
  final String userId;
  final String userLogin;
  final String userName;
  final String gameId;
  final String gameName;
  final String title;
  final int viewerCount;
  final DateTime? startedAt;
  final String language;
  final String thumbnailUrl;
  final List<String> tags;
  final bool isMature;
  final String profileImageUrl;

  const TwitchLiveStream({
    required this.id,
    required this.userId,
    required this.userLogin,
    required this.userName,
    required this.gameId,
    required this.gameName,
    required this.title,
    required this.viewerCount,
    required this.startedAt,
    required this.language,
    required this.thumbnailUrl,
    required this.tags,
    required this.isMature,
    this.profileImageUrl = '',
  });

  factory TwitchLiveStream.fromHelixJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];

    return TwitchLiveStream(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userLogin: json['user_login']?.toString().toLowerCase() ?? '',
      userName: json['user_name']?.toString() ?? '',
      gameId: json['game_id']?.toString() ?? '',
      gameName: json['game_name']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      viewerCount: _readInt(json['viewer_count']),
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
      language: json['language']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      tags: rawTags is List
          ? rawTags
                .map((tag) => tag.toString())
                .where((tag) => tag.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      isMature: json['is_mature'] == true,
    );
  }

  TwitchLiveStream copyWith({String? profileImageUrl}) {
    return TwitchLiveStream(
      id: id,
      userId: userId,
      userLogin: userLogin,
      userName: userName,
      gameId: gameId,
      gameName: gameName,
      title: title,
      viewerCount: viewerCount,
      startedAt: startedAt,
      language: language,
      thumbnailUrl: thumbnailUrl,
      tags: tags,
      isMature: isMature,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  String get displayName {
    if (userName.trim().isNotEmpty) return userName.trim();
    if (userLogin.trim().isNotEmpty) return userLogin.trim();
    return 'Unknown';
  }

  String get channelLogin => userLogin.trim().toLowerCase();

  String thumbnail({int width = 440, int height = 248}) {
    return thumbnailUrl
        .replaceAll('{width}', width.toString())
        .replaceAll('{height}', height.toString());
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'userLogin': userLogin,
      'userName': userName,
      'gameId': gameId,
      'gameName': gameName,
      'title': title,
      'viewerCount': viewerCount,
      'startedAt': startedAt?.toIso8601String(),
      'language': language,
      'thumbnailUrl': thumbnailUrl,
      'tags': tags,
      'isMature': isMature,
      'profileImageUrl': profileImageUrl,
    };
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class TwitchGameCategory {
  final String id;
  final String name;
  final String boxArtUrl;

  const TwitchGameCategory({
    required this.id,
    required this.name,
    required this.boxArtUrl,
  });

  factory TwitchGameCategory.fromHelixJson(Map<String, dynamic> json) {
    return TwitchGameCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      boxArtUrl: json['box_art_url']?.toString() ?? '',
    );
  }

  String boxArt({int width = 188, int height = 250}) {
    return boxArtUrl
        .replaceAll('{width}', width.toString())
        .replaceAll('{height}', height.toString());
  }
}

class TwitchFollowedChannel {
  final String broadcasterId;
  final String broadcasterLogin;
  final String broadcasterName;
  final DateTime? followedAt;
  final String profileImageUrl;
  final String offlineImageUrl;
  final String description;

  const TwitchFollowedChannel({
    required this.broadcasterId,
    required this.broadcasterLogin,
    required this.broadcasterName,
    required this.followedAt,
    this.profileImageUrl = '',
    this.offlineImageUrl = '',
    this.description = '',
  });

  factory TwitchFollowedChannel.fromHelixJson(Map<String, dynamic> json) {
    return TwitchFollowedChannel(
      broadcasterId: json['broadcaster_id']?.toString() ?? '',
      broadcasterLogin:
          json['broadcaster_login']?.toString().toLowerCase() ?? '',
      broadcasterName: json['broadcaster_name']?.toString() ?? '',
      followedAt: DateTime.tryParse(json['followed_at']?.toString() ?? ''),
    );
  }

  factory TwitchFollowedChannel.fromHelixSearchChannelJson(
    Map<String, dynamic> json,
  ) {
    return TwitchFollowedChannel(
      broadcasterId: json['id']?.toString() ?? '',
      broadcasterLogin:
          json['broadcaster_login']?.toString().toLowerCase() ?? '',
      broadcasterName: json['display_name']?.toString() ?? '',
      followedAt: null,
      profileImageUrl: json['thumbnail_url']?.toString().trim() ?? '',
      description: json['title']?.toString().trim() ?? '',
    );
  }

  TwitchFollowedChannel copyWith({
    String? profileImageUrl,
    String? offlineImageUrl,
    String? description,
  }) {
    return TwitchFollowedChannel(
      broadcasterId: broadcasterId,
      broadcasterLogin: broadcasterLogin,
      broadcasterName: broadcasterName,
      followedAt: followedAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      offlineImageUrl: offlineImageUrl ?? this.offlineImageUrl,
      description: description ?? this.description,
    );
  }

  String get channelLogin => broadcasterLogin.trim().toLowerCase();

  String get displayName {
    if (broadcasterName.trim().isNotEmpty) return broadcasterName.trim();
    if (broadcasterLogin.trim().isNotEmpty) return broadcasterLogin.trim();
    return 'Unknown';
  }
}

class TwitchChannelVideo {
  final String id;
  final String userId;
  final String userName;
  final String title;
  final String description;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final String url;
  final String thumbnailUrl;
  final int viewCount;
  final String duration;
  final String type;
  final String language;

  const TwitchChannelVideo({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.publishedAt,
    required this.url,
    required this.thumbnailUrl,
    required this.viewCount,
    required this.duration,
    required this.type,
    required this.language,
  });

  factory TwitchChannelVideo.fromHelixJson(Map<String, dynamic> json) {
    return TwitchChannelVideo(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      url: json['url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      viewCount: TwitchLiveStream._readInt(json['view_count']),
      duration: json['duration']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
    );
  }

  String thumbnail({int width = 440, int height = 248}) {
    return thumbnailUrl
        .replaceAll('%{width}', width.toString())
        .replaceAll('%{height}', height.toString())
        .replaceAll('{width}', width.toString())
        .replaceAll('{height}', height.toString());
  }

  Duration? get parsedDuration {
    final text = duration.trim().toLowerCase();
    if (text.isEmpty) return null;

    final matches = RegExp(r'(\d+)([hms])').allMatches(text);
    var seconds = 0;
    var found = false;
    for (final match in matches) {
      final value = int.tryParse(match.group(1) ?? '') ?? 0;
      switch (match.group(2)) {
        case 'h':
          seconds += value * 3600;
          found = true;
          break;
        case 'm':
          seconds += value * 60;
          found = true;
          break;
        case 's':
          seconds += value;
          found = true;
          break;
      }
    }
    return found ? Duration(seconds: seconds) : null;
  }

  bool get isLikelyGrowingArchive {
    final start = createdAt ?? publishedAt;
    final length = parsedDuration;
    if (start == null || length == null) return false;
    final estimatedEnd = start.toUtc().add(length);
    final age = DateTime.now().toUtc().difference(estimatedEnd);
    return age > const Duration(minutes: -5) &&
        age < const Duration(minutes: 20);
  }
}

class TwitchChannelClip {
  final String id;
  final String url;
  final String embedUrl;
  final String broadcasterId;
  final String broadcasterName;
  final String creatorName;
  final String videoId;
  final String gameId;
  final String language;
  final String title;
  final int viewCount;
  final DateTime? createdAt;
  final String thumbnailUrl;
  final double duration;
  final int vodOffset;

  const TwitchChannelClip({
    required this.id,
    required this.url,
    required this.embedUrl,
    required this.broadcasterId,
    required this.broadcasterName,
    required this.creatorName,
    required this.videoId,
    required this.gameId,
    required this.language,
    required this.title,
    required this.viewCount,
    required this.createdAt,
    required this.thumbnailUrl,
    required this.duration,
    required this.vodOffset,
  });

  factory TwitchChannelClip.fromHelixJson(Map<String, dynamic> json) {
    return TwitchChannelClip(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      embedUrl: json['embed_url']?.toString() ?? '',
      broadcasterId: json['broadcaster_id']?.toString() ?? '',
      broadcasterName: json['broadcaster_name']?.toString() ?? '',
      creatorName: json['creator_name']?.toString() ?? '',
      videoId: json['video_id']?.toString() ?? '',
      gameId: json['game_id']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      viewCount: TwitchLiveStream._readInt(json['view_count']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      duration: double.tryParse(json['duration']?.toString() ?? '') ?? 0,
      vodOffset: TwitchLiveStream._readInt(json['vod_offset']),
    );
  }
}

class TwitchChannelPanel {
  final String id;
  final String type;
  final String title;
  final String description;
  final String imageUrl;
  final String linkUrl;

  const TwitchChannelPanel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.linkUrl,
  });

  factory TwitchChannelPanel.fromGqlJson(Map<String, dynamic> json) {
    return TwitchChannelPanel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString().trim() ?? '',
      description: json['description']?.toString().trim() ?? '',
      imageUrl: json['imageURL']?.toString().trim() ?? '',
      linkUrl: json['linkURL']?.toString().trim() ?? '',
    );
  }

  bool get hasContent {
    return title.isNotEmpty ||
        description.isNotEmpty ||
        imageUrl.isNotEmpty ||
        linkUrl.isNotEmpty;
  }
}

class TwitchChannelSocialLink {
  final String name;
  final String title;
  final String url;

  const TwitchChannelSocialLink({
    required this.name,
    required this.title,
    required this.url,
  });

  factory TwitchChannelSocialLink.fromGqlJson(Map<String, dynamic> json) {
    final name = json['name']?.toString().trim() ?? '';
    return TwitchChannelSocialLink(
      name: name,
      title: json['title']?.toString().trim() ?? name,
      url: json['url']?.toString().trim() ?? '',
    );
  }

  bool get hasContent => url.isNotEmpty;
}

class TwitchChannelAboutResult {
  final List<TwitchChannelPanel> panels;
  final List<TwitchChannelSocialLink> socialLinks;

  const TwitchChannelAboutResult({
    required this.panels,
    required this.socialLinks,
  });
}

class TwitchStreamPageResult {
  final List<TwitchLiveStream> streams;
  final String? cursor;

  const TwitchStreamPageResult({required this.streams, required this.cursor});

  bool get hasMore => cursor != null && cursor!.trim().isNotEmpty;
}

class TwitchGamePageResult {
  final List<TwitchGameCategory> games;
  final String? cursor;

  const TwitchGamePageResult({required this.games, required this.cursor});

  bool get hasMore => cursor != null && cursor!.trim().isNotEmpty;
}

class TwitchFollowedChannelPageResult {
  final List<TwitchFollowedChannel> channels;
  final String? cursor;

  const TwitchFollowedChannelPageResult({
    required this.channels,
    required this.cursor,
  });

  bool get hasMore => cursor != null && cursor!.trim().isNotEmpty;
}

class TwitchChannelVideoPageResult {
  final List<TwitchChannelVideo> videos;
  final String? cursor;

  const TwitchChannelVideoPageResult({
    required this.videos,
    required this.cursor,
  });

  bool get hasMore => cursor != null && cursor!.trim().isNotEmpty;
}

class TwitchChannelClipPageResult {
  final List<TwitchChannelClip> clips;
  final String? cursor;

  const TwitchChannelClipPageResult({
    required this.clips,
    required this.cursor,
  });

  bool get hasMore => cursor != null && cursor!.trim().isNotEmpty;
}
