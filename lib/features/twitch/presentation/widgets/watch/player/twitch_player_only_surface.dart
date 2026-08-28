import 'package:flutter/material.dart';

class TwitchPlayerOnlySurface extends StatelessWidget {
  final Widget player;
  final BoxFit fit;
  final double aspectRatio;

  const TwitchPlayerOnlySurface({
    super.key,
    required this.player,
    this.fit = BoxFit.contain,
    this.aspectRatio = 16 / 9,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: fit == BoxFit.contain
            ? player
            : FittedBox(
                fit: fit,
                child: SizedBox(width: aspectRatio, height: 1, child: player),
              ),
      ),
    );
  }
}
