import '../entities/message.dart';

abstract class MessageRepository {
  Future<List<ConversationSummary>> getMyConversations(String myId);
  Future<String> getOrCreateDirectConversation(String otherProfileId);
  Future<List<Message>> getMessages(String conversationId,
      {int limit = 50, DateTime? before});
  Stream<List<Message>> watchMessages(String conversationId);
  Future<void> sendTextMessage(String conversationId, String content);

  /// [fileName] is stored as the message's `content` so the original name
  /// survives independently of the storage path (spec: image/pdf/any file
  /// type). [attachmentUrl] is a **storage path** (`chat-attachments`
  /// bucket is private), not a public URL — resolve it with
  /// [getAttachmentSignedUrl] before displaying.
  Future<void> sendAttachmentMessage(
    String conversationId,
    String attachmentUrl,
    MessageType type, {
    String? fileName,
  });

  /// Uploads to the `chat-attachments` bucket under
  /// `<conversationId>/<unique>_<fileName>` (the path convention its RLS
  /// policies key off) and returns that storage path.
  Future<String> uploadAttachment(String conversationId,
      {required List<int> bytes, required String fileName});

  /// Short-lived signed URL for a private storage path — required since the
  /// bucket isn't public.
  Future<String> getAttachmentSignedUrl(String storagePath);

  Future<void> deleteMessage(String messageId);
  Future<void> markConversationRead(String conversationId, String myId);
}
