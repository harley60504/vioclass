import 'package:flutter/material.dart';

import '../../chat/services/twitch_prediction_probe_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

/// Prediction Probe debug sheet.
///
/// This belongs under:
///   lib/features/twitch/presentation/sheets/
///
/// It should not live under:
///   lib/features/twitch/presentation/widgets/chat/
///
/// because it is a popup sheet, not a chat-row/widget component.
Future<void> showTwitchPredictionProbeSheet({
  required BuildContext context,
  required TwitchPredictionProbeService predictionProbe,
}) async {
  await showTwitchResponsiveSheet<void>(
    context: context,
    size: TwitchUnifiedSheetSize.wide,
    builder: (sheetContext) {
      return AnimatedBuilder(
        animation: predictionProbe,
        builder: (context, _) {
          final logs = predictionProbe.logs.reversed.toList(growable: false);
          final events = predictionProbe.events.reversed.toList(growable: false);

          return TwitchUnifiedSheetScaffold(
            title: 'Prediction Probe',
            subtitle: predictionProbe.statusText,
            icon: predictionProbe.hermesConnected
                ? Icons.query_stats
                : Icons.query_stats_outlined,
            loading: false,
            onRefresh: predictionProbe.reconnect,
            onClose: () => Navigator.of(sheetContext).maybePop(),
            child: Column(
              children: [
              if (predictionProbe.errorText != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  color: Colors.redAccent.withOpacity(0.14),
                  child: Text(
                    predictionProbe.errorText!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        labelColor: Color(0xFFBF94FF),
                        unselectedLabelColor: Colors.white54,
                        indicatorColor: Color(0xFF9146FF),
                        tabs: [
                          Tab(text: '事件'),
                          Tab(text: 'Log'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            events.isEmpty
                                ? const Center(
                                    child: Text(
                                      '還沒有收到 prediction-like 事件。\n找一個正在開賽況預測的台，或等實況主開新預測。',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white54,
                                        height: 1.35,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(10),
                                    itemCount: events.length,
                                    itemBuilder: (context, index) {
                                      final event = events[index];
                                      final summary = event.summary;

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.045),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.08),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              event.topic ?? 'unknown topic',
                                              style: const TextStyle(
                                                color: Color(0xFFBF94FF),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              [
                                                if (event.type != null)
                                                  'type=${event.type}',
                                                if (summary.title != null)
                                                  'title=${summary.title}',
                                                if (summary.status != null)
                                                  'status=${summary.status}',
                                                if (summary.totalPoints != null)
                                                  'points=${summary.totalPoints}',
                                                if (summary.totalUsers != null)
                                                  'users=${summary.totalUsers}',
                                              ].join('｜'),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11.5,
                                                height: 1.3,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            if (summary.outcomes.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              for (final outcome
                                                  in summary.outcomes.take(4))
                                                Text(
                                                  '• ${outcome.title ?? outcome.id ?? 'outcome'}'
                                                  '${outcome.points == null ? '' : '｜${outcome.points} 點'}'
                                                  '${outcome.users == null ? '' : '｜${outcome.users} 人'}'
                                                  '${outcome.odds == null ? '' : '｜${outcome.odds}'}'
                                                  '${outcome.winner == true ? '｜WIN' : ''}',
                                                  style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 11.5,
                                                    height: 1.3,
                                                  ),
                                                ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                            logs.isEmpty
                                ? const Center(
                                    child: Text(
                                      '沒有 log',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(10),
                                    itemCount: logs.length,
                                    itemBuilder: (context, index) {
                                      return SelectableText(
                                        logs[index],
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          height: 1.3,
                                          fontFamily: 'monospace',
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
        },
      );
    },
  );
}
