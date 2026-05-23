import '../../api/special_actions/twitch_viewer_special_message_api_service_stage251.dart';
import '../../models/special_actions/twitch_viewer_special_message_models_stage251.dart';

class TwitchViewerSpecialMessageSendResultStage251 {
  final bool ok;
  final String operation;
  final dynamic raw;
  final Object? error;

  const TwitchViewerSpecialMessageSendResultStage251({
    required this.ok,
    required this.operation,
    this.raw,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ok': ok,
      'operation': operation,
      'raw': raw,
      if (error != null) 'error': error.toString(),
    };
  }
}

class TwitchViewerSpecialMessageRuntimeStage251 {
  final TwitchViewerSpecialMessageApiServiceStage251 api;

  const TwitchViewerSpecialMessageRuntimeStage251({required this.api});

  Future<TwitchViewerSpecialMessagesSnapshotStage251> load({
    required String channelLogin,
    String? channelId,
    String? viewerId,
    bool includeWatchStreak = true,
    bool includeResub = true,
    bool includeChatIdentity = true,
  }) async {
    final issues = <TwitchViewerSpecialMessageBackendIssue>[];
    TwitchWatchStreakStatusStage251? watchStreak;
    TwitchResubNotificationStage251? resub;
    TwitchChatIdentityStatusStage251? chatIdentity;

    await Future.wait<void>([
      if (includeWatchStreak)
        (() async {
          try {
            watchStreak = await api.getWatchStreak(
              channelLogin: channelLogin,
              channelId: channelId,
              viewerId: viewerId,
            );
          } catch (error) {
            issues.add(
              TwitchViewerSpecialMessageBackendIssue(
                area: 'watchStreak',
                message: error.toString(),
                raw: error,
              ),
            );
          }
        })(),
      if (includeResub)
        (() async {
          try {
            resub = await api.getResubNotification(
              channelLogin: channelLogin,
              channelId: channelId,
              viewerId: viewerId,
            );
          } catch (error) {
            issues.add(
              TwitchViewerSpecialMessageBackendIssue(
                area: 'resub',
                message: error.toString(),
                raw: error,
              ),
            );
          }
        })(),
      if (includeChatIdentity)
        (() async {
          try {
            chatIdentity = await api.fetchChatIdentityBadges(
              channelLogin: channelLogin,
              channelId: channelId,
              viewerId: viewerId,
            );
          } catch (error) {
            issues.add(
              TwitchViewerSpecialMessageBackendIssue(
                area: 'chatIdentity',
                message: error.toString(),
                raw: error,
              ),
            );
          }
        })(),
    ]);

    return TwitchViewerSpecialMessagesSnapshotStage251(
      channelLogin: channelLogin.trim().toLowerCase(),
      channelId: channelId,
      checkedAt: DateTime.now(),
      watchStreak: watchStreak,
      resub: resub,
      chatIdentity: chatIdentity,
      issues: issues,
    );
  }

  Future<TwitchViewerSpecialMessageSendResultStage251> shareWatchStreak({
    required String channelLogin,
    String? channelId,
    String? viewerId,
    required TwitchWatchStreakStatusStage251 status,
    String message = '',
  }) async {
    try {
      final raw = await api.shareWatchStreak(
        channelLogin: channelLogin,
        channelId: channelId ?? status.channelId,
        viewerId: viewerId,
        shareToken: status.shareToken,
        message: message,
      );
      return TwitchViewerSpecialMessageSendResultStage251(
        ok: true,
        operation: 'shareWatchStreak',
        raw: raw,
      );
    } catch (error) {
      return TwitchViewerSpecialMessageSendResultStage251(
        ok: false,
        operation: 'shareWatchStreak',
        error: error,
      );
    }
  }

  Future<TwitchViewerSpecialMessageSendResultStage251> useResubToken({
    required String channelLogin,
    String? channelId,
    String? viewerId,
    required TwitchResubNotificationStage251 resub,
    String message = '',
  }) async {
    final token = resub.token?.trim() ?? '';
    if (token.isEmpty) {
      return const TwitchViewerSpecialMessageSendResultStage251(
        ok: false,
        operation: 'useResubToken',
        error: 'Missing resub token.',
      );
    }

    try {
      final raw = await api.useResubToken(
        channelLogin: channelLogin,
        channelId: channelId ?? resub.channelId,
        viewerId: viewerId,
        token: token,
        message: message,
      );
      return TwitchViewerSpecialMessageSendResultStage251(
        ok: true,
        operation: 'useResubToken',
        raw: raw,
      );
    } catch (error) {
      return TwitchViewerSpecialMessageSendResultStage251(
        ok: false,
        operation: 'useResubToken',
        error: error,
      );
    }
  }

  Future<TwitchViewerSpecialMessageSendResultStage251> updateChatIdentity({
    required String channelLogin,
    String? channelId,
    String? viewerId,
    required TwitchChatIdentityBadgeStage251 badge,
  }) async {
    try {
      final raw = await api.updateChatIdentity(
        channelLogin: channelLogin,
        channelId: channelId,
        viewerId: viewerId,
        badgeSetId: badge.setId,
        badgeVersion: badge.version,
      );
      return TwitchViewerSpecialMessageSendResultStage251(
        ok: true,
        operation: 'updateChatIdentity',
        raw: raw,
      );
    } catch (error) {
      return TwitchViewerSpecialMessageSendResultStage251(
        ok: false,
        operation: 'updateChatIdentity',
        error: error,
      );
    }
  }
}
