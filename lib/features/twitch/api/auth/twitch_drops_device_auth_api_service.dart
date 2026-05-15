import './twitch_device_auth_api_service.dart';
import '../core/twitch_api_constants.dart';
import '../core/twitch_api_exception.dart';

typedef TwitchDropsClientIdProvider = String Function();

/// Drops / channel-points device auth.
///
/// This intentionally uses empty scopes, matching the StreamNook /
/// TwitchDropsMiner style flow. The Client-ID is configurable so we can test
/// whether a normal Developer Client-ID works with the same flow.
class TwitchDropsDeviceAuthApiService {
  final TwitchDeviceAuthApiService deviceAuthApi;
  final TwitchDropsClientIdProvider? clientIdProvider;

  const TwitchDropsDeviceAuthApiService({
    required this.deviceAuthApi,
    this.clientIdProvider,
  });

  String get clientId {
    final provided = clientIdProvider?.call().trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return TwitchApiConstants.twitchDefaultDropsClientId.trim();
  }

  void _ensureConfigured() {
    if (clientId.trim().isEmpty) {
      throw TwitchApiException(
        'Drops Client-ID is empty. Enter a Twitch Developer Client-ID in the '
        'test page, or pass --dart-define=TWITCH_DROPS_CLIENT_ID=<client_id>.',
      );
    }
  }

  Future<TwitchDeviceAuthorization> startDeviceFlow() {
    _ensureConfigured();

    return deviceAuthApi.startDeviceAuthorization(
      clientId: clientId,
      scopes: const <String>[],
    );
  }

  Future<TwitchDeviceTokenPollResult> pollForToken({
    required String deviceCode,
    int currentIntervalSeconds = 5,
  }) {
    _ensureConfigured();

    return deviceAuthApi.pollDeviceToken(
      clientId: clientId,
      deviceCode: deviceCode,
      scopes: const <String>[],
      currentIntervalSeconds: currentIntervalSeconds,
    );
  }
}
