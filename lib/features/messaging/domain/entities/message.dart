enum MessageType { text, image, file, system }

extension MessageTypeX on MessageType {
  String get value => name;
  static MessageType fromValue(String? value) {
    return MessageType.values
        .firstWhere((e) => e.value == value, orElse: () => MessageType.text);
  }
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.content,
    this.attachmentUrl,
    required this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final String? content;
  final String? attachmentUrl;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        senderId: json['sender_id'] as String,
        type: MessageTypeX.fromValue(json['message_type'] as String?),
        content: json['content'] as String?,
        attachmentUrl: json['attachment_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        deletedAt: json['deleted_at'] != null
            ? DateTime.parse(json['deleted_at'] as String)
            : null,
      );
}

class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.otherProfileId,
    required this.otherName,
    this.otherAvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
  });

  final String conversationId;
  final String otherProfileId;
  final String otherName;
  final String? otherAvatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
}
