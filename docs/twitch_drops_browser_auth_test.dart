// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/auth/twitch_drops_browser_auth.dart';

void main() {
  test('Drops uses authorize with an empty scope and a Twitch redirect', () {
    final uri = TwitchDropsBrowserAuth.authorizationUri(
      clientId: 'android-client',
      state: 'random-state',
    );
    expect(uri.host, 'id.twitch.tv');
    expect(uri.path, '/oauth2/authorize');
    expect(uri.queryParameters, {
      'response_type': 'token',
      'client_id': 'android-client',
      'redirect_uri': 'https://www.twitch.tv/',
      'scope': '',
      'state': 'random-state',
      'force_verify': 'false',
    });
  });

  test('Ordinary Twitch navigation is not an OAuth callback', () {
    for (final url in [
      'https://www.twitch.tv/',
      'https://www.twitch.tv/login',
    ]) {
      expect(
        TwitchDropsBrowserAuth.isRedirectResponse(
          Uri.parse(url),
          redirectUri: TwitchDropsBrowserAuth.defaultRedirectUri,
        ),
        isFalse,
      );
    }
  });

  test('Only the exact redirect destination can carry the grant', () {
    for (final url in [
      'http://www.twitch.tv/#access_token=test',
      'https://www.twitch.tv.evil.example/#access_token=test',
      'https://www.twitch.tv:444/#access_token=test',
      'https://www.twitch.tv/login#access_token=test',
      'http://localhost:3000/#access_token=test',
    ]) {
      expect(
        TwitchDropsBrowserAuth.isRedirectResponse(
          Uri.parse(url),
          redirectUri: TwitchDropsBrowserAuth.defaultRedirectUri,
        ),
        isFalse,
      );
    }
  });

  test('Both success and denied consent are recognized on the redirect', () {
    for (final response in [
      'access_token=test&state=random-state',
      'error=access_denied&state=random-state',
    ]) {
      expect(
        TwitchDropsBrowserAuth.isRedirectResponse(
          Uri.parse('https://www.twitch.tv/#$response'),
          redirectUri: TwitchDropsBrowserAuth.defaultRedirectUri,
        ),
        isTrue,
      );
    }
  });

  test('Status URLs never show authorization credentials', () {
    expect(
      TwitchDropsBrowserAuth.displayUrl(
        Uri.parse(
          'https://www.twitch.tv/?access_token=secret#access_token=secret',
        ),
      ),
      'https://www.twitch.tv/',
    );
  });
}
