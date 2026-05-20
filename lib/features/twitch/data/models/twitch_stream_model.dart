class TwitchStreamModel {
  final String id;
  final String userId;
  final String userLogin;
  final String userName;
  final String title;
  final String gameName;
  final int viewerCount;
  final String thumbnailUrl;
  final String profileImageUrl;

  const TwitchStreamModel({
    this.id = '',
    this.userId = '',
    this.userLogin = '',
    this.userName = '',
    this.title = '',
    this.gameName = '',
    this.viewerCount = 0,
    this.thumbnailUrl = '',
    this.profileImageUrl = '',
  });

  factory TwitchStreamModel.fromJson(Map<String, dynamic> json) {
    return TwitchStreamModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      userLogin: json['user_login']?.toString() ?? json['userLogin']?.toString() ?? json['login']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? json['userName']?.toString() ?? json['displayName']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      gameName: json['game_name']?.toString() ?? json['gameName']?.toString() ?? '',
      viewerCount: int.tryParse(json['viewer_count']?.toString() ?? json['viewerCount']?.toString() ?? '') ?? 0,
      thumbnailUrl: json['thumbnail_url']?.toString() ?? json['thumbnailUrl']?.toString() ?? '',
      profileImageUrl: json['profile_image_url']?.toString() ?? json['profileImageUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'userLogin': userLogin,
      'userName': userName,
      'title': title,
      'gameName': gameName,
      'viewerCount': viewerCount,
      'thumbnailUrl': thumbnailUrl,
      'profileImageUrl': profileImageUrl,
    };
  }
}
