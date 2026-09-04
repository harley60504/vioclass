import 'package:flutter/material.dart';

import '../localization/vioclass_localizations.dart';

enum TwitchHomeSection { following, browse }

extension TwitchHomeSectionUi on TwitchHomeSection {
  String get label {
    switch (this) {
      case TwitchHomeSection.following:
        return '追隨';
      case TwitchHomeSection.browse:
        return '瀏覽';
    }
  }

  String localizedLabel(BuildContext context) {
    return context.vio.t(label);
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
