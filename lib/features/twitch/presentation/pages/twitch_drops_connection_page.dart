import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../services/auth/twitch_auth_service.dart';
import '../../services/auth/twitch_drops_auth_service.dart';
import '../../services/drops/twitch_drops_channel_points_leaderboard_service.dart';
import '../../services/drops/twitch_drops_connection_check.dart';
import '../../services/drops/twitch_drops_connection_service.dart';
import '../../services/drops/twitch_drops_snapshot.dart';
import '../../services/notifications/twitch_app_notification_service.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/responsive/twitch_responsive_layout.dart';

part 'twitch_drops_connection_page_parts/01_k_purple.dart';
part 'twitch_drops_connection_page_parts/02_campaign_games_table.dart';
part 'twitch_drops_connection_page_parts/03_drops_inventory_page.dart';
part 'twitch_drops_connection_page_parts/04_current_drop_status_card.dart';
part 'twitch_drops_connection_page_parts/05_format_date_time.dart';
