class TwitchChatReplyInfo {
  final String parentMsgId;
  final String parentDisplayName;
  final String parentMsgBody;
  final String parentUserId;
  final String parentUserLogin;

  const TwitchChatReplyInfo({
    required this.parentMsgId,
    required this.parentDisplayName,
    required this.parentMsgBody,
    required this.parentUserId,
    required this.parentUserLogin,
  });

  bool get hasValue {
    return parentMsgId.isNotEmpty ||
        parentDisplayName.isNotEmpty ||
        parentMsgBody.isNotEmpty ||
        parentUserId.isNotEmpty ||
        parentUserLogin.isNotEmpty;
  }

  factory TwitchChatReplyInfo.fromTags(Map<String, String> tags) {
    return TwitchChatReplyInfo(
      parentMsgId:
          tags['reply-parent-msg-id'] ??
          tags['reply-thread-parent-msg-id'] ??
          '',
      parentDisplayName: tags['reply-parent-display-name'] ?? '',
      parentMsgBody: tags['reply-parent-msg-body'] ?? '',
      parentUserId: tags['reply-parent-user-id'] ?? '',
      parentUserLogin: tags['reply-parent-user-login'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'parentMsgId': parentMsgId,
      'parentDisplayName': parentDisplayName,
      'parentMsgBody': parentMsgBody,
      'parentUserId': parentUserId,
      'parentUserLogin': parentUserLogin,
    };
  }
}
