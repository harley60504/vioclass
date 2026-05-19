import 'package:flutter/material.dart';

class PlayerErrorCard extends StatelessWidget {
  final String message;

  const PlayerErrorCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.36)),
      ),
      child: SelectableText(
        message,
        style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
      ),
    );
  }
}
