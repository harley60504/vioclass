import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../models/discovery/twitch_live_stream.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../localization/vioclass_localizations.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/responsive/twitch_responsive_layout.dart';
import '../widgets/shared/twitch_cached_image_layer.dart';
import '../widgets/shared/twitch_centered_text_field.dart';
import 'twitch_watch_page.dart';

part 'twitch_channel_page_parts/01_channel_media_library_dialog.dart';
part 'twitch_channel_page_parts/02_social_link_section.dart';
part 'twitch_channel_page_parts/03_clip_card.dart';
part 'twitch_channel_page_parts/04_vod_meta_text.dart';
