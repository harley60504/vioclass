import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/playback/twitch_playback_api_service.dart';
import '../../models/playback/twitch_hls_proxy_models.dart';
import '../../models/playback/twitch_m3u8_variant.dart';
import '../../models/playback/twitch_playback.dart';
import '../../parsers/playback/twitch_hls_playlist_parser.dart';
import 'twitch_canonical_playback_clock_registry.dart';
import 'twitch_hls_low_latency_proxy.dart' show TwitchHlsStartupMode;
import 'twitch_live_dvr_bridge_proxy.dart';
import 'twitch_stable_hls_proxy_router.dart';

part 'twitch_playlist_player_runtime_parts/01_twitch_dvr_health_state.dart';
part 'twitch_playlist_player_runtime_parts/02_twitch_playlist_player_runtime.dart';
part 'twitch_playlist_player_runtime_parts/03_twitch_playlist_player_runtime_quality_ops.dart';
part 'twitch_playlist_player_runtime_parts/04_twitch_playlist_player_runtime_dvr_ops.dart';
part 'twitch_playlist_player_runtime_parts/05_playback_candidate.dart';
