// Small non-widget helpers and model types used by TwitchChannelPointsSheet.
// Keep these outside the sheet file so the sheet can focus on state flow.

import 'dart:async';

import '../../../api/engagement/twitch_channel_points_api_service.dart';
import '../../widgets/channel_points/twitch_channel_points_emote_overlay.dart';

class TwitchChannelPointsModifiedEmoteSelection {
  /// For Modify a Single Emote this should be the final modified emote id
  /// returned by the Channel Points emote source, for example `1022569_BW`.
  final String emoteId;

  /// UI metadata only. The API sends [emoteId] as the mutation emoteID.
  final String modifierId;

  const TwitchChannelPointsModifiedEmoteSelection({
    required this.emoteId,
    required this.modifierId,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'emoteId': emoteId, 'modifierId': modifierId};
  }
}

typedef TwitchChannelPointEmoteLoader =
    Future<List<TwitchChannelPointEmoteOption>> Function(
      Map<String, dynamic> reward,
    );

class TwitchChannelPointEmoteCompleter {
  final Completer<Object?> _completer = Completer<Object?>();

  bool get isCompleted => _completer.isCompleted;
  Future<Object?> get future => _completer.future;
  void complete(Object? value) => _completer.complete(value);
}

List<TwitchChannelPointEmoteOption> filterChannelPointOverlayEmotes({
  required ChannelPointEmoteOverlayMode? mode,
  required List<TwitchChannelPointEmoteOption> emotes,
  required TwitchChannelPointEmoteOption? selectedBaseEmote,
  required String query,
  int limit = 240,
}) {
  Iterable<TwitchChannelPointEmoteOption> output = emotes;
  final cleanQuery = query.trim().toLowerCase();

  if (cleanQuery.isNotEmpty) {
    output = output.where((emote) {
      return emote.token.toLowerCase().contains(cleanQuery);
    });
  }

  return output.take(limit).toList(growable: false);
}
