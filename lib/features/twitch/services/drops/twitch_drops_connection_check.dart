import 'dart:convert';

import 'twitch_drops_snapshot.dart';

class TwitchDropsConnectionCheck {
  final bool hasToken;
  final bool tokenValid;
  final String clientId;

  final int? inventoryStatusCode;
  final bool inventoryHasErrors;
  final String inventoryRootSummary;
  final String inventoryPreview;

  final int? campaignsStatusCode;
  final bool campaignsHasErrors;
  final String campaignsRootSummary;
  final String campaignsPreview;

  final TwitchDropsSnapshot? snapshot;
  final String? errorText;
  final DateTime checkedAt;

  const TwitchDropsConnectionCheck({
    required this.hasToken,
    required this.tokenValid,
    required this.clientId,
    required this.inventoryStatusCode,
    required this.inventoryHasErrors,
    required this.inventoryRootSummary,
    required this.inventoryPreview,
    required this.campaignsStatusCode,
    required this.campaignsHasErrors,
    required this.campaignsRootSummary,
    required this.campaignsPreview,
    required this.snapshot,
    required this.errorText,
    required this.checkedAt,
  });

  bool get inventoryOk {
    final code = inventoryStatusCode ?? 0;
    return code >= 200 && code < 300 && !inventoryHasErrors;
  }

  bool get campaignsOk {
    final code = campaignsStatusCode ?? 0;
    return code >= 200 && code < 300 && !campaignsHasErrors;
  }

  bool get connected {
    return hasToken && tokenValid && inventoryOk && campaignsOk;
  }

  String get title {
    if (connected) return 'Drops 連線成功';
    if (!hasToken) return '尚未取得 Drops token';
    if (!tokenValid) return 'Drops token 驗證失敗';
    if (!inventoryOk) return 'Drops inventory 連線失敗';
    if (!campaignsOk) return 'Drops campaigns 連線失敗';
    return 'Drops 連線未完成';
  }

  String get summary {
    return <String>[
      'connected=$connected',
      'hasToken=$hasToken',
      'tokenValid=$tokenValid',
      'clientId=$clientId',
      'inventoryStatusCode=${inventoryStatusCode ?? '-'}',
      'inventoryHasErrors=$inventoryHasErrors',
      'inventoryRoot=$inventoryRootSummary',
      'campaignsStatusCode=${campaignsStatusCode ?? '-'}',
      'campaignsHasErrors=$campaignsHasErrors',
      'campaignsRoot=$campaignsRootSummary',
      if (snapshot != null) 'snapshot:\n${snapshot!.compactSummary}',
      if (errorText != null && errorText!.trim().isNotEmpty) 'error=$errorText',
    ].join('\n');
  }

  String get prettyJson {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(<String, dynamic>{
      'connected': connected,
      'hasToken': hasToken,
      'tokenValid': tokenValid,
      'clientId': clientId,
      'inventoryStatusCode': inventoryStatusCode,
      'inventoryHasErrors': inventoryHasErrors,
      'inventoryRootSummary': inventoryRootSummary,
      'campaignsStatusCode': campaignsStatusCode,
      'campaignsHasErrors': campaignsHasErrors,
      'campaignsRootSummary': campaignsRootSummary,
      'snapshot': snapshot?.toJson(),
      'errorText': errorText,
      'checkedAt': checkedAt.toIso8601String(),
    });
  }
}
