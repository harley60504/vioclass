class TwitchAuthToken {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final List<String> scopes;
  final int expiresIn;
  final DateTime obtainedAt;

  const TwitchAuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.scopes,
    required this.expiresIn,
    required this.obtainedAt,
  });

  DateTime get expiresAt => obtainedAt.add(Duration(seconds: expiresIn));

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  bool get expiresSoon {
    return DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));
  }

  factory TwitchAuthToken.fromOAuthJson(Map<String, dynamic> json) {
    final scope = json['scope'];

    return TwitchAuthToken(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      scopes: scope is List
          ? scope.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      expiresIn: int.tryParse(json['expires_in']?.toString() ?? '') ?? 0,
      obtainedAt: DateTime.now(),
    );
  }

  factory TwitchAuthToken.fromJson(Map<String, dynamic> json) {
    final scopes = json['scopes'];

    return TwitchAuthToken(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      tokenType: json['tokenType']?.toString() ?? 'bearer',
      scopes: scopes is List
          ? scopes.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      expiresIn: int.tryParse(json['expiresIn']?.toString() ?? '') ?? 0,
      obtainedAt: DateTime.tryParse(json['obtainedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': tokenType,
      'scopes': scopes,
      'expiresIn': expiresIn,
      'obtainedAt': obtainedAt.toIso8601String(),
    };
  }
}
