import '../../models/bootstrap/twitch_api_bootstrap.dart';
import '../engagement/twitch_channel_points_api_service.dart';
import '../chat/twitch_chat_startup_api_service.dart';
import '../engagement/twitch_hype_train_api_service.dart';
import '../engagement/twitch_pinned_chat_api_service.dart';
import '../playback/twitch_playback_api_service.dart';
import '../engagement/twitch_prediction_api_service.dart';
import '../channel/twitch_stream_api_service.dart';
import '../channel/twitch_user_api_service.dart';

class TwitchApiBootstrapService {
  final TwitchUserApiService userApi;
  final TwitchStreamApiService streamApi;
  final TwitchPlaybackApiService playbackApi;
  final TwitchPinnedChatApiService pinnedChatApi;
  final TwitchHypeTrainApiService hypeTrainApi;
  final TwitchChannelPointsApiService channelPointsApi;
  final TwitchPredictionApiService predictionApi;
  final TwitchChatStartupApiService chatStartupApi;

  const TwitchApiBootstrapService({
    required this.userApi,
    required this.streamApi,
    required this.playbackApi,
    required this.pinnedChatApi,
    required this.hypeTrainApi,
    required this.channelPointsApi,
    required this.predictionApi,
    required this.chatStartupApi,
  });

  Future<TwitchApiBootstrapSnapshot> bootstrapChannel({
    required String channelLogin,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channelLogin cannot be empty',
      );
    }

    final startedAt = DateTime.now();

    final userFuture = userApi.getUserByLogin(login);
    final streamFuture = streamApi.getLiveStreamByLogin(login);
    final playbackFuture = _safeMap(() async {
      final token = await playbackApi.getLivePlaybackAccessToken(
        channelLogin: login,
      );
      final uri = playbackApi.buildLivePlaylistUri(
        channelLogin: login,
        accessToken: token,
      );

      return <String, dynamic>{
        'hasValue': token.value.isNotEmpty,
        'valueLength': token.value.length,
        'hasSignature': token.signature.isNotEmpty,
        'signature': token.signature,
        'playlistUriPreview': uri.toString().replaceFirst(
          RegExp(r'token=[^&]+'),
          'token=<hidden>',
        ),
      };
    });
    final hypeTrainFuture = _safeMap(() async {
      final snapshot = await hypeTrainApi.getHypeTrainSnapshot(
        channelLogin: login,
      );
      return snapshot.toJson();
    });
    final channelPointsFuture = _safeMap(() async {
      final bundle = await channelPointsApi.fetchChannelPointsBundle(
        channelLogin: login,
      );
      return bundle.toJson();
    });
    final predictionFuture = _safeMap(() async {
      final prediction = await predictionApi.fetchPredictionContext(
        channelLogin: login,
      );
      return prediction.toJson();
    });
    final chatStartupFuture = _safeMap(() async {
      final startup = await chatStartupApi.fetchParsedStartupSnapshot(
        channelLogin: login,
      );
      return startup.toJson();
    });

    final user = await userFuture;
    final channelId = user?.id ?? '';

    final pinnedChatFuture = _safeMap(() async {
      if (channelId.isEmpty) {
        return <String, dynamic>{'error': 'channelId is empty'};
      }

      final messages = await pinnedChatApi.getPinnedChatMessages(
        channelId: channelId,
        count: 10,
      );

      return <String, dynamic>{
        'channelId': channelId,
        'count': messages.length,
        'messages': messages.map((message) => message.toJson()).toList(),
      };
    });

    final stream = await streamFuture;

    final snapshot = TwitchApiBootstrapSnapshot(
      channelLogin: login,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      user: user == null ? null : _normalize(user),
      stream: stream == null
          ? <String, dynamic>{'online': false, 'login': login}
          : _normalize(stream),
      playback: await playbackFuture,
      pinnedChat: await pinnedChatFuture,
      hypeTrain: await hypeTrainFuture,
      channelPoints: await channelPointsFuture,
      prediction: await predictionFuture,
      chatStartup: await chatStartupFuture,
    );

    return snapshot;
  }

  Future<Map<String, dynamic>> _safeMap(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      return <String, dynamic>{
        'error': error.toString(),
        'stackTop': stackTrace.toString().split('\n').take(3).join('\n'),
      };
    }
  }

  Map<String, dynamic> _normalize(Object value) {
    try {
      final dynamic dynamicValue = value;
      final Object? json = dynamicValue.toJson();

      if (json is Map<String, dynamic>) return json;
      return <String, dynamic>{'value': json};
    } catch (_) {
      return <String, dynamic>{'value': value.toString()};
    }
  }
}
