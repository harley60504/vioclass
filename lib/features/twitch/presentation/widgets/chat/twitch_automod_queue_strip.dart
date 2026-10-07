import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../api/moderation/twitch_moderation_api_service.dart';
import '../../../models/chat/twitch_automod_queue.dart';
import '../../../models/emotes/twitch_cheermote_catalog.dart';
import '../../../services/chat/twitch_automod_eventsub_service.dart';
import '../../localization/vioclass_localizations.dart';
import 'twitch_automod_message_text.dart';

class TwitchAutomodQueueStrip extends StatefulWidget {
  final TwitchModerationApiService api;
  final String channelName;
  final double maxHeight;
  final TwitchAutomodEventSubService Function(
    TwitchModerationApiService api,
    void Function(String, Map<String, dynamic>, DateTime) onMessage,
    void Function(String) onStatus,
  )?
  receiverFactory;
  const TwitchAutomodQueueStrip({
    super.key,
    required this.api,
    required this.channelName,
    this.maxHeight = 200,
    this.receiverFactory,
  });

  @override
  State<TwitchAutomodQueueStrip> createState() =>
      _TwitchAutomodQueueStripState();
}

class _TwitchAutomodQueueStripState extends State<TwitchAutomodQueueStrip> {
  late TwitchAutomodQueue _queue;
  late TwitchAutomodEventSubService _receiver;
  bool _open = false;
  String _status = '';
  String? _error;
  final _busy = <String>{};
  final _submitted = <String>{};
  int _generation = 0;
  TwitchCheermoteCatalog _cheermotes = const TwitchCheermoteCatalog.empty();
  bool _cheerAttempted = false;
  bool _cheerLoading = false;
  bool _cheerFailed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final generation = ++_generation;
    _queue = TwitchAutomodQueue(widget.api.broadcasterId);
    _busy.clear();
    _submitted.clear();
    _error = null;
    _cheermotes = const TwitchCheermoteCatalog.empty();
    _cheerAttempted = _cheerLoading = _cheerFailed = false;
    void receive(String type, Map<String, dynamic> event, DateTime _) {
      if (!mounted || generation != _generation) return;
      final changed = _queue.apply(type, event);
      if (changed) {
        setState(() {
          _submitted.removeWhere((id) => !_queue.contains(id));
        });
        if (!_cheerAttempted &&
            _queue.messages.any(
              (row) => row.fragments.any((part) => part.bits != null),
            )) {
          _loadCheermotes();
        }
      }
    }

    void status(String text) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _status = text;
        if (!_receiver.connected) {
          _queue.clear();
          _submitted.clear();
        }
      });
    }

    _receiver =
        widget.receiverFactory?.call(widget.api, receive, status) ??
        TwitchAutomodEventSubService(
          api: widget.api,
          onMessage: receive,
          onStatus: status,
        );
    _receiver.start();
  }

  Future<void> _loadCheermotes() async {
    if (_cheerLoading || widget.api.canModerate?.call() == false) return;
    final generation = _generation;
    final api = widget.api;
    setState(() {
      _cheerAttempted = _cheerLoading = true;
      _cheerFailed = false;
    });
    try {
      final catalog = await api.automodCheermotes();
      if (!mounted ||
          generation != _generation ||
          widget.api.canModerate?.call() == false) {
        return;
      }
      setState(() => _cheermotes = catalog);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _cheerFailed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _cheerLoading = false);
      }
    }
  }

  @override
  void didUpdateWidget(covariant TwitchAutomodQueueStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api.broadcasterId != widget.api.broadcasterId ||
        oldWidget.api.moderatorId != widget.api.moderatorId) {
      _receiver.stop();
      _open = false;
      _start();
    }
  }

  @override
  void dispose() {
    ++_generation;
    _receiver.stop();
    super.dispose();
  }

  Future<void> _resolve(TwitchHeldAutomodMessage row, bool allow) async {
    if (_busy.contains(row.id) ||
        _submitted.contains(row.id) ||
        !_receiver.connected ||
        !_queue.contains(row.id)) {
      return;
    }
    final generation = _generation;
    final api = widget.api;
    setState(() {
      _busy.add(row.id);
      _error = null;
    });
    try {
      if (api.canModerate?.call() == false) {
        throw const TwitchModerationException('管理身分或頻道已變更，未送出操作。');
      }
      await api.resolveAutomod(row.id, allow: allow);
      if (!mounted || generation != _generation) return;
      // A 204 means submitted. Only the official update removes a row.
      if (_queue.contains(row.id)) _submitted.add(row.id);
    } on TwitchModerationException catch (error) {
      if (mounted && generation == _generation) _error = error.message;
    } catch (_) {
      if (mounted && generation == _generation) {
        _error = 'AutoMod 操作結果未確認；請等候官方更新，不要直接重送。';
        _submitted.add(row.id);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy.remove(row.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _queue.messages;
    if (widget.maxHeight < 44 || (_receiver.connected && rows.isEmpty)) {
      return const SizedBox.shrink();
    }
    final permitted = widget.api.canModerate?.call() != false;
    final connected = _receiver.connected;
    final height = math.min(widget.maxHeight, 200.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _open = !_open),
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: Text(
                      connected
                          ? '${context.vio.t('AutoMod 待審')} · ${rows.length}'
                          : context.vio.t(_status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (!connected)
                  IconButton(
                    tooltip: context.vio.t('重新連線'),
                    onPressed: permitted
                        ? () {
                            _receiver.stop();
                            _start();
                          }
                        : null,
                    icon: const Icon(Icons.refresh, size: 18),
                  ),
              ],
            ),
          ),
          if (_open && height > 60)
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  Text(
                    '@${widget.channelName} · ${context.vio.t('只包含連線後收到的待審訊息；斷線期間不會補回。')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_error != null)
                    Text(
                      context.vio.t(_error!),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  if (_cheerLoading) Text(context.vio.t('Bits 圖片載入中，原文字仍保留。')),
                  if (_cheerFailed)
                    TextButton(
                      onPressed: permitted ? _loadCheermotes : null,
                      child: Text(context.vio.t('Bits 圖片載入失敗，按此重試；原文字仍保留。')),
                    ),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row.userName} · ${row.reason}',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          TwitchAutomodMessageText(
                            message: row,
                            cheermotes: _cheermotes,
                          ),
                          if (row.boundaries.isNotEmpty)
                            Text(
                              '${context.vio.t('官方命中位置（從 0 起，含結尾）')}：${row.boundaries.map((range) => '${range.$1}–${range.$2}').join('、')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (_submitted.contains(row.id))
                            Text(context.vio.t('已送出，等待官方審核更新')),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed:
                                    permitted &&
                                        connected &&
                                        !_busy.contains(row.id) &&
                                        !_submitted.contains(row.id)
                                    ? () => _resolve(row, true)
                                    : null,
                                icon: const Icon(Icons.check, size: 18),
                                label: Text(context.vio.t('允許訊息')),
                              ),
                              TextButton.icon(
                                onPressed:
                                    permitted &&
                                        connected &&
                                        !_busy.contains(row.id) &&
                                        !_submitted.contains(row.id)
                                    ? () => _resolve(row, false)
                                    : null,
                                icon: const Icon(Icons.close, size: 18),
                                label: Text(context.vio.t('拒絕訊息')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
