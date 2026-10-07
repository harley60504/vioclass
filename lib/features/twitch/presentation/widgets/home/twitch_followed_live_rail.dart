import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../responsive/twitch_responsive_layout.dart';
import '../shared/twitch_cached_image_layer.dart';

/// Shared homepage/watch shell. Fetches only on wide visible routes, keeps
/// ordering from the follows API, and never persists identities or credentials.
class TwitchFollowedLiveRailShell extends StatefulWidget {
  final Widget child;
  final Future<List<TwitchLiveStream>> Function() loadStreams;
  final Future<void> Function(TwitchLiveStream) onSelect;
  final String? selectedLogin;
  final bool enabled;
  const TwitchFollowedLiveRailShell({
    super.key,
    required this.child,
    required this.loadStreams,
    required this.onSelect,
    this.selectedLogin,
    this.enabled = true,
  });

  @override
  State<TwitchFollowedLiveRailShell> createState() => _RailShellState();
}

class _RailShellState extends State<TwitchFollowedLiveRailShell> {
  List<TwitchLiveStream> streams = const [];
  Timer? timer;
  bool visible = false;
  bool loading = false;
  bool selecting = false;
  bool failed = false;
  bool expanded = false;
  int generation = 0;

  void _setVisible(bool value) {
    if (visible == value) return;
    visible = value;
    timer?.cancel();
    timer = null;
    if (!value) {
      generation++;
      loading = false;
      return;
    }
    final request = generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !visible || request != generation) return;
      unawaited(_refresh());
      timer?.cancel();
      timer = Timer.periodic(const Duration(minutes: 2), (_) {
        if (ModalRoute.of(context)?.isCurrent != false) unawaited(_refresh());
      });
    });
  }

  Future<void> _refresh() async {
    if (!visible || loading) return;
    final request = generation;
    setState(() => loading = true);
    try {
      final result = await widget.loadStreams();
      if (!mounted || request != generation) return;
      setState(() {
        streams = result;
        failed = false;
      });
    } catch (_) {
      if (!mounted || request != generation) return;
      // Don't display another account's old follows after auth fails.
      setState(() {
        streams = const [];
        failed = true;
      });
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant TwitchFollowedLiveRailShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadStreams != widget.loadStreams) {
      generation++;
      loading = false;
      streams = const [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refresh());
      });
    }
  }

  Future<void> _select(TwitchLiveStream stream) async {
    if (selecting ||
        stream.channelLogin == widget.selectedLogin?.toLowerCase()) {
      return;
    }
    setState(() => selecting = true);
    try {
      await widget.onSelect(stream);
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = TwitchResponsiveLayout.fromConstraints(constraints);
      final show =
          widget.enabled &&
          (layout.isDesktop || (layout.isTablet && layout.width >= 760));
      _setVisible(show);
      if (!show) return widget.child;
      return Stack(
        children: [
          Positioned.fill(left: 60, child: widget.child),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: expanded ? 280 : 60,
            child: MouseRegion(
              onEnter: (_) => setState(() => expanded = true),
              onExit: (_) => setState(() => expanded = false),
              child: SizedBox(
                key: const ValueKey('followed-live-rail'),
                child: ColoredBox(
                  color: TwitchUiColors.surfacePanel.withValues(alpha: .85),
                  child: Column(
                    children: [
                      if (failed)
                        SizedBox(
                          height: 48,
                          child: IconButton(
                            tooltip: '無法載入追隨直播，點此重試',
                            onPressed: loading ? null : _refresh,
                            icon: const Icon(Icons.refresh, size: 20),
                          ),
                        ),
                      if (loading) const LinearProgressIndicator(minHeight: 2),
                      Expanded(
                        child: streams.isEmpty
                            ? const Tooltip(
                                message: '目前沒有追隨中的直播',
                                child: Center(
                                  child: Icon(
                                    Icons.tv_off,
                                    size: 20,
                                    color: Colors.white38,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                primary: false,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                itemCount: streams.length,
                                itemBuilder: (_, index) {
                                  final stream = streams[index];
                                  final selected =
                                      stream.channelLogin ==
                                      widget.selectedLogin?.toLowerCase();
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                      horizontal: 6,
                                    ),
                                    child: Tooltip(
                                      message:
                                          '${stream.userName}\n${stream.title}',
                                      triggerMode: TooltipTriggerMode.longPress,
                                      child: Semantics(
                                        button: true,
                                        selected: selected,
                                        label: stream.userName,
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            key: ValueKey(
                                              'live-rail-${stream.userId}',
                                            ),
                                            onTap: selecting || selected
                                                ? null
                                                : () => _select(stream),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: selected
                                                          ? TwitchUiColors
                                                                .primary
                                                          : Colors.transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child:
                                                      TwitchCachedImageLayer.avatar(
                                                        imageUrl: stream
                                                            .profileImageUrl,
                                                        size: 38,
                                                      ),
                                                ),
                                                if (expanded) ...[
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          stream.userName,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                        Text(
                                                          stream.gameName,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Icon(
                                                    Icons.circle,
                                                    size: 8,
                                                    color: Colors.redAccent,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    stream.viewerCount
                                                        .toString()
                                                        .replaceAllMapped(
                                                          RegExp(
                                                            r'(\d)(?=(\d{3})+(?!\d))',
                                                          ),
                                                          (match) =>
                                                              '${match[1]},',
                                                        ),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
