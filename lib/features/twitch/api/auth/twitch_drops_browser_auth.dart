/// Drops authorization via a browser redirect, independent of device-code auth.
class TwitchDropsBrowserAuth {
  static const defaultRedirectUri = 'https://www.twitch.tv/';

  static Uri authorizationUri({
    required String clientId,
    required String state,
    String redirectUri = defaultRedirectUri,
  }) => Uri.https('id.twitch.tv', '/oauth2/authorize', {
    'response_type': 'token',
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'scope': '',
    'state': state,
    'force_verify': 'false',
  });

  static bool isRedirectResponse(Uri uri, {required String redirectUri}) {
    final expected = Uri.tryParse(redirectUri);
    if (expected == null ||
        uri.scheme != expected.scheme ||
        uri.host != expected.host ||
        uri.port != expected.port ||
        uri.path != expected.path) {
      return false;
    }
    final params = {
      ...uri.queryParameters,
      if (uri.fragment.isNotEmpty) ...Uri.splitQueryString(uri.fragment),
    };
    return params.containsKey('access_token') || params.containsKey('error');
  }

  /// Never show an OAuth credential in the app's status/address text.
  static String displayUrl(Uri uri) => Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}
