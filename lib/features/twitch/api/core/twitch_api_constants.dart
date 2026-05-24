/// Twitch API 常數集中管理。
///
/// 這一層只放 endpoint / client id / timeout 這種低階常數。
/// 不要在 UI 或 controller 裡到處硬寫 URL。
class TwitchApiConstants {
  TwitchApiConstants._();

  /// Twitch Web 公開 Client-ID。
  ///
  /// Twitch release workflow also injects this as TWITCH_WEB_CLIENT_ID.
  /// 用於 Web GQL / playback token / ChannelPointsContext 類 public-web context。
  static const String twitchWebClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

  /// Twitch Android / Drops-compatible public Client-ID used by Twitch.
  ///
  /// Twitch release workflow injects this as TWITCH_ANDROID_CLIENT_ID.
  /// Used for empty-scope device flow, drops token, claim, prediction bet.
  static const String twitchAndroidPublicClientId =
      'kd1unb4b3q4t58fwlpcbzcbnm76a8fp';

  /// Drops / channel-points Client-ID.
  ///
  /// Defaults to the Twitch-compatible public Android Client-ID, but can be
  /// overridden at build time:
  ///
  /// flutter run -d windows --dart-define=TWITCH_DROPS_CLIENT_ID=<client_id>
  ///
  /// TWITCH_ANDROID_CLIENT_ID is still accepted as a compatibility fallback.
  static const String twitchDefaultDropsClientId = String.fromEnvironment(
    'TWITCH_DROPS_CLIENT_ID',
    defaultValue: String.fromEnvironment(
      'TWITCH_ANDROID_CLIENT_ID',
      defaultValue: twitchAndroidPublicClientId,
    ),
  );

  static bool get hasDefaultDropsClientId {
    return twitchDefaultDropsClientId.trim().isNotEmpty;
  }

  /// Backward-compatible alias used by older test code.
  static const String twitchAndroidClientId = twitchDefaultDropsClientId;

  static bool get hasTwitchAndroidClientId {
    return hasDefaultDropsClientId;
  }

  /// Helix API base URL.
  static const String helixBaseUrl = 'https://api.twitch.tv/helix';

  /// Twitch GraphQL endpoint.
  static const String gqlEndpoint = 'https://gql.twitch.tv/gql';

  /// Twitch IRC WebSocket endpoint.
  static const String ircWebSocketUrl = 'wss://irc-ws.chat.twitch.tv:443';

  /// Twitch Hermes WebSocket endpoint.
  ///
  /// 後面接 prediction / channel points 事件時會用到。
  static const String hermesWebSocketUrl = 'wss://hermes.twitch.tv/v1';

  /// OAuth token validation endpoint.
  static const String oauthValidateUrl = 'https://id.twitch.tv/oauth2/validate';

  /// OAuth token revoke endpoint.
  static const String oauthRevokeUrl = 'https://id.twitch.tv/oauth2/revoke';

  static const Duration connectTimeout = Duration(seconds: 12);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  static const String browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const Map<String, String> twitchWebHeaders = <String, String>{
    'User-Agent': browserUserAgent,
    'Accept': '*/*',
    'Origin': 'https://www.twitch.tv',
    'Referer': 'https://www.twitch.tv/',
  };
}
