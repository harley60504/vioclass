import 'package:flutter/material.dart';

import '../../models/engagement/twitch_hype_train.dart';

Future<void> showTwitchHypeTrainSheet({
  required BuildContext context,
  required TwitchHypeTrainSnapshot snapshot,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF18181B),
    showDragHandle: true,
    builder: (context) => TwitchHypeTrainSheet(snapshot: snapshot),
  );
}

class TwitchHypeTrainSheet extends StatelessWidget {
  final TwitchHypeTrainSnapshot snapshot;

  const TwitchHypeTrainSheet({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '發燒列車',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _InfoRow(label: 'Level', value: '${snapshot.level}'),
            _InfoRow(label: 'Total', value: '${snapshot.total}'),
            _InfoRow(
              label: 'Progress',
              value: '${snapshot.progress} / ${snapshot.goal}',
            ),
            _InfoRow(label: 'Started', value: _formatDate(snapshot.startedAt)),
            _InfoRow(label: 'Expires', value: _formatDate(snapshot.expiresAt)),
            _InfoRow(label: 'Ended', value: _formatDate(snapshot.endedAt)),
            _InfoRow(
              label: 'Cooldown',
              value: _formatDate(snapshot.cooldownEndsAt),
            ),
            _InfoRow(label: 'Type', value: snapshot.type),
            _InfoRow(
              label: 'Shared Train',
              value: snapshot.isSharedTrain ? 'Yes' : 'No',
            ),
            const SizedBox(height: 16),
            _SectionTitle('Top Contributions'),
            if (snapshot.topContributions.isEmpty)
              const _EmptyText('目前沒有貢獻資料')
            else
              for (final contribution in snapshot.topContributions)
                _InfoRow(
                  label: contribution.displayName.isNotEmpty
                      ? contribution.displayName
                      : contribution.userLogin,
                  value: '${contribution.amount} ${contribution.type}',
                ),
            const SizedBox(height: 16),
            _SectionTitle('Shared Train Participants'),
            if (snapshot.sharedTrainParticipants.isEmpty)
              const _EmptyText('目前沒有共享列車參與者')
            else
              for (final participant in snapshot.sharedTrainParticipants)
                _InfoRow(
                  label: participant.displayName.isNotEmpty
                      ? participant.displayName
                      : participant.channelLogin,
                  value:
                      'Lv.${participant.level} '
                      '${participant.progress} / ${participant.goal}',
                ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return value.toLocal().toString();
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;

  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.54),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
