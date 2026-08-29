import 'package:flutter/material.dart';

import '../../theme/twitch_ui_tokens.dart';

const Color _kPanel = Color(0xCC15121F);

class TwitchStreamHomeSidebar extends StatelessWidget {
  final String viewerLabel;
  final String loginStatus;
  final bool loadingLoginState;

  const TwitchStreamHomeSidebar({
    super.key,
    required this.viewerLabel,
    required this.loginStatus,
    required this.loadingLoginState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      decoration: BoxDecoration(
        color: _kPanel,
        border: Border(
          right: BorderSide(
            color: TwitchUiColors.primary.withValues(alpha: 0.24),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
            color: TwitchUiColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Twitch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  viewerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    loadingLoginState ? '檢查中' : loginStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 18),
              children: <Widget>[const _SidebarHomeBadge()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarHomeBadge extends StatelessWidget {
  const _SidebarHomeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: TwitchUiColors.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TwitchUiColors.primarySoft.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.home_rounded, color: TwitchUiColors.primarySoft, size: 21),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '首頁',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
