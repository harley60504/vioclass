import 'dart:convert';

/// Stage 249 Twitch Drops persisted GQL operation presets.
///
/// These values are compatibility research presets based on the public
/// TwitchDropsMiner operation table. Keep them isolated from production code so
/// they can be replaced when Twitch changes persisted query hashes.
class TwitchDropsGqlOperationsStage249 {
  const TwitchDropsGqlOperationsStage249._();

  static const String inventoryOperationName = 'Inventory';
  static const String inventorySha256 =
      'd86775d0ef16a63a33ad52e80eaff963b2d5b72fada7c991504a57496e1d8e4b';

  static const String campaignsOperationName = 'ViewerDropsDashboard';
  static const String campaignsSha256 =
      '5a4da2ab3d5b47c9f9ce864e727b2cb346af1e3ea8b897fe8f704a97ff017619';

  static const String campaignDetailsOperationName = 'DropCampaignDetails';
  static const String campaignDetailsSha256 =
      '039277bf98f3130929262cc7c6efd9c141ca3749cb6dca442fc8ead9a53f77c1';

  static const String currentDropOperationName = 'DropCurrentSessionContext';
  static const String currentDropSha256 =
      '4d06b702d25d652afb9ef835d2a550031f1cf762b193523a92166f40ea3d142b';

  static const String availableDropsOperationName =
      'DropsHighlightService_AvailableDrops';
  static const String availableDropsSha256 =
      '782dad0f032942260171d2d80a654f88bdd0c5a9dddc392e9bc92218a0f42d20';

  static const String claimDropOperationName = 'DropsPage_ClaimDropRewards';
  static const String claimDropSha256 =
      'a455deea71bdc9015b78eb49f4acfbce8baa7ccbedd28e549bb025bd0f751930';

  static String inventoryJson({bool pretty = true}) {
    return _encode(
      _persisted(
        operationName: inventoryOperationName,
        sha256Hash: inventorySha256,
        variables: const <String, dynamic>{
          'fetchRewardCampaigns': false,
        },
      ),
      pretty: pretty,
    );
  }

  static String campaignsJson({bool pretty = true}) {
    return _encode(
      _persisted(
        operationName: campaignsOperationName,
        sha256Hash: campaignsSha256,
        variables: const <String, dynamic>{
          'fetchRewardCampaigns': false,
        },
      ),
      pretty: pretty,
    );
  }

  static String campaignDetailsJson({
    String channelLoginOrUserId = '130591488',
    String campaignId = '<campaign_id>',
    bool pretty = true,
  }) {
    return _encode(
      _persisted(
        operationName: campaignDetailsOperationName,
        sha256Hash: campaignDetailsSha256,
        variables: <String, dynamic>{
          'channelLogin': channelLoginOrUserId,
          'dropID': campaignId,
        },
      ),
      pretty: pretty,
    );
  }

  static String currentDropJson({
    String channelId = '<channel_id>',
    bool pretty = true,
  }) {
    return _encode(
      _persisted(
        operationName: currentDropOperationName,
        sha256Hash: currentDropSha256,
        variables: <String, dynamic>{
          'channelID': channelId,
          'channelLogin': '',
        },
      ),
      pretty: pretty,
    );
  }

  static String availableDropsJson({
    String channelId = '<channel_id>',
    bool pretty = true,
  }) {
    return _encode(
      _persisted(
        operationName: availableDropsOperationName,
        sha256Hash: availableDropsSha256,
        variables: <String, dynamic>{
          'channelID': channelId,
        },
      ),
      pretty: pretty,
    );
  }

  static String claimDropJson({
    String dropInstanceId = '<drop_instance_id>',
    bool pretty = true,
  }) {
    return _encode(
      _persisted(
        operationName: claimDropOperationName,
        sha256Hash: claimDropSha256,
        variables: <String, dynamic>{
          'input': <String, dynamic>{
            'dropInstanceID': dropInstanceId,
          },
        },
      ),
      pretty: pretty,
    );
  }

  static Map<String, dynamic> _persisted({
    required String operationName,
    required String sha256Hash,
    required Map<String, dynamic> variables,
  }) {
    return <String, dynamic>{
      'operationName': operationName,
      'variables': variables,
      'extensions': <String, dynamic>{
        'persistedQuery': <String, dynamic>{
          'version': 1,
          'sha256Hash': sha256Hash,
        },
      },
    };
  }

  static String _encode(
    Object value, {
    required bool pretty,
  }) {
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return jsonEncode(value);
  }
}
