import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/chat/twitch_chat_user_profile_api_service.dart';
import '../../api/chat/twitch_chat_user_public_profile_api_service.dart';
import '../../api/chat/twitch_chat_user_appearance_api_service.dart';
import '../../models/chat/twitch_chat_badge.dart';
import '../../models/channel/twitch_user.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../localization/vioclass_localizations.dart';
import '../widgets/chat/message/twitch_chat_mention.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

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
  Future<TwitchChatUserFollowInfo> Function()? loadFollowInfo,
  Future<TwitchChatUserPublicProfile?> Function()? loadPublicProfile,
  Future<TwitchChatUserAppearance?> Function()? loadAppearance,
  required bool canWhisper,
  String? cacheKey,
  String? viewerLogin,
  Widget Function(BuildContext, TwitchChatRuntimeMessage)? messageActionBuilder,
  Widget? moderationActions,
  TwitchThirdPartyEmoteCacheService? thirdPartyEmotes,
  TwitchOfficialEmoteCacheService? officialEmotes,
}) => showTwitchResponsiveSheet<bool>(
  context: context,
  maxWidth: 560,
  backgroundColor: const Color(0xFF09090B),
  builder: (_) => TwitchChatMentionScope(
    viewerLogin: viewerLogin,
    child: TwitchChatUserProfileCard(
      message: message,
      messages: messages,
      loadUser: loadUser,
      loadFollowInfo: loadFollowInfo,
      loadPublicProfile: loadPublicProfile,
      loadAppearance: loadAppearance,
      canWhisper: canWhisper,
      cacheKey: cacheKey,
      messageActionBuilder: messageActionBuilder,
      moderationActions: moderationActions,
      thirdPartyEmotes: thirdPartyEmotes,
      officialEmotes: officialEmotes,
    ),
  ),
);

