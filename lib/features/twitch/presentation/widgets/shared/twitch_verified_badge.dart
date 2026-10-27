import 'package:flutter/material.dart';

import '../../localization/vioclass_localizations.dart';

class TwitchVerifiedBadge extends StatelessWidget {
  final double size;

  const TwitchVerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.vio.isEnglish ? 'Verified' : '已認證',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.verified_rounded,
              color: const Color(0xFF9146FF),
              size: size,
            ),
            Icon(Icons.check_rounded, color: Colors.white, size: size * 0.62),
          ],
        ),
      ),
    );
  }
}
