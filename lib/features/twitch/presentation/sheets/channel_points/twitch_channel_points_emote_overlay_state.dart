// PATCH VERSION: twitch_channel_points_emote_overlay_state_stage173
//
// Immutable state holder for the Channel Points emote overlay. This prevents
// twitch_channel_points_sheet.dart from carrying many independent overlay fields.

import '../../../api/engagement/twitch_channel_points_api_service.dart';
import '../../widgets/channel_points/twitch_channel_points_emote_overlay.dart';
import 'twitch_channel_points_sheet_models.dart';

class TwitchChannelPointsEmoteOverlayState {
  final ChannelPointEmoteOverlayMode? mode;
  final Map<String, dynamic>? reward;
  final List<TwitchChannelPointEmoteOption> emotes;
  final TwitchChannelPointEmoteOption? selectedBaseEmote;
  final bool loading;
  final String? error;
  final String query;

  const TwitchChannelPointsEmoteOverlayState({
    required this.mode,
    required this.reward,
    required this.emotes,
    required this.selectedBaseEmote,
    required this.loading,
    required this.error,
    required this.query,
  });

  const TwitchChannelPointsEmoteOverlayState.hidden()
    : mode = null,
      reward = null,
      emotes = const <TwitchChannelPointEmoteOption>[],
      selectedBaseEmote = null,
      loading = false,
      error = null,
      query = '';

  bool get isVisible => mode != null;

  TwitchChannelPointsEmoteOverlayState opened({
    required ChannelPointEmoteOverlayMode mode,
    required Map<String, dynamic> reward,
  }) {
    return TwitchChannelPointsEmoteOverlayState(
      mode: mode,
      reward: reward,
      emotes: const <TwitchChannelPointEmoteOption>[],
      selectedBaseEmote: null,
      loading: true,
      error: null,
      query: '',
    );
  }

  TwitchChannelPointsEmoteOverlayState reloading() {
    return TwitchChannelPointsEmoteOverlayState(
      mode: mode,
      reward: reward,
      emotes: const <TwitchChannelPointEmoteOption>[],
      selectedBaseEmote: null,
      loading: true,
      error: null,
      query: query,
    );
  }

  TwitchChannelPointsEmoteOverlayState loaded(
    List<TwitchChannelPointEmoteOption> nextEmotes,
  ) {
    return TwitchChannelPointsEmoteOverlayState(
      mode: mode,
      reward: reward,
      emotes: nextEmotes,
      selectedBaseEmote: selectedBaseEmote,
      loading: false,
      error: null,
      query: query,
    );
  }

  TwitchChannelPointsEmoteOverlayState failed(Object error) {
    return TwitchChannelPointsEmoteOverlayState(
      mode: mode,
      reward: reward,
      emotes: emotes,
      selectedBaseEmote: selectedBaseEmote,
      loading: false,
      error: error.toString(),
      query: query,
    );
  }

  TwitchChannelPointsEmoteOverlayState withQuery(String value) {
    return TwitchChannelPointsEmoteOverlayState(
      mode: mode,
      reward: reward,
      emotes: emotes,
      selectedBaseEmote: selectedBaseEmote,
      loading: loading,
      error: error,
      query: value.trim().toLowerCase(),
    );
  }

  TwitchChannelPointsEmoteOverlayState selectBaseEmote(
    TwitchChannelPointEmoteOption emote,
  ) {
    return TwitchChannelPointsEmoteOverlayState(
      mode: mode,
      reward: reward,
      emotes: emotes,
      selectedBaseEmote: emote,
      loading: loading,
      error: error,
      query: '',
    );
  }

  TwitchChannelPointsEmoteOverlayState clearBaseEmote() {
    return TwitchChannelPointsEmoteOverlayState(
      mode: mode,
      reward: reward,
      emotes: emotes,
      selectedBaseEmote: null,
      loading: loading,
      error: error,
      query: '',
    );
  }

  List<TwitchChannelPointEmoteOption> visibleEmotes() {
    return filterChannelPointOverlayEmotes(
      mode: mode,
      emotes: emotes,
      selectedBaseEmote: selectedBaseEmote,
      query: query,
    );
  }
}
