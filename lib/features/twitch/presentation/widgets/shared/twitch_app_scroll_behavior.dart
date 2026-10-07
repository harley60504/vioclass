import 'package:flutter/material.dart';

// Hide automatic desktop scrollbars without changing scroll physics,
// supported input devices or overscroll behavior.
final twitchAppScrollBehavior = const MaterialScrollBehavior().copyWith(
  scrollbars: false,
);
