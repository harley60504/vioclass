/// Twitch API 統一例外。
///
/// API 層盡量丟這個 exception，讓 controller / UI 可以用一致方式顯示錯誤。
class TwitchApiException implements Exception {
  final String message;
  final int? statusCode;
  final Uri? uri;
  final Object? details;

  const TwitchApiException(
    this.message, {
    this.statusCode,
    this.uri,
    this.details,
  });

  @override
  String toString() {
    final parts = <String>[
      'TwitchApiException',
      if (statusCode != null) 'status=$statusCode',
      if (uri != null) 'uri=$uri',
      'message=$message',
      if (details != null) 'details=$details',
    ];

    return parts.join(' | ');
  }
}
