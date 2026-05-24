import 'package:flutter/material.dart';

enum TwitchHomeSection {
  following,
  browse,
}

extension TwitchHomeSectionUi on TwitchHomeSection {
  String get label {
    switch (this) {
      case TwitchHomeSection.following:
        return '追隨';
      case TwitchHomeSection.browse:
        return '瀏覽';
    }
  }

  IconData get icon {
    switch (this) {
      case TwitchHomeSection.following:
        return Icons.favorite_rounded;
      case TwitchHomeSection.browse:
        return Icons.explore_rounded;
    }
  }
}
