import 'package:flutter/material.dart';

class TwitchDefaultChannelPointsIcon extends StatelessWidget {
  final double size;

  const TwitchDefaultChannelPointsIcon({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/twitch/default_channel_points.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) {
        return CustomPaint(
          size: Size.square(size),
          painter: _TwitchDefaultChannelPointsIconPainter(),
        );
      },
    );
  }
}

class _TwitchDefaultChannelPointsIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.16
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE7F7FF);

    canvas.drawCircle(center, radius * 0.62, paint);
    canvas.drawCircle(center, radius * 0.28, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
