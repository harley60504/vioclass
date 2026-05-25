import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../engagement/twitch_prediction_api_service.dart';

class TwitchTokenValidation {
  final String clientId;
  final String login;
  final String userId;
  final List<String> scopes;
  final int expiresIn;

  const TwitchTokenValidation({
    required this.clientId,
    required this.login,
    required this.userId,
    required this.scopes,
    required this.expiresIn,
  });

  factory TwitchTokenValidation.fromJson(Map<String, dynamic> json) {
    final scopes = json['scopes'];

    return TwitchTokenValidation(
      clientId: json['client_id']?.toString() ?? '',
      login: json['login']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      scopes: scopes is List
          ? scopes.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      expiresIn: int.tryParse(json['expires_in']?.toString() ?? '') ?? 0,
    );
  }
}

/// OAuth token helper。
///
/// 這裡先只做 validate / revoke。
/// Device code / Web cookie login 之後再另外做成正式 auth flow。
class TwitchAuthApiService {
  final TwitchApiClient client;
  final String clientId;

  const TwitchAuthApiService({
    required this.client,
    this.clientId = TwitchApiConstants.twitchWebClientId,
  });

  Future<TwitchTokenValidation> validateToken(String accessToken) async {
    final response = await client.getJson<Map<String, dynamic>>(
      TwitchApiConstants.oauthValidateUrl,
      headers: <String, String>{'Authorization': 'OAuth ${accessToken.trim()}'},
    );

    final validation = TwitchTokenValidation.fromJson(response);
    TwitchPredictionApiService.rememberViewerUserId(validation.userId);
    return validation;
  }

  Future<void> revokeToken(String accessToken) async {
    await client.postJson<Map<String, dynamic>>(
      TwitchApiConstants.oauthRevokeUrl,
      queryParameters: <String, dynamic>{
        'client_id': clientId,
        'token': accessToken.trim(),
      },
      headers: const <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );
  }
}
