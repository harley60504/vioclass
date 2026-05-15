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

  TwitchLiveStream copyWith({
    String? profileImageUrl,
  }) {
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

  String thumbnail({
    int width = 440,
    int height = 248,
  }) {
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

  String boxArt({
    int width = 188,
    int height = 250,
  }) {
    return boxArtUrl
        .replaceAll('{width}', width.toString())
        .replaceAll('{height}', height.toString());
  }
}

class TwitchStreamPageResult {
  final List<TwitchLiveStream> streams;
  final String? cursor;

  const TwitchStreamPageResult({
    required this.streams,
    required this.cursor,
  });

  bool get hasMore => cursor != null && cursor!.trim().isNotEmpty;
}


class TwitchGamePageResult {
  final List<TwitchGameCategory> games;
  final String? cursor;

  const TwitchGamePageResult({
    required this.games,
    required this.cursor,
  });

  bool get hasMore => cursor != null && cursor!.trim().isNotEmpty;
}
