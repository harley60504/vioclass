// PATCH VERSION: twitch_watch_composition_root_stage186e
//
// Watch composition root.
//
// This widget owns Watch feature dependencies and exposes both service groups
// and narrow feature ports to the subtree. WatchPage can then become a layout
// and route-lifecycle composer while Player / Chat / Emote / Engagement /
// Relationship widgets consume their own ports.

import 'package:flutter/widgets.dart';

import '../../services/watch/twitch_watch_services.dart';
import 'twitch_watch_feature_ports.dart';
import 'twitch_watch_port_scope.dart';
import 'twitch_watch_scope.dart';

class TwitchWatchCompositionRoot extends StatefulWidget {
  final Widget child;
  final String playerTitle;

  const TwitchWatchCompositionRoot({
    super.key,
    required this.child,
    this.playerTitle = 'Twitch Raw Proxy',
  });

  @override
  State<TwitchWatchCompositionRoot> createState() =>
      _TwitchWatchCompositionRootState();
}

class _TwitchWatchCompositionRootState extends State<TwitchWatchCompositionRoot> {
  late final TwitchWatchServices _services;
  late final TwitchWatchFeaturePorts _ports;

  @override
  void initState() {
    super.initState();
    _services = TwitchWatchServices.create(playerTitle: widget.playerTitle);
    _ports = TwitchWatchFeaturePorts.fromServices(_services);
  }

  @override
  Widget build(BuildContext context) {
    return TwitchWatchScope(
      services: _services,
      child: TwitchWatchPortScope(
        ports: _ports,
        child: widget.child,
      ),
    );
  }
}
