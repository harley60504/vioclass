class TwitchStream {
  final String id;
  final String userId;
  final String userLogin;
  final String userName;
  final String gameId;
  final String gameName;
  final String type;
  final String title;
  final int viewerCount;
  final DateTime? startedAt;
  final String language;
  final String thumbnailUrl;
  final List<String> tagIds;
  final List<String> tags;
  final bool isMature;

  const TwitchStream({
    required this.id,
    required this.userId,
    required this.userLogin,
    required this.userName,
    required this.gameId,
    required this.gameName,
    required this.type,
    required this.title,
    required this.viewerCount,
    required this.startedAt,
    required this.language,
    required this.thumbnailUrl,
    this.tagIds = const <String>[],
    this.tags = const <String>[],
    this.isMature = false,
  });

  factory TwitchStream.fromHelixJson(Map<String, dynamic> json) {
    return TwitchStream(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userLogin: json['user_login']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      gameId: json['game_id']?.toString() ?? '',
      gameName: json['game_name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      viewerCount: int.tryParse(json['viewer_count']?.toString() ?? '') ?? 0,
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
      language: json['language']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      tagIds: _readStringList(json['tag_ids']),
      tags: _readStringList(json['tags']),
      isMature: json['is_mature'] == true,
    );
  }

  String getThumbnailUrl({
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
      'type': type,
      'title': title,
      'viewerCount': viewerCount,
      'startedAt': startedAt?.toIso8601String(),
      'language': language,
      'thumbnailUrl': thumbnailUrl,
      'tagIds': tagIds,
      'tags': tags,
      'isMature': isMature,
    };
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}