class TwitchChatUserProfileCard extends StatefulWidget {
  final String? cacheKey;
  final TwitchChatRuntimeMessage message;
  final List<TwitchChatRuntimeMessage> messages;
  final Future<TwitchUser?> Function() loadUser;
  final Future<TwitchChatUserFollowInfo> Function()? loadFollowInfo;
  final Future<TwitchChatUserPublicProfile?> Function()? loadPublicProfile;
  final Future<TwitchChatUserAppearance?> Function()? loadAppearance;
  final bool canWhisper;
  final Widget Function(BuildContext, TwitchChatRuntimeMessage)?
  messageActionBuilder;
  final Widget? moderationActions;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  const TwitchChatUserProfileCard({
    super.key,
    this.cacheKey,
    required this.message,
    required this.messages,
    required this.loadUser,
    this.loadFollowInfo,
    this.loadPublicProfile,
    this.loadAppearance,
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
  static final _cache = <String, _ProfileSnapshot>{};
  bool _loadingProfile = true;
  int _profileGeneration = 0;
  TwitchUser? _user;
  bool _loading = true;
  String? _error;
  int _generation = 0;
  int? _badgeIndex;
  TwitchChatUserFollowInfo _followInfo =
      const TwitchChatUserFollowInfo.unknown();
  bool _loadingFollow = false;
  TwitchChatUserPublicProfile? _publicProfile;
  TwitchChatUserAppearance? _appearance;
  bool _loadingAppearance = false;
  List<TwitchChatBadge> get _allBadges => [
    ...widget.message.resolvedBadges,
    ...?_appearance?.earnedBadges,
    ...?_appearance?.sevenTvBadges,
    ...?_appearance?.externalBadges.values.expand((badges) => badges),
  ];
  void _showBadge(int index) => setState(() => _badgeIndex = index);

  Widget _badgeImage(String url, double size) {
    final placeholder = Icon(Icons.shield_outlined, size: size);
    if (url.isEmpty) return placeholder;
    if (Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') == true) {
      return SvgPicture.network(
        url,
        width: size,
        height: size,
        placeholderBuilder: (_) => placeholder,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => placeholder,
    );
  }

  Widget _badgeViewer() {
    final badges = _allBadges;
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
                  child: _badgeImage(image, 96),
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
    final cached = _cache[widget.cacheKey];
    if (cached != null && DateTime.now().difference(cached.loadedAt) < const Duration(minutes: 1)) {
      _user = cached.user;
      _appearance = cached.appearance;
      _publicProfile = cached.publicProfile;
      _followInfo = cached.followInfo;
      _loading = false;
      _loadingProfile = false;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final generation = ++_profileGeneration;
    setState(() => _loadingProfile = true);
    await Future.wait([
      _load(),
      _loadFollow(),
      _loadPublicProfile(),
      _loadAppearance(),
    ]);
    if (!mounted || generation != _profileGeneration) return;
    final key = widget.cacheKey;
    if (key != null && (_user != null || _appearance?.user != null || _publicProfile?.user != null)) {
      _cache.removeWhere((_, entry) => DateTime.now().difference(entry.loadedAt) >= const Duration(minutes: 1));
      _cache.remove(key);
      if (_cache.length >= 64) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = _ProfileSnapshot(_user, _appearance, _publicProfile, _followInfo);
    }
    setState(() => _loadingProfile = false);
  }

  Future<void> _loadAppearance() async {
    final loader = widget.loadAppearance;
    if (loader == null) return;
    setState(() => _loadingAppearance = true);
    try {
      final appearance = await loader().timeout(const Duration(seconds: 8));
      if (mounted && appearance != null) {
        setState(() => _appearance = appearance);
      }
    } catch (_) {
      // Optional public appearance must not block identity or chat history.
    } finally {
      if (mounted) setState(() => _loadingAppearance = false);
    }
  }

  Widget _badgeCollection(String title, List<TwitchChatBadge> badges) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.vio.t(title),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            _profileSection(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final badge in badges)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        key: ValueKey(
                          'profile-owned-badge-${badge.id}-${badge.version}',
                        ),
                        tooltip: badge.title,
                        padding: const EdgeInsets.all(4),
                        onPressed: () => _showBadge(_allBadges.indexOf(badge)),
                        icon: _badgeImage(badge.image1x, 24),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _paintLabel(TwitchChatNamePaint paint) {
    final colors = paint.colors
        .map((hex) {
          final text = hex.replaceFirst('#', '');
          final value = int.tryParse(
            text.length >= 6 ? text.substring(0, 6) : '',
            radix: 16,
          );
          return value == null ? null : Color(0xFF000000 | value);
        })
        .whereType<Color>()
        .toList();
    final name = Text(
      paint.name,
      style: TextStyle(color: colors.length == 1 ? colors.first : Colors.white),
    );
    if (colors.length < 2) return name;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          LinearGradient(colors: colors).createShader(bounds),
      child: name,
    );
  }

  Widget _namePaints() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.vio.t('7TV 名稱樣式'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        _profileSection(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final paint in _appearance!.paints)
                Chip(
                  avatar: paint.active
                      ? const Icon(Icons.check_circle_outline, size: 16)
                      : null,
                  label: _paintLabel(paint),
                  backgroundColor: paint.active
                      ? const Color(0xFF302544)
                      : null,
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _loadPublicProfile() async {
    final loader = widget.loadPublicProfile;
    if (loader == null) return;
    try {
      final info = await loader().timeout(const Duration(seconds: 8));
      if (!mounted || info == null) return;
      setState(() => _publicProfile = info);
    } catch (_) {
      // A missing optional source does not block the profile or local history.
    }
  }

  Future<void> _loadFollow() async {
    final loader = widget.loadFollowInfo;
    if (loader == null) return;
    setState(() => _loadingFollow = true);
    var info = const TwitchChatUserFollowInfo.unknown();
    try {
      info = await loader().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Relationship metadata is optional; keep identity and history usable.
    }
    if (!mounted) return;
    setState(() {
      _followInfo = info;
      _loadingFollow = false;
    });
  }

  String _dateLabel(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    final age = days < 1 ? context.vio.t('今天') : '$days ${context.vio.t('天前')}';
    return '${date.toLocal().toIso8601String().split('T').first}\n$age';
  }

  Widget _statRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            context.vio.t(label),
            style: const TextStyle(color: Color(0xFFAAC0C8)),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(flex: 2, child: Text(value, textAlign: TextAlign.right)),
      ],
    ),
  );

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await widget.loadUser().timeout(const Duration(seconds: 8));
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
            : '使用者資料暫時載入失敗，請稍後再試。',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final user = _user ?? _appearance?.user ?? _publicProfile?.user;
    final createdAt =
        _user?.createdAt ??
        _appearance?.user?.createdAt ??
        _publicProfile?.user?.createdAt;
    final profileImage = _appearance?.sevenTvAvatar.isNotEmpty == true
        ? _appearance!.sevenTvAvatar
        : _user?.profileImageUrl.isNotEmpty == true
        ? _user!.profileImageUrl
        : _appearance?.user?.profileImageUrl ??
              _publicProfile?.user?.profileImageUrl ??
              '';
    final description = _user?.description.isNotEmpty == true
        ? _user!.description
        : _appearance?.user?.description ??
              _publicProfile?.user?.description ??
              '';
    final followDate = _followInfo.followedAt ?? _publicProfile?.followedAt;
    final followKnown =
        _followInfo.known || _publicProfile?.followKnown == true;
    final t = context.vio.t;
    final name = user?.displayName ?? message.displayName;
    final colorHex =
        (_appearance?.chatColor.isNotEmpty == true
                ? _appearance!.chatColor
                : message.color)
            .replaceFirst('#', '');
    final colorValue = colorHex.length == 6
        ? int.tryParse(colorHex, radix: 16)
        : null;
    final badges = message.resolvedBadges;
    final subscriptionMonths =
        _publicProfile?.cumulativeMonths ?? _subscriptionMonths();
    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 26,
          child: profileImage.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    profileImage,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.person),
                  ),
                )
              : const Icon(Icons.person),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? message.userLogin : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colorValue == null
                      ? Theme.of(context).colorScheme.primary
                      : Color(0xFF000000 | colorValue),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@${user?.login ?? message.userLogin}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFAAC0C8)),
              ),
            ],
          ),
        ),
      ],
    );
    final whisperAction = OutlinedButton.icon(
      key: const ValueKey('profile-whisper-action'),
      onPressed: widget.canWhisper ? () => Navigator.pop(context, true) : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: const Icon(Icons.chat_bubble_outline, size: 16),
      label: Text(t('私訊')),
    );
    final actions = Wrap(
      key: const ValueKey('profile-actions-and-badges'),
      spacing: 4,
      runSpacing: 4,
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
                padding: const EdgeInsets.all(4),
                onPressed: () => _showBadge(_allBadges.indexOf(badge)),
                icon: badge.image1x.isEmpty
                    ? const Icon(Icons.shield_outlined, size: 24)
                    : Image.network(
                        badge.image1x,
                        width: 24,
                        height: 24,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.shield_outlined, size: 24),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
    return TwitchUnifiedSheetScaffold(
      title: t('使用者資料'),
      icon: Icons.person_outline,
      showRefresh: false,
      trailing: [whisperAction],
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_loadingProfile)
            const Padding(
              key: ValueKey('profile-loading'),
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child:
                  _appearance?.bannerUrl.isNotEmpty == true ||
                      user?.offlineImageUrl.isNotEmpty == true
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              _appearance?.bannerUrl.isNotEmpty == true
                                  ? _appearance!.bannerUrl
                                  : user!.offlineImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.35),
                                    Colors.black.withValues(alpha: 0.85),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 18,
                            ),
                            child: identity,
                          ),
                        ],
                      ),
                    )
                  : identity,
            ),
            if (_badgeIndex != null)
              _badgeViewer()
            else ...[
              if (_loading) const LinearProgressIndicator(),
              if (_error != null &&
                  _publicProfile?.user == null &&
                  _appearance?.user == null &&
                  !_loadingAppearance) ...[
                Text(t(_error!)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _loading ? null : _loadProfile,
                    icon: const Icon(Icons.refresh),
                    label: Text(t('重試')),
                  ),
                ),
              ],
              if (description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(description),
                ),
              if (createdAt != null ||
                  _loadingFollow ||
                  followKnown ||
                  _publicProfile?.followHidden == true ||
                  subscriptionMonths != null ||
                  _publicProfile?.streakMonths != null ||
                  _publicProfile?.subscribed != null ||
                  _publicProfile?.lastBroadcastAt != null ||
                  _publicProfile?.followers != null ||
                  _publicProfile?.follows != null ||
                  _publicProfile?.chatterCount != null ||
                  _publicProfile?.modSince != null ||
                  _publicProfile?.vipSince != null ||
                  _publicProfile?.banned == true ||
                  _publicProfile?.founder == true ||
                  colorValue != null)
                _profileSection(
                  child: Column(
                    children: [
                      if (createdAt case final DateTime created)
                        _statRow('帳號建立日期', _dateLabel(created)),
                      if (_loadingFollow ||
                          followKnown ||
                          _publicProfile?.followHidden == true)
                        _statRow(
                          '追隨此頻道',
                          _loadingFollow
                              ? t('載入中…')
                              : !_followInfo.known &&
                                    _publicProfile?.followHidden == true
                              ? t('已隱藏')
                              : followDate != null
                              ? _dateLabel(followDate)
                              : t('未追隨'),
                        ),
                      if (subscriptionMonths != null)
                        _statRow('訂閱月數', '$subscriptionMonths ${t('個月')}'),
                      if (_publicProfile?.streakMonths case final int months)
                        _statRow('連續訂閱', '$months ${t('個月')}'),
                      if (_publicProfile?.subscribed case final bool subscribed)
                        _statRow('訂閱狀態', t(subscribed ? '訂閱中' : '目前未訂閱')),
                      if (_publicProfile?.lastBroadcastAt
                          case final DateTime last)
                        _statRow('最近開台', _dateLabel(last)),
                      if (colorValue != null)
                        Row(
                          children: [
                            Expanded(
                              child: _statRow(
                                '聊天名稱顏色',
                                '#${colorHex.toUpperCase()}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Color(0xFF000000 | colorValue),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      if (_publicProfile?.followers case final int count)
                        _statRow('追隨者', '$count'),
                      if (_publicProfile?.follows case final int count)
                        _statRow('追隨頻道', '$count'),
                      if (_publicProfile?.chatterCount case final int count)
                        _statRow('本人頻道聊天人數', '$count'),
                      if (_publicProfile?.modSince case final DateTime date)
                        _statRow('管理員任命', _dateLabel(date)),
                      if (_publicProfile?.vipSince case final DateTime date)
                        _statRow('VIP 任命', _dateLabel(date)),
                      if (_publicProfile?.banned == true)
                        _statRow('帳號狀態', t('已停權')),
                      if (_publicProfile?.founder == true)
                        _statRow('頻道身分', 'Founder'),
                      if (_publicProfile?.subscriptionTier
                          case final String tier)
                        _statRow('訂閱等級', 'Tier $tier'),
                      if (_publicProfile?.subscriptionType
                          case final String type)
                        _statRow('訂閱類型', t(type)),
                      if (_publicProfile?.giftFrom case final String giver)
                        _statRow('贈訂者', giver),
                    ],
                  ),
                ),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(t('徽章'), style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                _profileSection(child: actions),
              ],
              if (_appearance?.earnedBadges.isNotEmpty == true)
                _badgeCollection('Twitch 徽章收藏', _appearance!.earnedBadges),
              if (_appearance?.sevenTvBadges.isNotEmpty == true)
                _badgeCollection('7TV 徽章收藏', _appearance!.sevenTvBadges),
              if (_appearance?.paints.isNotEmpty == true) _namePaints(),
              for (final entry
                  in _appearance?.externalBadges.entries ??
                      const <MapEntry<String, List<TwitchChatBadge>>>[])
                _badgeCollection(entry.key, entry.value),
              if (widget.moderationActions != null) ...[
                const SizedBox(height: 8),
                _profileSection(child: widget.moderationActions!),
              ],
            ],
          ],
        ],
      ),
    );
  }

  int? _subscriptionMonths() {
    final tags = widget.message.source.tags;
    // Shared-chat subscriptions belong to the origin channel, not the host.
    final info = tags['source-room-id'] != null
        ? tags['source-badge-info'] ?? ''
        : tags['badge-info'] ?? '';
    for (final entry in info.split(',')) {
      final parts = entry.split('/');
      if (parts.length == 2 &&
          (parts.first == 'subscriber' || parts.first == 'founder')) {
        final months = int.tryParse(parts.last);
        if (months != null && months > 0) return months;
      }
    }
    return null;
  }

  Widget _profileSection({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF111114),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: child,
  );
}

class _ProfileSnapshot {
  final DateTime loadedAt = DateTime.now();
  final TwitchUser? user;
  final TwitchChatUserAppearance? appearance;
  final TwitchChatUserPublicProfile? publicProfile;
  final TwitchChatUserFollowInfo followInfo;
  _ProfileSnapshot(this.user, this.appearance, this.publicProfile, this.followInfo);
}
