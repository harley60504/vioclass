import 'package:flutter/material.dart';

class TwitchLoginRequiredView extends StatelessWidget {
  final String statusText;
  final bool loading;
  final VoidCallback onLoginPressed;
  final VoidCallback onRetryPressed;

  const TwitchLoginRequiredView({
    super.key,
    required this.statusText,
    required this.loading,
    required this.onLoginPressed,
    required this.onRetryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E0E10),
      alignment: Alignment.center,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: const [
            BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 34,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFF9146FF).withOpacity(0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.login_rounded,
                color: Color(0xFF9146FF),
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '需要登入 Twitch',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              statusText.trim().isEmpty
                  ? '追隨頁需要 OAuth token。請先完成 Twitch 登入。'
                  : statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: loading ? null : onLoginPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9146FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded),
                  label: const Text(
                    '用 WebView 登入',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: loading ? null : onRetryPressed,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('重新檢查'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
