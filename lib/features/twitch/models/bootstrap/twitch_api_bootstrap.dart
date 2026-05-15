class TwitchApiBootstrapSnapshot {
  final String channelLogin;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? stream;
  final Map<String, dynamic>? playback;
  final Map<String, dynamic>? pinnedChat;
  final Map<String, dynamic>? hypeTrain;
  final Map<String, dynamic>? channelPoints;
  final Map<String, dynamic>? prediction;
  final Map<String, dynamic>? chatStartup;
  final DateTime startedAt;
  final DateTime completedAt;

  const TwitchApiBootstrapSnapshot({
    required this.channelLogin,
    required this.startedAt,
    required this.completedAt,
    this.user,
    this.stream,
    this.playback,
    this.pinnedChat,
    this.hypeTrain,
    this.channelPoints,
    this.prediction,
    this.chatStartup,
  });

  int get elapsedMilliseconds {
    return completedAt.difference(startedAt).inMilliseconds;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'elapsedMilliseconds': elapsedMilliseconds,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'user': user,
      'stream': stream,
      'playback': playback,
      'pinnedChat': pinnedChat,
      'hypeTrain': hypeTrain,
      'channelPoints': channelPoints,
      'prediction': prediction,
      'chatStartup': chatStartup,
    };
  }
}
