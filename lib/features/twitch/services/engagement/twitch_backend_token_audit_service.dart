import '../../api/engagement/twitch_channel_points_api_service.dart';

class TwitchBackendTokenAuditService {
  final TwitchChannelPointsApiService channelPointsApi;

  TwitchBackendTokenAuditService({
    TwitchChannelPointsApiService? channelPointsApi,
    TwitchChannelPointsApiService? publicChannelPointsApi,
    TwitchChannelPointsApiService? dropsChannelPointsApi,
  }) : channelPointsApi = channelPointsApi ??
            dropsChannelPointsApi ??
            publicChannelPointsApi ??
            (throw ArgumentError(
              'TwitchBackendTokenAuditService requires channelPointsApi.',
            ));

  /// Deprecated alias kept for old diagnostics wiring.
  @Deprecated('Use channelPointsApi instead.')
  TwitchChannelPointsApiService get publicChannelPointsApi => channelPointsApi;

  /// Deprecated alias kept for old diagnostics wiring.
  @Deprecated('Use channelPointsApi instead.')
  TwitchChannelPointsApiService get dropsChannelPointsApi => channelPointsApi;

  Future<TwitchBackendChannelPointsAudit> probeChannelPoints({
    required String channelLogin,
  }) async {
    final startedAt = DateTime.now();
    final login = channelLogin.trim().toLowerCase();

    Map<String, dynamic>? publicRead;
    Map<String, dynamic>? contextRead;
    Map<String, dynamic>? rewardsRead;
    String? publicError;
    String? contextError;
    String? rewardsError;

    try {
      final publicBundle = await channelPointsApi.fetchChannelPointsBundle(
        channelLogin: login,
      );

      publicRead = publicBundle.toJson();
    } catch (e) {
      publicError = e.toString();
    }

    try {
      final context = await channelPointsApi.getContext(
        channelLogin: login,
      );

      contextRead = context.toJson();
    } catch (e) {
      contextError = e.toString();
    }

    try {
      final rewards = await channelPointsApi.getRewards(
        channelLogin: login,
      );

      rewardsRead = rewards.toJson();
    } catch (e) {
      rewardsError = e.toString();
    }

    return TwitchBackendChannelPointsAudit(
      channelLogin: login,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      publicRead: publicRead,
      publicError: publicError,
      contextRead: contextRead,
      contextError: contextError,
      rewardsRead: rewardsRead,
      rewardsError: rewardsError,
    );
  }
}

class TwitchBackendChannelPointsAudit {
  final String channelLogin;
  final DateTime startedAt;
  final DateTime completedAt;
  final Map<String, dynamic>? publicRead;
  final String? publicError;
  final Map<String, dynamic>? contextRead;
  final String? contextError;
  final Map<String, dynamic>? rewardsRead;
  final String? rewardsError;

  const TwitchBackendChannelPointsAudit({
    required this.channelLogin,
    required this.startedAt,
    required this.completedAt,
    required this.publicRead,
    required this.publicError,
    required this.contextRead,
    required this.contextError,
    required this.rewardsRead,
    required this.rewardsError,
  });

  bool get publicOk => publicError == null;
  bool get contextOk => contextError == null;
  bool get rewardsOk => rewardsError == null;
  bool get usable => publicOk || contextOk || rewardsOk;

  /// Deprecated alias kept for old diagnostics UI.
  bool get dropsOk => contextOk;

  /// Deprecated alias kept for old diagnostics UI.
  String? get dropsError => contextError;

  /// Deprecated alias kept for old diagnostics UI.
  Map<String, dynamic>? get dropsRead => contextRead;

  int get elapsedMilliseconds {
    return completedAt.difference(startedAt).inMilliseconds;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'elapsedMilliseconds': elapsedMilliseconds,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'usable': usable,
      'publicOk': publicOk,
      'publicError': publicError,
      'publicRead': publicRead,
      'contextOk': contextOk,
      'contextError': contextError,
      'contextRead': contextRead,
      'dropsOk': dropsOk,
      'dropsError': dropsError,
      'dropsRead': dropsRead,
      'rewardsOk': rewardsOk,
      'rewardsError': rewardsError,
      'rewardsRead': rewardsRead,
    };
  }
}
