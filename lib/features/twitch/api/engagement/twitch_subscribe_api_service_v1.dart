// Opens official Twitch subscription/channel pages from Flutter desktop.

import 'dart:io';

class TwitchSubscribeApiServiceV1 {
  const TwitchSubscribeApiServiceV1();

  Uri buildSubscribeUri(String channelLogin) {
    final login = _safeLogin(channelLogin);
    return Uri.https('www.twitch.tv', '/subs/$login');
  }

  Uri buildChannelUri(String channelLogin) {
    final login = _safeLogin(channelLogin);
    return Uri.https('www.twitch.tv', '/$login');
  }

  Future<void> openSubscribePage(String channelLogin) async {
    await openExternalUri(buildSubscribeUri(channelLogin));
  }

  Future<void> openChannelPage(String channelLogin) async {
    await openExternalUri(buildChannelUri(channelLogin));
  }

  Future<void> openExternalUri(Uri uri) async {
    final text = uri.toString();

    if (Platform.isWindows) {
      await Process.start('cmd', <String>[
        '/c',
        'start',
        '',
        text,
      ], runInShell: true);
      return;
    }

    if (Platform.isMacOS) {
      await Process.start('open', <String>[text]);
      return;
    }

    if (Platform.isLinux) {
      await Process.start('xdg-open', <String>[text]);
      return;
    }

    throw UnsupportedError('Unsupported platform for opening URL: $text');
  }

  String _safeLogin(String channelLogin) {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channelLogin cannot be empty',
      );
    }
    return login;
  }
}
