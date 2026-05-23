import 'dart:convert';

class TwitchDropsQueryPresetsStage249 {
  const TwitchDropsQueryPresetsStage249._();

  static String inventoryJson({bool pretty = false}) {
    return _encode(
      const <String, dynamic>{
        'operationName': 'Inventory',
        'variables': <String, dynamic>{
          'fetchRewardCampaigns': false,
        },
        'extensions': <String, dynamic>{
          'persistedQuery': <String, dynamic>{
            'version': 1,
            'sha256Hash':
                'd86775d0ef16a63a33ad52e80eaff963b2d5b72fada7c991504a57496e1d8e4b',
          },
        },
      },
      pretty: pretty,
    );
  }

  static String campaignsJson({bool pretty = false}) {
    return _encode(
      const <String, dynamic>{
        'operationName': 'ViewerDropsDashboard',
        'variables': <String, dynamic>{
          'fetchRewardCampaigns': false,
        },
        'extensions': <String, dynamic>{
          'persistedQuery': <String, dynamic>{
            'version': 1,
            'sha256Hash':
                '5a4da2ab3d5b47c9f9ce864e727b2cb346af1e3ea8b897fe8f704a97ff017619',
          },
        },
      },
      pretty: pretty,
    );
  }

  static String collectRewardJson({
    required String dropInstanceId,
    bool pretty = false,
  }) {
    return _encode(
      <String, dynamic>{
        'operationName': 'DropsPage_ClaimDropRewards',
        'variables': <String, dynamic>{
          'input': <String, dynamic>{
            'dropInstanceID': dropInstanceId.trim(),
          },
        },
        'extensions': const <String, dynamic>{
          'persistedQuery': <String, dynamic>{
            'version': 1,
            'sha256Hash':
                'a455deea71bdc9015b78eb49f4acfbce8baa7ccbedd28e549bb025bd0f751930',
          },
        },
      },
      pretty: pretty,
    );
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
