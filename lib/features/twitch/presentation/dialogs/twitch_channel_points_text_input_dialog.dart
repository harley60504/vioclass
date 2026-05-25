import 'package:flutter/material.dart';

import '../widgets/responsive/twitch_responsive_sheet.dart';

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String label;
  final String hintText;
  final String confirmLabel;
  final int minLines;
  final int maxLines;

  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.hintText,
    required this.confirmLabel,
    required this.minLines,
    required this.maxLines,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            textInputAction: widget.maxLines == 1 ? TextInputAction.done : null,
            onSubmitted: widget.maxLines == 1
                ? (_) => Navigator.of(context).pop(_controller.text)
                : null,
            style: const TextStyle(color: Colors.white),
            cursorColor: const Color(0xFFBF94FF),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hintText,
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0E0E10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2D2D35)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF9146FF)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9146FF),
                  foregroundColor: Colors.white,
                ),
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<String?> askChannelPointTextInput({
  required BuildContext context,
  required String title,
  required String label,
  required String hintText,
  required String confirmLabel,
  int minLines = 1,
  int maxLines = 1,
}) {
  return showTwitchResponsiveSheet<String>(
    context: context,
    maxWidth: 460,
    portraitHeightFactor: 0.72,
    builder: (_) => _TextInputDialog(
      title: title,
      label: label,
      hintText: hintText,
      confirmLabel: confirmLabel,
      minLines: minLines,
      maxLines: maxLines,
    ),
  );
}
