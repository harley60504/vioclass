import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_message_context/twitch_reply_thread_builder.dart';

import '../../api/chat/twitch_chat_user_profile_api_service.dart';
import '../../models/channel/twitch_user.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../localization/vioclass_localizations.dart';
import '../widgets/chat/twitch_runtime_message_tile.dart';
import '../widgets/chat/message/twitch_chat_mention.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import '../widgets/shared/twitch_notice.dart';

/// A snapshot of this viewer's loaded messages, not Twitch's remote history.
List<TwitchChatRuntimeMessage> twitchChatUserLocalHistory(
  TwitchChatRuntimeMessage selected,
  List<TwitchChatRuntimeMessage> messages,
) {
  final id = selected.source.tags['user-id'];
  String origin(TwitchChatRuntimeMessage m) =>
      m.metadata.sourceRoomId ?? m.source.tags['room-id'] ?? '';
  final seen = <String>{};
  final result = <TwitchChatRuntimeMessage>[];
  for (final m in [...messages, selected]) {
    final sameUser = id != null && id.isNotEmpty
        ? m.source.tags['user-id'] == id
        : m.userLogin.toLowerCase() == selected.userLogin.toLowerCase();
    if (sameUser &&
        m.channel.toLowerCase() == selected.channel.toLowerCase() &&
        origin(m) == origin(selected) &&
        seen.add(m.id)) {
      result.add(m);
    }
  }
  result.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
  return result;
}

/// Returns true only when the user explicitly chooses a private conversation.
Future<bool?> showTwitchChatUserProfileSheet({
  required BuildContext context,
  required TwitchChatRuntimeMessage message,
  required List<TwitchChatRuntimeMessage> messages,
  required Future<TwitchUser?> Function() loadUser,
  required bool canWhisper,
  String? viewerLogin,
  Widget Function(BuildContext, TwitchChatRuntimeMessage)? messageActionBuilder,
  Widget? moderationActions,
  TwitchThirdPartyEmoteCacheService? thirdPartyEmotes,
  TwitchOfficialEmoteCacheService? officialEmotes,
}) => showTwitchResponsiveSheet<bool>(
  context: context,
  builder: (_) => TwitchChatMentionScope(
    viewerLogin: viewerLogin,
    child: TwitchChatUserProfileCard(
      message: message,
      messages: messages,
      loadUser: loadUser,
      canWhisper: canWhisper,
      messageActionBuilder: messageActionBuilder,
      moderationActions: moderationActions,
      thirdPartyEmotes: thirdPartyEmotes,
      officialEmotes: officialEmotes,
    ),
  ),
);

class TwitchChatUserProfileCard extends StatefulWidget {
  final TwitchChatRuntimeMessage message;
  final List<TwitchChatRuntimeMessage> messages;
  final Future<TwitchUser?> Function() loadUser;
  final bool canWhisper;
  final Widget Function(BuildContext, TwitchChatRuntimeMessage)?
  messageActionBuilder;
  final Widget? moderationActions;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  const TwitchChatUserProfileCard({
    super.key,
    required this.message,
    required this.messages,
    required this.loadUser,
    required this.canWhisper,
    this.messageActionBuilder,
    this.moderationActions,
    this.thirdPartyEmotes,
    this.officialEmotes,
  });
  @override
  State<TwitchChatUserProfileCard> createState() => _ProfileState();
}

class _ProfileState extends State<TwitchChatUserProfileCard> {
  bool _showHistory = false;
  TwitchUser? _user;
  bool _loading = true;
  String? _error;
  int _generation = 0;
  int? _badgeIndex;
  void _showBadge(int index) => setState(() => _badgeIndex = index);

