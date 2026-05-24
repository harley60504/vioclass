// PATCH VERSION: twitch_channel_points_sheet_body_stage169
//
// Main body content for the Channel Points sheet. The parent sheet keeps the
// redeem / emote-overlay state machine; this file owns banners, claim button,
// empty state, and reward grid layout.

import 'package:flutter/material.dart';

import '../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../../widgets/channel_points/twitch_channel_points_sheet_utils.dart';
import '../../widgets/channel_points/twitch_channel_points_sheet_widgets.dart';

class TwitchChannelPointsSheetBody extends StatelessWidget {
  final TwitchChannelPointsRuntimeSnapshot? snapshot;
  final bool loading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String claimId) onClaim;
  final Future<void> Function(Map<String, dynamic> reward) onRewardTap;

  const TwitchChannelPointsSheetBody({
    super.key,
    required this.snapshot,
    required this.loading,
    required this.onRefresh,
    required this.onClaim,
    required this.onRewardTap,
  });

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    final balance = current?.balance;
    final claimId = current?.availableClaimId;
    final claimPoints = current?.availableClaimPoints ?? 0;
    final rewards = sortChannelPointRewards(
      current?.rewards ?? const <Map<String, dynamic>>[],
      balance: balance,
    );

    return Column(
      children: [
        if (current != null && current.contextError != null)
          ChannelPointsErrorBanner(
            message: current.contextError!,
            label: 'Balance',
          ),
        if (current != null && current.rewardsError != null)
          ChannelPointsErrorBanner(
            message: current.rewardsError!,
            label: 'Rewards',
          ),
        if (claimId != null && claimId.isNotEmpty)
          TwitchChannelPointsClaimButton(
            loading: loading,
            claimId: claimId,
            claimPoints: claimPoints,
            onClaim: onClaim,
          ),
        Expanded(
          child: rewards.isEmpty
              ? ChannelPointsEmptyRewards(
                  hasSnapshot: current != null,
                  onRefresh: onRefresh,
                  loading: loading,
                )
              : TwitchChannelPointsRewardGrid(
                  rewards: rewards,
                  balance: balance,
                  pointsIconUrl: current?.pointsIconUrl,
                  onRewardTap: onRewardTap,
                ),
        ),
      ],
    );
  }
}

class TwitchChannelPointsClaimButton extends StatelessWidget {
  final bool loading;
  final String claimId;
  final int claimPoints;
  final Future<void> Function(String claimId) onClaim;

  const TwitchChannelPointsClaimButton({
    super.key,
    required this.loading,
    required this.claimId,
    required this.claimPoints,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: loading ? null : () async => onClaim(claimId),
          icon: const Icon(Icons.card_giftcard_rounded),
          label: Text(claimPoints > 0 ? '領取 $claimPoints 點忠誠點數' : '領取可用忠誠點數獎勵'),
          style: ElevatedButton.styleFrom(
            backgroundColor: TwitchUiColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

class TwitchChannelPointsRewardGrid extends StatelessWidget {
  final List<Map<String, dynamic>> rewards;
  final int? balance;
  final String? pointsIconUrl;
  final Future<void> Function(Map<String, dynamic> reward) onRewardTap;

  const TwitchChannelPointsRewardGrid({
    super.key,
    required this.rewards,
    required this.balance,
    required this.pointsIconUrl,
    required this.onRewardTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 520
            ? 3
            : 2;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          itemCount: rewards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: constraints.maxWidth < 420
                ? 232
                : constraints.maxWidth < 760
                ? 224
                : 216,
          ),
          itemBuilder: (context, index) {
            final reward = rewards[index];

            return ChannelPointsRewardTile(
              reward: reward,
              balance: balance,
              pointsIconUrl: pointsIconUrl,
              onTap: () => onRewardTap(reward),
            );
          },
        );
      },
    );
  }
}
