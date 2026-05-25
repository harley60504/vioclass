class TwitchUser {
  final String id;
  final String login;
  final String displayName;
  final String type;
  final String broadcasterType;
  final String description;
  final String profileImageUrl;
  final String offlineImageUrl;
  final int viewCount;
  final DateTime? createdAt;

  const TwitchUser({
    required this.id,
    required this.login,
    required this.displayName,
    this.type = '',
    this.broadcasterType = '',
    this.description = '',
    this.profileImageUrl = '',
    this.offlineImageUrl = '',
    this.viewCount = 0,
    this.createdAt,
  });

  factory TwitchUser.fromHelixJson(Map<String, dynamic> json) {
    return TwitchUser(
      id: json['id']?.toString() ?? '',
      login: json['login']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      broadcasterType: json['broadcaster_type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      profileImageUrl: json['profile_image_url']?.toString() ?? '',
      offlineImageUrl: json['offline_image_url']?.toString() ?? '',
      viewCount: int.tryParse(json['view_count']?.toString() ?? '') ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  factory TwitchUser.fromGqlUserJson(Map<String, dynamic> json) {
    return TwitchUser(
      id: json['id']?.toString() ?? '',
      login: json['login']?.toString() ?? '',
      displayName:
          json['displayName']?.toString() ??
          json['display_name']?.toString() ??
          json['login']?.toString() ??
          '',
      description: json['description']?.toString() ?? '',
      profileImageUrl:
          json['profileImageURL']?.toString() ??
          json['profile_image_url']?.toString() ??
          '',
      offlineImageUrl:
          json['offlineImageURL']?.toString() ??
          json['offline_image_url']?.toString() ??
          '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'login': login,
      'displayName': displayName,
      'type': type,
      'broadcasterType': broadcasterType,
      'description': description,
      'profileImageUrl': profileImageUrl,
      'offlineImageUrl': offlineImageUrl,
      'viewCount': viewCount,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
