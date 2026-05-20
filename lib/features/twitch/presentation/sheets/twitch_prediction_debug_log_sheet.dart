import 'dart:async';

import 'package:flutter/material.dart';

import '../../debug/twitch_prediction_debug_log_bus.dart';
import '../../services/engagement/twitch_prediction_hermes_runtime_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchPredictionDebugLogSheet({
  required BuildContext context,
}) {
  return showTwitchResponsiveSheet<void>(
    context: context,
    size: TwitchUnifiedSheetSize.medium,
    builder: (_) => const TwitchPredictionDebugLogSheet(),
  );
}

class TwitchPredictionDebugLogSheet extends StatefulWidget {
  const TwitchPredictionDebugLogSheet({super.key});

  @override
  State<TwitchPredictionDebugLogSheet> createState() =>
      _TwitchPredictionDebugLogSheetState();
}

class _TwitchPredictionDebugLogSheetState
    extends State<TwitchPredictionDebugLogSheet> {
  StreamSubscription<dynamic>? _predictionSub;

  @override
  void initState() {
    super.initState();
    TwitchPredictionDebugLogBus.instance.add('Debug sheet opened');
    _predictionSub = TwitchPredictionHermesRealtimeBus.predictionStream.listen(
      (prediction) {
        if (prediction == null) {
          TwitchPredictionDebugLogBus.instance.add('Prediction bus: null');
          return;
        }
        TwitchPredictionDebugLogBus.instance.add(
          'Prediction bus: id=${prediction.id.isEmpty ? '--' : prediction.id} '
          'status=${prediction.status.isEmpty ? '--' : prediction.status} '
          'outcomes=${prediction.outcomes.length} '
          'points=${prediction.totalPoints}',
        );
      },
    );
  }

  @override
  void dispose() {
    _predictionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: TwitchUnifiedSheetScaffold(
        title: 'Prediction Debug Log',
        subtitle: '顯示 Prediction bus / Hermes 後續推進事件',
        icon: Icons.bug_report_rounded,
        showRefresh: false,
        child: AnimatedBuilder(
          animation: TwitchPredictionDebugLogBus.instance,
          builder: (context, _) {
            final entries = TwitchPredictionDebugLogBus.instance.entries
                .reversed
                .toList(growable: false);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '目前只要 prediction bus 有 publish，這裡就會更新。',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.58),
                            fontSize: 12,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: TwitchPredictionDebugLogBus.instance.clear,
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('清空'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF2D2D35)),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Text(
                            '還沒有 log。\n開著這個面板後，等待賭盤資料更新或手動刷新互動。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            return SelectableText(
                              entries[index],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                                height: 1.35,
                                fontFamily: 'monospace',
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
