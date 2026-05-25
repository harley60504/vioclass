import 'package:dio/dio.dart';

import './twitch_api_constants.dart';
import './twitch_api_exception.dart';

/// 共用 HTTP client。
///
/// 這層只負責：
/// - Dio 設定
/// - timeout
/// - HTTP method
/// - 統一錯誤轉換
///
/// 不在這裡解析 Twitch feature model。
class TwitchApiClient {
  final Dio _dio;
  final bool closeDioOnDispose;

  TwitchApiClient({Dio? dio, this.closeDioOnDispose = true})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: TwitchApiConstants.connectTimeout,
              receiveTimeout: TwitchApiConstants.receiveTimeout,
              sendTimeout: TwitchApiConstants.sendTimeout,
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  Dio get dio => _dio;

  Future<T> getJson<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _requestJson<T>(
      method: 'GET',
      url: url,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<T> postJson<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _requestJson<T>(
      method: 'POST',
      url: url,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<T> patchJson<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _requestJson<T>(
      method: 'PATCH',
      url: url,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<T> deleteJson<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _requestJson<T>(
      method: 'DELETE',
      url: url,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<T> _requestJson<T>({
    required String method,
    required String url,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.json,
        ),
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        throw TwitchApiException(
          _extractErrorMessage(response.data) ??
              'HTTP request failed with status $statusCode.',
          statusCode: statusCode,
          uri: response.realUri,
          details: response.data,
        );
      }

      final body = response.data;
      if (body is T) return body;

      throw TwitchApiException(
        'Unexpected response type. Expected $T but got ${body.runtimeType}.',
        statusCode: statusCode,
        uri: response.realUri,
        details: body,
      );
    } on DioException catch (e) {
      throw TwitchApiException(
        e.message ?? 'Network request failed.',
        statusCode: e.response?.statusCode,
        uri: e.requestOptions.uri,
        details: e.response?.data ?? e.error,
      );
    }
  }

  String? _extractErrorMessage(Object? data) {
    if (data is Map) {
      final message = data['message'] ?? data['error'] ?? data['status'];
      if (message != null) return message.toString();
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return null;
  }

  void close({bool force = false}) {
    if (closeDioOnDispose) {
      _dio.close(force: force);
    }
  }
}
