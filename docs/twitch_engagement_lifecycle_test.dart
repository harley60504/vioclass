// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/engagement/twitch_hype_train_api_service.dart';
import '../lib/features/twitch/services/engagement/twitch_hype_train_controller.dart';
import '../lib/features/twitch/presentation/watch/twitch_watch_feature_ports.dart';
import '../lib/features/twitch/presentation/watch/controllers/twitch_watch_engagement_controller.dart';

class _RefreshPort {
  final requests = <Completer<TwitchWatchEngagementSnapshot>>[];
  Future<TwitchWatchEngagementSnapshot> refresh({
    required String channelLogin,
    required String? channelId,
  }) {
    final gate = Completer<TwitchWatchEngagementSnapshot>();
    requests.add(gate);
    return gate.future;
  }
}

class _NoNetworkHype extends TwitchHypeTrainController {
  int refreshes = 0;
  _NoNetworkHype() : super(api: const TwitchHypeTrainApiService());
  @override
  Future<void> refresh({
    required String channelLogin,
    String? channelId,
  }) async {
    refreshes++;
  }
}

TwitchWatchEngagementSnapshot _snapshot(String marker) =>
    TwitchWatchEngagementSnapshot(
      channelPoints: null,
      prediction: null,
      pinnedMessages: [marker],
      error: null,
    );

void main() {
  for (final change in ['none', 'newer', 'reset', 'viewer']) {
    test('Engagement rejects obsolete refresh change=$change', () async {
      final port = _RefreshPort();
      final hype = _NoNetworkHype();
      var viewer = 'fixture-viewer';
      final controller = TwitchWatchEngagementController(
        emotesPort: Object(),
        engagementPort: port,
        channelLogin: () => 'fixture',
        channelId: () => null,
        viewerId: () => viewer,
        isCurrentWatchTask: (_, _) => true,
        hypeTrainController: hype,
      );
      addTearDown(controller.dispose);
      final old = controller.refreshEngagement(notifyBalanceDelta: false);
      expect(port.requests.length, 1);
      if (change == 'newer') {
        final newer = controller.refreshEngagement(notifyBalanceDelta: false);
        port.requests[1].complete(_snapshot('new'));
        await newer;
      } else if (change == 'reset') {
        controller.reset();
      } else if (change == 'viewer') {
        viewer = 'replacement-viewer';
      }
      port.requests.first.complete(_snapshot('old'));
      await old;
      expect(
        controller.pinnedMessages,
        change == 'none'
            ? ['old']
            : change == 'newer'
            ? ['new']
            : isEmpty,
      );
      expect(controller.loadingEngagement, isFalse);
      expect(hype.refreshes, change == 'none' || change == 'newer' ? 1 : 0);
    });
  }
}
