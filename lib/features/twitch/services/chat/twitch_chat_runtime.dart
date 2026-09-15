import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../api/chat/twitch_irc_api_service.dart';
import '../../api/chat/twitch_recent_messages_api_service.dart';
import '../../models/chat/twitch_chat_badge.dart';
import '../../models/chat/twitch_chat_message.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';
import '../engagement/twitch_prediction_hermes_runtime_service.dart';
import '../../parsers/chat/twitch_chat_message_normalizer.dart';
import './twitch_badge_cache_service.dart';
import './twitch_chat_runtime_notify_batcher.dart';

part 'twitch_chat_runtime_parts/01_twitch_chat_runtime.dart';
part 'twitch_chat_runtime_parts/02_twitch_chat_runtime_messages_ops.dart';
