import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../models/auth/twitch_auth_token.dart';
import '../../services/auth/twitch_auth_service.dart';

/// Lightweight Twitch OAuth proof-of-concept using flutter_web_auth_2.
///
/// This page intentionally handles only the official Twitch OAuth token.
/// Web/GQL authentication remains a separate pipeline so this experiment can
/// tell us whether the OAuth package itself works with Twitch/Google sign-in.
class TwitchOAuthPackageLoginPage extends StatefulWidget {
  final TwitchAuthService mainAuthService;
  final TwitchAuthApiService authApi;

  const TwitchOAuthPackageLoginPage({
    super.key,
    required this.mainAuthService,
    required this.authApi,
  });

  static const String clientId = 'euyqoof00efejc6vk5f4gv0nze20ue';
  static const String redirectUri = 'http://localhost:3000';
  static const List<String> scopes = <String>[
    'user:read:email',
    'user:read:follows',
    'chat:read',
    'chat:edit',
    'user:read:emotes',
    'clips:edit',
  ];

  @override
  State<TwitchOAuthPackageLoginPage> createState() =>
      _TwitchOAuthPackageLoginPageState();
}

class _TwitchOAuthPackageLoginPageState
    extends State<TwitchOAuthPackageLoginPage> {
  bool _busy = false;
  String _status = '準備登入 Twitch';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_login());
    });
  }

  String _newState() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Uri _authorizationUri(String state) {
    return Uri.parse('https://id.twitch.tv/oauth2/authorize').replace(
      queryParameters: <String, String>{
        'response_type': 'token',
        'client_id': TwitchOAuthPackageLoginPage.clientId,
        'redirect_uri': TwitchOAuthPackageLoginPage.redirectUri,
        'scope': TwitchOAuthPackageLoginPage.scopes.join(' '),
        'state': state,
        'force_verify': 'false',
      },
    );
  }

  Map<String, String> _oauthParams(Uri uri) {
    final result = <String, String>{};
    if (uri.query.isNotEmpty) {
      result.addAll(Uri.splitQueryString(uri.query));
    }
    if (uri.fragment.isNotEmpty) {
      result.addAll(Uri.splitQueryString(uri.fragment));
    }
    return result;
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = '正在開啟 Twitch 登入…';
    });

    final state = _newState();

    try {
      // On Windows flutter_web_auth_2 5.x uses its WebView implementation by
      // default. We intentionally keep that default here because this PoC is
      // testing whether the package can handle Twitch -> Google -> Twitch
      // without switching VioClass to an external system browser.
      final result = await FlutterWebAuth2.authenticate(
        url: _authorizationUri(state).toString(),
        callbackUrlScheme: 'http',
      );

      final uri = Uri.parse(result);
      final params = _oauthParams(uri);

      final error = params['error'];
      if (error != null && error.isNotEmpty) {
        throw StateError(error);
      }

      if (params['state'] != state) {
        throw StateError('OAuth state mismatch');
      }

      final accessToken = params['access_token']?.trim();
      if (accessToken == null || accessToken.isEmpty) {
        throw StateError('OAuth access token missing');
      }

      if (mounted) {
        setState(() => _status = '正在驗證 Twitch 登入…');
      }

      final validation = await widget.authApi.validateToken(accessToken);
      final scopes = validation.scopes.isNotEmpty
          ? validation.scopes
          : TwitchOAuthPackageLoginPage.scopes;

      final token = TwitchAuthToken(
        accessToken: accessToken,
        refreshToken: '',
        tokenType: 'bearer',
        scopes: scopes,
        expiresIn: validation.expiresIn > 0
            ? validation.expiresIn
            : int.tryParse(params['expires_in'] ?? '') ?? 14400,
        obtainedAt: DateTime.now(),
      );

      await widget.mainAuthService.saveSession(
        clientId: validation.clientId.trim().isNotEmpty
            ? validation.clientId.trim()
            : TwitchOAuthPackageLoginPage.clientId,
        token: token,
      );

      if (!mounted) return;
      setState(() => _status = 'Twitch OAuth 登入成功');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _status = 'Twitch OAuth 登入失敗';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Twitch OAuth 測試'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  const CircularProgressIndicator()
                else
                  const Icon(Icons.login_rounded, size: 52, color: Colors.white),
                const SizedBox(height: 18),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _login,
                    child: const Text('重新登入'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
