import '../engagement/twitch_channel_points_api_service.dart';
import '../engagement/twitch_pinned_chat_api_service.dart';
import '../engagement/twitch_prediction_api_service.dart';
import 'twitch_api_client.dart';
import 'twitch_api_constants.dart';
import 'twitch_web_gql_persisted_api_service.dart';

typedef TwitchRouterAccessTokenProvider = Future<String?> Function();
typedef TwitchRouterDropsTokenProvider = Future<String?> Function();

/// Central API classification point.
///
/// The important rule:
///
/// - publicWebGql: Twitch web Client-ID, no user Authorization.
/// - viewerWebGql: OAuth token's own clientId + OAuth token.
/// - dropsChannelPoints: merged channel-points API using the drops token provider.
/// - viewer actions are optional and must never be required for chat connect.
class TwitchApiRouter {
  final TwitchApiClient client;
  final TwitchRouterAccessTokenProvider? accessTokenProvider;
  final TwitchRouterDropsTokenProvider? dropsTokenProvider;

  late final TwitchWebGqlPersistedApiService publicWebGql;
  late final TwitchChannelPointsApiService publicChannelPoints;
  late final TwitchPredictionApiService publicPrediction;
  late final TwitchPinnedChatApiService pinnedChat;

  TwitchChannelPointsApiService? _dropsChannelPoints;
  TwitchWebGqlPersistedApiService? _viewerWebGql;
  TwitchChannelPointsApiService? _viewerChannelPoints;
  TwitchPredictionApiService? _viewerPrediction;

  TwitchApiRouter({
    required this.client,
    this.accessTokenProvider,
    this.dropsTokenProvider,
  }) {
    publicWebGql = TwitchWebGqlPersistedApiService(
      client: client,
      clientId: TwitchApiConstants.twitchWebClientId,
      accessTokenProvider: null,
    );

    publicChannelPoints = TwitchChannelPointsApiService(
      gql: publicWebGql,
      client: client,
      webClientId: TwitchApiConstants.twitchWebClientId,
    );
    publicPrediction = TwitchPredictionApiService(gql: publicWebGql);

    pinnedChat = TwitchPinnedChatApiService(
      client: client,
      clientId: TwitchApiConstants.twitchWebClientId,
      accessTokenProvider: null,
    );

    if (dropsTokenProvider != null) {
      _dropsChannelPoints = TwitchChannelPointsApiService(
        client: client,
        tokenProvider: dropsTokenProvider,
        webClientId: TwitchApiConstants.twitchWebClientId,
        androidClientId: TwitchApiConstants.twitchAndroidClientId,
      );
    }
  }

  TwitchWebGqlPersistedApiService? get viewerWebGql => _viewerWebGql;
  TwitchChannelPointsApiService? get viewerChannelPoints =>
      _viewerChannelPoints;
  TwitchPredictionApiService? get viewerPrediction => _viewerPrediction;

  /// Old public name kept for call sites that still ask the router for the
  /// drops-token channel-points client.
  ///
  /// This is no longer a separate `TwitchDropsChannelPointsApiService`; it is
  /// the unified `TwitchChannelPointsApiService` configured with
  /// [dropsTokenProvider].
  TwitchChannelPointsApiService? get dropsChannelPoints => _dropsChannelPoints;

  /// Preferred action client for channel-point actions.
  ///
  /// Drops token is preferred because the merged channel-points service uses it
  /// for balance / claim / reward actions. If it is unavailable, fall back to
  /// the normal viewer OAuth action client.
  TwitchChannelPointsApiService? get channelPointsActions {
    return _dropsChannelPoints ?? _viewerChannelPoints;
  }

  bool get hasViewerActionClient {
    return _viewerWebGql != null && accessTokenProvider != null;
  }

  bool get hasDropsChannelPointsClient {
    return _dropsChannelPoints != null;
  }

  bool get hasChannelPointsActionClient {
    return channelPointsActions != null;
  }

  void configureViewer({required String oauthClientId}) {
    final clientId = oauthClientId.trim();

    if (clientId.isEmpty || accessTokenProvider == null) {
      clearViewer();
      return;
    }

    final viewerGql = TwitchWebGqlPersistedApiService(
      client: client,
      clientId: clientId,
      accessTokenProvider: accessTokenProvider,
    );

    _viewerWebGql = viewerGql;
    _viewerChannelPoints = TwitchChannelPointsApiService(
      gql: viewerGql,
      client: client,
      tokenProvider: accessTokenProvider,
      webClientId: clientId,
      androidClientId: TwitchApiConstants.twitchAndroidClientId,
      actionClientIdProvider: () => clientId,
    );
    _viewerPrediction = TwitchPredictionApiService(gql: viewerGql);
  }

  void clearViewer() {
    _viewerWebGql = null;
    _viewerChannelPoints = null;
    _viewerPrediction = null;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'publicWebGqlClientId': TwitchApiConstants.twitchWebClientId,
      'viewerWebGqlClientId': _viewerWebGql?.clientId,
      'hasViewerActionClient': hasViewerActionClient,
      'hasDropsChannelPointsClient': hasDropsChannelPointsClient,
      'hasChannelPointsActionClient': hasChannelPointsActionClient,
      'channelPointsActionSource': _dropsChannelPoints != null
          ? 'dropsTokenProvider'
          : _viewerChannelPoints != null
          ? 'viewerOAuth'
          : null,
      'twitchAndroidClientIdConfigured':
          TwitchApiConstants.hasTwitchAndroidClientId,
      'rules': const <String, String>{
        'publicWebGql': 'Twitch web Client-ID; no Authorization',
        'viewerWebGql': 'OAuth validate client_id + OAuth token; actions only',
        'pinnedChat': 'public read',
        'channelPointsRewards': 'public read first',
        'channelPointsViewerActions':
            'merged TwitchChannelPointsApiService action client on demand',
        'channelPointsActions':
            'prefer dropsTokenProvider; fallback to viewer OAuth action client',
        'predictionDisplay': 'public read',
        'predictionBet': 'drops token action on demand',
      },
    };
  }
}
