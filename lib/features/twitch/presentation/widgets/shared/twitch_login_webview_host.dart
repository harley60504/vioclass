import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import '../../../services/auth/twitch_webview_environment_disposal.dart';

/// Creates Windows login views only after the existing cookie profile is ready.
/// Never silently falls back to the plugin's default (different) profile.
class TwitchLoginWebViewHost extends StatefulWidget {
  final Widget Function(WebViewEnvironment? environment) builder;
  final Future<WebViewEnvironment> Function()? createEnvironment;

  const TwitchLoginWebViewHost({
    super.key,
    required this.builder,
    this.createEnvironment,
  });

  @override
  State<TwitchLoginWebViewHost> createState() => _TwitchLoginWebViewHostState();
}

class _TwitchLoginWebViewHostState extends State<TwitchLoginWebViewHost> {
  WebViewEnvironment? _environment;
  bool _failed = false;
  String? _failureCode;
  bool get _needsEnvironment =>
      Platform.isWindows || widget.createEnvironment != null;

  @override
  void initState() {
    super.initState();
    if (_needsEnvironment) unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      final environment =
          await (widget.createEnvironment?.call() ??
              WebViewEnvironment.create(
                settings: WebViewEnvironmentSettings(
                  userDataFolder:
                      '${Directory.systemTemp.path}${Platform.pathSeparator}'
                      'new_twitch_app_shared_twitch_desktop_webview_v30',
                ),
              ));
      if (!mounted) {
        await disposeTwitchWebViewEnvironment(environment);
        return;
      }
      setState(() => _environment = environment);
    } catch (error) {
      // No OAuth URLs, cookies or token values in diagnostics.
      _failureCode = error is PlatformException
          ? '${error.code}: ${error.message ?? 'WebViewEnvironment creation failed'}'
          : error.runtimeType.toString();
      debugPrint('[TwitchLoginWebView][environment-create] $_failureCode');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    final environment = _environment;
    if (environment != null) {
      unawaited(
        disposeTwitchWebViewEnvironment(environment).catchError((Object error) {
          debugPrint(
            '[TwitchLoginWebView][environment-dispose] ${error.runtimeType}',
          );
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsEnvironment || _environment != null) {
      return widget.builder(_environment);
    }
    if (_failed) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() => _failed = false);
            unawaited(_prepare());
          },
          child: Text(
            '無法建立登入 WebView，點此重試${_failureCode == null ? '' : '\n$_failureCode'}',
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