  Widget _badgeViewer() {
    final badges = widget.message.resolvedBadges;
    final index = _badgeIndex!;
    final badge = badges[index];
    final image = badge.image4x.isNotEmpty
        ? badge.image4x
        : badge.image2x.isNotEmpty
        ? badge.image2x
        : badge.image1x;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _badgeIndex = null),
            icon: const Icon(Icons.chevron_left),
            label: Text(context.vio.t('返回')),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              tooltip: context.vio.t('上一個徽章'),
              onPressed: index > 0 ? () => _showBadge(index - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  key: const ValueKey('profile-badge-preview'),
                  width: 96,
                  height: 96,
                  child: image.isEmpty
                      ? const Icon(Icons.shield_outlined, size: 80)
                      : Image.network(
                          image,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.shield_outlined, size: 80),
                        ),
                ),
              ),
            ),
            IconButton(
              tooltip: context.vio.t('下一個徽章'),
              onPressed: index + 1 < badges.length
                  ? () => _showBadge(index + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          badge.title.isEmpty ? badge.setId : badge.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await widget.loadUser();
      if (!mounted || generation != _generation) return;
      setState(() {
        _user = user;
        _error = user == null ? '找不到這個 Twitch 帳號。' : null;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(
        () => _error = error is TwitchChatUserProfileException
            ? error.message
            : '官方使用者資料暫時載入失敗；本機紀錄仍可查看。',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _copyMessage(TwitchChatRuntimeMessage message) async {
    final name = message.displayName.isEmpty
        ? message.userLogin
        : message.displayName;
    final text = name.isEmpty ? message.message : '$name: ${message.message}';
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      showTwitchNotice(context, '已複製這則聊天室訊息', tone: TwitchNoticeTone.success);
    } catch (_) {
      if (!mounted) return;
      showTwitchNotice(context, '無法複製訊息，請稍後再試。', tone: TwitchNoticeTone.error);
    }
  }

  Widget _messageRow(TwitchChatRuntimeMessage message, {Widget? actions}) =>
      Padding(
        key: ValueKey('profile-message-${message.id}'),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: context.vio.t('複製這則訊息'),
              child: TwitchRuntimeMessageTile(
                message: message,
                thirdPartyEmotes: widget.thirdPartyEmotes,
                officialEmotes: widget.officialEmotes,
                showTimestamp: true,
                onOpenContext: () => _copyMessage(message),
              ),
            ),
            ?actions,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final history = twitchChatUserLocalHistory(message, widget.messages);
    final thread = TwitchReplyThreadBuilder.build(
      selectedMessage: message,
      messages: widget.messages,
    );
    final t = context.vio.t;
    final name = _user?.displayName ?? message.displayName;
    final colorHex = message.color.replaceFirst('#', '');
    final colorValue = colorHex.length == 6
        ? int.tryParse(colorHex, radix: 16)
        : null;
    final badges = message.resolvedBadges;
    final identity = ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: _user?.profileImageUrl.isNotEmpty == true
            ? ClipOval(
                child: Image.network(
                  _user!.profileImageUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.person),
                ),
              )
            : const Icon(Icons.person),
      ),
      title: Text(
        name.isEmpty ? message.userLogin : name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colorValue == null ? null : Color(0xFF000000 | colorValue),
        ),
      ),
      subtitle: Text(
        '@${_user?.login ?? message.userLogin}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: OutlinedButton.icon(
        onPressed: widget.canWhisper
            ? () => Navigator.pop(context, true)
            : null,
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text(t('私訊')),
      ),
    );
    final actions = Wrap(
      key: const ValueKey('profile-actions-and-badges'),
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...badges.map(
          (badge) => SizedBox(
            width: 32,
            height: 32,
            child: Semantics(
              label: badge.title.isEmpty ? badge.setId : badge.title,
              button: true,
              child: IconButton(
                key: ValueKey('profile-badge-${badge.id}-${badge.version}'),
                tooltip: t('查看徽章'),
                padding: const EdgeInsets.all(6),
                onPressed: () => _showBadge(badges.indexOf(badge)),
                icon: badge.image1x.isEmpty
                    ? const Icon(Icons.shield_outlined, size: 20)
                    : Image.network(
                        badge.image1x,
                        width: 20,
                        height: 20,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.shield_outlined, size: 20),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
    return Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('使用者資料'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: t('關閉'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: identity,
          ),
          if (_badgeIndex != null)
            _badgeViewer()
          else ...[
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(t(_error!)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(t('重試')),
                ),
              ),
            ],
            if (_user?.createdAt case final DateTime created)
              Text(
                '${t('帳號建立日期')}：${created.toLocal().toIso8601String().split('T').first}',
              ),
            if (_user?.description.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_user!.description),
              ),
            ?widget.moderationActions,
            if (badges.isNotEmpty) actions,
            const Divider(),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(t('聊天串')),
                  selected: !_showHistory,
                  onSelected: (_) => setState(() => _showHistory = false),
                ),
                ChoiceChip(
                  label: Text(t('個人聊天紀錄')),
                  selected: _showHistory,
                  onSelected: (_) => setState(() => _showHistory = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_showHistory) ...[
              Text('${t('本機聊天紀錄')} · ${history.length}'),
              Text(
                t('僅包含目前已載入的頻道訊息，不是完整遠端歷史。'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final item in history) _messageRow(item),
            ] else ...[
              for (final entry in thread)
                _messageRow(
                  entry.message,
                  actions: entry.message.id == message.id
                      ? null
                      : widget.messageActionBuilder?.call(
                          context,
                          entry.message,
                        ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
