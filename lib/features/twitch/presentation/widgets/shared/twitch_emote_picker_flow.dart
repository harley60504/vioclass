import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'twitch_emote_image.dart';

/// Shared compact, lazily built flow for chat and whispers, without card grids.
class TwitchEmotePickerFlow extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  const TwitchEmotePickerFlow({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final perRow = math.max(
        1,
        ((constraints.maxWidth - 16 + 4) / 52).floor(),
      );
      return ListView.builder(
        primary: false,
        padding: const EdgeInsets.all(8),
        itemCount: (itemCount / perRow).ceil(),
        itemBuilder: (context, row) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (
                var index = row * perRow;
                index < math.min(itemCount, (row + 1) * perRow);
                index++
              )
                itemBuilder(context, index),
            ],
          ),
        ),
      );
    },
  );
}

class TwitchEmotePickerTile extends StatelessWidget {
  final String id, name, imageUrl, staticImageUrl, providerLabel;
  final bool isOfficial, isAnimated, locked, favorite, zeroWidth;
  final VoidCallback? onTap, onLongPress;
  final Widget? image;
  final bool showName;
  const TwitchEmotePickerTile({
    super.key,
    required this.id,
    required this.name,
    required this.imageUrl,
    this.staticImageUrl = '',
    this.providerLabel = '',
    this.isOfficial = false,
    this.isAnimated = false,
    this.locked = false,
    this.favorite = false,
    this.zeroWidth = false,
    this.onTap,
    this.onLongPress,
    this.image,
    this.showName = true,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Tooltip(
      message: name,
      child: Semantics(
        label: name,
        button: true,
        enabled: !locked && onTap != null,
        child: InkWell(
          onTap: locked ? null : onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 48,
            height: 40 + MediaQuery.textScalerOf(context).scale(10) * 1.3,
            child: Stack(
              children: [
                Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: Center(
                        child:
                            image ??
                            TwitchEmoteImage(
                              id: id,
                              name: name,
                              imageUrl: imageUrl,
                              staticImageUrl: staticImageUrl,
                              providerLabel: providerLabel,
                              isOfficial: isOfficial,
                              isAnimated: isAnimated,
                              locked: locked,
                              width: 32,
                              height: 32,
                              memCacheWidth: 64,
                              memCacheHeight: 64,
                            ),
                      ),
                    ),
                    if (showName)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, height: 1.2),
                      ),
                  ],
                ),
                if (favorite)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(Icons.star, size: 12, color: Colors.amber),
                  ),
                if (locked)
                  const Positioned(
                    right: 0,
                    bottom: 16,
                    child: Icon(Icons.lock, size: 12, color: Colors.amber),
                  ),
                if (zeroWidth)
                  const Positioned(
                    left: 0,
                    top: 0,
                    child: Text('ZW', style: TextStyle(fontSize: 8)),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
