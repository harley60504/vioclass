// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';

import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_api_constants.dart';
import '../lib/features/twitch/api/core/twitch_gql_api_service.dart';
import '../lib/features/twitch/api/playback/twitch_playback_api_service.dart';
import '../lib/features/twitch/services/playback/twitch_playback_integrity_browser.dart';
import '../lib/features/twitch/services/playback/twitch_playback_integrity_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ProbeApp());
}

class _ProbeApp extends StatefulWidget {
  const _ProbeApp();

  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<_ProbeApp> {
  String status = 'running';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final client = TwitchApiClient();
    var browserAcquisitions = 0;
    final manager = TwitchPlaybackIntegrityManager(
      acquire:
          ({
            required clientId,
            required channelLogin,
            required viewerAuth,
          }) async {
            browserAcquisitions++;
            return const TwitchPlaybackIntegrityBrowserAcquirer().acquire(
              clientId: clientId,
              channelLogin: channelLogin,
              viewerAuth: viewerAuth,
            );
          },
    );
    try {
      final headers = await Future.wait(<Future<Map<String, String>>>[
        manager.headersFor(
          clientId: TwitchApiConstants.twitchWebClientId,
          channelLogin: 'monstercat',
          viewerAuth: null,
        ),
        manager.headersFor(
          clientId: TwitchApiConstants.twitchWebClientId,
          channelLogin: 'monstercat',
          viewerAuth: null,
        ),
      ]);
      final sharedProof =
          headers[0]['Client-Integrity'] == headers[1]['Client-Integrity'];
      final cached = manager.cachedHeadersFor(
        clientId: TwitchApiConstants.twitchWebClientId,
        viewerAuth: null,
      );
      final api = TwitchPlaybackApiService(
        gql: TwitchGqlApiService(
          client: client,
          clientId: TwitchApiConstants.twitchWebClientId,
        ),
        cachedIntegrityHeaders: manager.cachedHeadersFor,
        integrityHeadersProvider: manager.headersFor,
        integrityInvalidator: manager.invalidateRejected,
      );
      final token = await api.getLivePlaybackAccessToken(
        channelLogin: 'monstercat',
      );
      final passed =
          browserAcquisitions == 1 &&
          sharedProof &&
          cached != null &&
          token.isValid;
      debugPrint(
        '[PlaybackIntegrityProbe] passed=$passed '
        'browserAcquisitions=$browserAcquisitions '
        'singleflight=$sharedProof cache=${cached != null} '
        'protectedEndpoint=${token.isValid}',
      );
      if (mounted) setState(() => status = passed ? 'passed' : 'failed');
    } catch (error) {
      debugPrint(
        '[PlaybackIntegrityProbe] passed=false errorType=${error.runtimeType}',
      );
      if (mounted) setState(() => status = 'failed: ${error.runtimeType}');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: Center(child: Text('Playback integrity: $status'))),
  );
}
