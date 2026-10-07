class TwitchBlockedTerm {
  final String id;
  final String text;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  const TwitchBlockedTerm({
    required this.id,
    required this.text,
    this.createdAt,
    this.expiresAt,
  });
  factory TwitchBlockedTerm.fromJson(Map<String, dynamic> json) =>
      TwitchBlockedTerm(
        id: json['id']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      );
}

class TwitchBlockedTermsPage {
  final List<TwitchBlockedTerm> terms;
  final String? cursor;
  const TwitchBlockedTermsPage(this.terms, this.cursor);
}
