import 'package:flutter/material.dart';

import 'twitch_emote_picker_flow.dart';

const twitchPickerEmoji = ['😀', '😂', '😊', '❤️', '👍', '🎉', '🙏', '😢'];

class TwitchEmojiPicker extends StatelessWidget {
  final String query;
  final ValueChanged<String> onSelected;
  const TwitchEmojiPicker({
    super.key,
    required this.query,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final values = twitchPickerEmoji
        .where((value) => value.contains(query))
        .toList();
    return TwitchEmotePickerFlow(
      itemCount: values.length,
      itemBuilder: (_, index) {
        final value = values[index];
        return TwitchEmotePickerTile(
          id: value,
          name: value,
          imageUrl: '',
          showName: false,
          onTap: () => onSelected(value),
          image: Text(value, style: const TextStyle(fontSize: 24)),
        );
      },
    );
  }
}
