// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/models/chat/twitch_moderation_log_entry.dart';

Map<String, dynamic> event(String action) => {
  'broadcaster_user_id': '20',
  'moderator_user_id': 'other-mod',
  'moderator_user_login': 'helper',
  'moderator_user_name': 'Helper',
  'action': action,
};

TwitchModerationLogEntry? parse(Map<String, dynamic> value) =>
    TwitchModerationLogEntry.parse(
      id: 'official-event',
      time: DateTime.parse('2026-10-03T12:00:00Z'),
      expectedBroadcasterId: '20',
      event: value,
    );

void main() {
  const expected = [
    'ban',
    'timeout',
    'unban',
    'untimeout',
    'clear',
    'emoteonly',
    'emoteonlyoff',
    'followers',
    'followersoff',
    'uniquechat',
    'uniquechatoff',
    'slow',
    'slowoff',
    'subscribers',
    'subscribersoff',
    'unraid',
    'delete',
    'unvip',
    'vip',
    'raid',
    'add_blocked_term',
    'add_permitted_term',
    'remove_blocked_term',
    'remove_permitted_term',
    'mod',
    'unmod',
    'approve_unban_request',
    'deny_unban_request',
    'warn',
    'shared_chat_ban',
    'shared_chat_timeout',
    'shared_chat_unban',
    'shared_chat_untimeout',
    'shared_chat_delete',
  ];
  test('Every documented v2 action has a classification', () {
    expect(TwitchModerationLogEntry.actions.keys, unorderedEquals(expected));
    for (final action in expected) {
      final value = event(action)..['source_broadcaster_user_id'] = '20';
      final entry = parse(value)!;
      expect(entry.category, isNot(TwitchModerationLogCategory.unknown));
      expect(entry.label, isNotEmpty);
      expect(entry.action, action);
    }
  });
  test('Actor is the performing moderator, not the subscription owner', () {
    final entry = parse(event('clear'))!;
    expect(entry.moderatorId, 'other-mod');
    expect(entry.moderatorLogin, 'helper');
    expect(entry.detailsAvailable, isTrue);
    expect(entry.targetUserId, isNull);
    expect(entry.time.isUtc, isTrue);
  });
  test('Shared source stays separate and missing source is not invented', () {
    final value = event('shared_chat_timeout')
      ..['source_broadcaster_user_id'] = '30'
      ..['shared_chat_timeout'] = {
        'user_id': '40',
        'reason': 'spam',
        'expires_at': '2026-10-03T12:10:00Z',
      }
      ..['timeout'] = {'user_id': 'wrong'};
    final entry = parse(value)!;
    expect(entry.broadcasterId, '20');
    expect(entry.sourceBroadcasterId, '30');
    expect(entry.isSharedChat, isTrue);
    expect(entry.targetUserId, '40');
    value.remove('source_broadcaster_user_id');
    expect(parse(value), isNull);
  });
  test('Malformed identity and another broadcaster are rejected', () {
    for (final field in [
      'broadcaster_user_id',
      'moderator_user_id',
      'action',
    ]) {
      for (final bad in [null, '', 123, <String>[]]) {
        expect(parse(event('clear')..[field] = bad), isNull);
      }
    }
    expect(parse(event('clear')..['broadcaster_user_id'] = '30'), isNull);
  });
  test('Unknown action survives without claiming a known result', () {
    final entry = parse(
      event('future_action')
        ..['future_action'] = {'user_id': '40', 'access_token': 'secret'},
    )!;
    expect(entry.category, TwitchModerationLogCategory.unknown);
    expect(entry.detailsAvailable, isFalse);
    expect(entry.details, isEmpty);
  });
  test('Missing detail never creates a target or reason', () {
    final entry = parse(event('ban'))!;
    expect(entry.detailsAvailable, isFalse);
    expect(entry.targetUserId, isNull);
    expect(entry.details, isEmpty);
  });
  test('Warning and term lists are immutable snapshots', () {
    final rules = ['be kind'];
    final value = event('warn')
      ..['warn'] = {
        'user_id': '40',
        'reason': 'rude',
        'chat_rules_cited': rules,
        'access_token': 'secret',
      };
    final entry = parse(value)!;
    rules.add('new rule');
    expect(entry.details['chat_rules_cited'], ['be kind']);
    expect(entry.details.containsKey('access_token'), isFalse);
    expect(() => entry.details['reason'] = 'changed', throwsUnsupportedError);
    expect(
      () => (entry.details['chat_rules_cited'] as List).add('changed'),
      throwsUnsupportedError,
    );
    final terms = parse(
      event('add_blocked_term')
        ..['automod_terms'] = {
          'action': 'add',
          'list': 'blocked',
          'terms': ['spam'],
          'from_automod': true,
        },
    )!;
    expect(terms.details['terms'], ['spam']);
    expect(terms.details['from_automod'], isTrue);
  });
  test('Unban request uses its documented nested object', () {
    final entry = parse(
      event('deny_unban_request')
        ..['unban_request'] = {
          'user_id': '40',
          'is_approved': false,
          'moderator_message': 'reason',
        },
    )!;
    expect(entry.targetUserId, '40');
    expect(entry.details['is_approved'], isFalse);
  });
  test('Malformed detail values are not stringified or defaulted to zero', () {
    final entry = parse(
      event('timeout')
        ..['timeout'] = {
          'user_id': 40,
          'reason': {},
          'expires_at': 'invalid',
          'chat_rules_cited': ['rule', 1],
          'viewer_count': -1,
        },
    )!;
    expect(entry.details, isEmpty);
    final slow = parse(event('slow')..['slow'] = {'wait_time_seconds': 0})!;
    expect(slow.details['wait_time_seconds'], 0);
    final followers = parse(
      event('followers')..['followers'] = {'follow_duration_minutes': 5},
    )!;
    expect(followers.details['follow_duration_minutes'], 5);
  });
}
