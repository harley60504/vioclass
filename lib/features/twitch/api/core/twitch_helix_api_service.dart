import './twitch_api_client.dart';
import './twitch_api_constants.dart';

typedef TwitchBearerTokenProvider = Future<String?> Function();

/// Twitch Helix transport layer。
///
/// 只負責 Helix GET/POST/PATCH/DELETE 與 headers。
/// Feature API 請放到 twitch_user_api_service / twitch_stream_api_service 等檔案。
class TwitchHelixApiService {
  final TwitchApiClient client;
  final String clientId;
  final TwitchBearerTokenProvider accessTokenProvider;

  const TwitchHelixApiService({
    required this.client,
    required this.accessTokenProvider,
    this.clientId = TwitchApiConstants.twitchWebClientId,
  });

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return client.getJson<Map<String, dynamic>>(
      _url(path),
      queryParameters: queryParameters,
      headers: await _headers(),
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return client.postJson<Map<String, dynamic>>(
      _url(path),
      data: data,
      queryParameters: queryParameters,
      headers: await _headers(),
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return client.patchJson<Map<String, dynamic>>(
      _url(path),
      data: data,
      queryParameters: queryParameters,
      headers: await _headers(),
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return client.deleteJson<Map<String, dynamic>>(
      _url(path),
      data: data,
      queryParameters: queryParameters,
      headers: await _headers(),
    );
  }

  String _url(String path) {
    final safePath = path.startsWith('/') ? path : '/$path';
    return '${TwitchApiConstants.helixBaseUrl}$safePath';
  }

  Future<Map<String, String>> _headers() async {
    final rawToken = await accessTokenProvider();
    final token = rawToken?.trim() ?? '';

    return <String, String>{
      'Client-ID': clientId,
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }
}
