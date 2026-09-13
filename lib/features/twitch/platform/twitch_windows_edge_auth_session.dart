import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A small Windows-only bridge to a real Microsoft Edge profile.
///
/// Edge is launched with a dedicated, persistent user-data folder and a
/// loopback-only DevTools endpoint. The endpoint lets the app observe the
/// OAuth redirect URL and read the HttpOnly Twitch web cookie from that exact
/// browser session without putting Google OAuth inside an embedded WebView.
class TwitchWindowsEdgeAuthSession {
  static const bool isExperimentEnabled = bool.fromEnvironment(
    'TWITCH_WINDOWS_EDGE_AUTH_TEST',
    defaultValue: true,
  );

  static String sharedUserDataFolder() {
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'new_twitch_app_windows_edge_auth_v1';
    try {
      Directory(path).createSync(recursive: true);
    } catch (_) {}
    return path;
  }

  Process? _process;
  int? _debugPort;

  bool get isStarted => _debugPort != null;

  Future<void> start({
    required String authorizationUrl,
    required String userDataFolder,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Microsoft Edge auth is Windows-only.');
    }

    final edgeExecutable = _findEdgeExecutable();
    if (edgeExecutable == null) {
      throw StateError('Microsoft Edge was not found.');
    }

    final profileDirectory = Directory(userDataFolder);
    await profileDirectory.create(recursive: true);
    // Chromium exposes navigator.webdriver when the special port value 0 is
    // used. Google then rejects the sign-in as an automated/unsafe browser.
    // A normal loopback port keeps this as a regular Edge session while still
    // allowing VioClass to inspect only its dedicated browser profile.
    final debugPort = await _reserveLoopbackPort();
    _debugPort = debugPort;

    _process = await Process.start(edgeExecutable, <String>[
      '--remote-debugging-address=127.0.0.1',
      '--remote-debugging-port=$debugPort',
      '--user-data-dir=${profileDirectory.path}',
      '--profile-directory=Default',
      '--no-first-run',
      '--no-default-browser-check',
      '--new-window',
      authorizationUrl,
    ], mode: ProcessStartMode.detachedWithStdio);
    unawaited(_process!.stdout.drain<void>());
    unawaited(_process!.stderr.drain<void>());

    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      try {
        await _readJson('/json/version');
        return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    await close();
    throw StateError('Microsoft Edge DevTools endpoint did not start.');
  }

  Future<int> _reserveLoopbackPort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    try {
      return socket.port;
    } finally {
      await socket.close();
    }
  }

  Future<List<Uri>> readPageUris() async {
    final targets = await _readTargets();
    return targets
        .map((target) => Uri.tryParse(target.url))
        .whereType<Uri>()
        .toList(growable: false);
  }

  Future<String?> readTwitchAuthToken() async {
    final targets = await _readTargets();
    for (final target in targets) {
      if (target.webSocketDebuggerUrl.isEmpty) continue;
      try {
        final response = await _sendCommand(
          target.webSocketDebuggerUrl,
          'Network.getAllCookies',
        );
        final result = response['result'];
        if (result is! Map) continue;
        final cookies = result['cookies'];
        if (cookies is! List) continue;
        for (final item in cookies) {
          if (item is! Map) continue;
          final name = item['name']?.toString().toLowerCase();
          final domain = item['domain']?.toString().toLowerCase() ?? '';
          final value = item['value']?.toString().trim() ?? '';
          if (name == 'auth-token' &&
              domain.endsWith('twitch.tv') &&
              value.isNotEmpty) {
            return value;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<bool> isAlive() async {
    try {
      await _readJson('/json/version');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> close() async {
    final port = _debugPort;
    _debugPort = null;
    var gracefulCloseRequested = false;
    if (port != null) {
      try {
        final version = await _readJsonForPort(port, '/json/version');
        final socketUrl = version['webSocketDebuggerUrl']?.toString();
        if (socketUrl != null && socketUrl.isNotEmpty) {
          await _sendCommand(socketUrl, 'Browser.close');
          gracefulCloseRequested = true;
        }
      } catch (_) {}
    }
    final process = _process;
    _process = null;
    if (process == null) return;

    if (gracefulCloseRequested) {
      try {
        // Give Edge time to flush cookies and profile state before falling
        // back to terminating a stuck browser process.
        await process.exitCode.timeout(const Duration(seconds: 5));
        return;
      } catch (_) {}
    }

    try {
      process.kill();
    } catch (_) {}
  }

  Future<List<_EdgeDevToolsTarget>> _readTargets() async {
    final raw = await _readJson('/json/list');
    if (raw is! List) return const <_EdgeDevToolsTarget>[];
    return raw
        .whereType<Map>()
        .where((item) => item['type'] == 'page')
        .map(
          (item) => _EdgeDevToolsTarget(
            url: item['url']?.toString() ?? '',
            webSocketDebuggerUrl:
                item['webSocketDebuggerUrl']?.toString() ?? '',
          ),
        )
        .toList(growable: false);
  }

  Future<dynamic> _readJson(String path) async {
    final port = _debugPort;
    if (port == null) throw StateError('Edge auth session is not started.');
    return _readJsonForPort(port, path);
  }

  Future<dynamic> _readJsonForPort(int port, String path) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(Uri.http('127.0.0.1:$port', path));
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Edge DevTools returned ${response.statusCode}.');
      }
      final body = await utf8.decoder.bind(response).join();
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _sendCommand(
    String webSocketDebuggerUrl,
    String method,
  ) async {
    final socket = await WebSocket.connect(
      webSocketDebuggerUrl,
    ).timeout(const Duration(seconds: 3));
    try {
      const commandId = 1;
      socket.add(
        jsonEncode(<String, dynamic>{'id': commandId, 'method': method}),
      );
      await for (final message in socket.timeout(const Duration(seconds: 3))) {
        final decoded = jsonDecode(message.toString());
        if (decoded is Map && decoded['id'] == commandId) {
          return Map<String, dynamic>.from(decoded);
        }
      }
      throw StateError('Edge DevTools connection closed without a response.');
    } finally {
      await socket.close();
    }
  }

  String? _findEdgeExecutable() {
    final candidates = <String>{
      if (Platform.environment['PROGRAMFILES(X86)'] case final root?)
        '$root\\Microsoft\\Edge\\Application\\msedge.exe',
      if (Platform.environment['PROGRAMFILES'] case final root?)
        '$root\\Microsoft\\Edge\\Application\\msedge.exe',
      if (Platform.environment['LOCALAPPDATA'] case final root?)
        '$root\\Microsoft\\Edge\\Application\\msedge.exe',
    };
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }
}

class _EdgeDevToolsTarget {
  final String url;
  final String webSocketDebuggerUrl;

  const _EdgeDevToolsTarget({
    required this.url,
    required this.webSocketDebuggerUrl,
  });
}
