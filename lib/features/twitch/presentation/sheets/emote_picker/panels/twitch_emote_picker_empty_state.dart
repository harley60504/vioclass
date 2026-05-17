import 'package:flutter/material.dart';

class TwitchEmotePickerEmptyState extends StatelessWidget {
  final String text;

  const TwitchEmotePickerEmptyState({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white54,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
