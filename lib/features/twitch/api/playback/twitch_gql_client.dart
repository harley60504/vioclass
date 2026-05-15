import 'package:dio/dio.dart';

class TwitchGqlClientException implements Exception {
  final String message;
  final int? statusCode;
  final Object? responseData;

  const TwitchGqlClientException(
    this.message, {
    this.statusCode,
    this.responseData,
  });

  @override
  String toString() {
    final code = statusCode == null ? '' : ' HTTP $statusCode';
    return 'TwitchGqlClientException$code: $message';
  }
}

class TwitchGqlClient {
  static const String gqlEndpoint = 'https://gql.twitch.tv/gql';

  final String clientId;
  final String? accessToken;
  final String authorizationPrefix;
  final Dio _dio;

  TwitchGqlClient({
    required this.clientId,
    this.accessToken,
    this.authorizationPrefix = 'Bearer',
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 12),
                sendTimeout: const Duration(seconds: 10),
              ),
            );

  Map<String, String> buildHeaders() {
    final headers = <String, String>{
      'Client-ID': clientId,
      'Content-Type': 'application/json',
      'Accept': '*/*',
      'Origin': 'https://www.twitch.tv',
      'Referer': 'https://www.twitch.tv/',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };

    final token = accessToken?.trim();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = '$authorizationPrefix $token';
    }

    return headers;
  }

  Future<dynamic> post(
    Map<String, dynamic> payload, {
    String? operationLabel,
  }) async {
    final response = await _dio.post<dynamic>(
      gqlEndpoint,
      data: payload,
      options: Options(
        headers: buildHeaders(),
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final status = response.statusCode ?? 0;
    final data = response.data;

    if (status >= 400) {
      throw TwitchGqlClientException(
        'GQL request failed${operationLabel == null ? '' : '：$operationLabel'}',
        statusCode: status,
        responseData: data,
      );
    }

    final errors = _extractErrors(data);
    if (errors.isNotEmpty) {
      throw TwitchGqlClientException(
        'GQL returned errors${operationLabel == null ? '' : '：$operationLabel'}｜${errors.join(' / ')}',
        statusCode: status,
        responseData: data,
      );
    }

    return data;
  }

  List<String> _extractErrors(dynamic data) {
    final output = <String>[];

    void readOne(dynamic value) {
      if (value is Map) {
        final errors = value['errors'];
        if (errors is List) {
          for (final error in errors) {
            if (error is Map) {
              final message = error['message']?.toString();
              if (message != null && message.trim().isNotEmpty) {
                output.add(message.trim());
              } else {
                output.add(error.toString());
              }
            } else if (error != null) {
              output.add(error.toString());
            }
          }
        }
      }
    }

    if (data is List) {
      for (final item in data) {
        readOne(item);
      }
    } else {
      readOne(data);
    }

    return output;
  }
}
