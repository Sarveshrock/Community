import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_events.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/message_repository_impl.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/message_repository.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepositoryImpl(supabase);
});

final myConversationsProvider =
    FutureProvider<List<ConversationSummary>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(messageRepositoryProvider).getMyConversations(user.id);
});

final conversationMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  return ref.watch(messageRepositoryProvider).watchMessages(conversationId);
});

final directConversationIdProvider =
    FutureProvider.family<String, String>((ref, otherProfileId) async {
  return ref
      .watch(messageRepositoryProvider)
      .getOrCreateDirectConversation(otherProfileId);
});

/// Resolves a private storage path (chat-attachments isn't a public bucket)
/// to a short-lived signed URL for display/download.
final attachmentSignedUrlProvider =
    FutureProvider.family<String, String>((ref, storagePath) {
  return ref
      .watch(messageRepositoryProvider)
      .getAttachmentSignedUrl(storagePath);
});

class MessageController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> sendText(String conversationId, String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    final result = await AsyncValue.guard(
      () => ref
          .read(messageRepositoryProvider)
          .sendTextMessage(conversationId, trimmed),
    );
    state = result;
    if (!result.hasError) {
      ref.read(analyticsServiceProvider).log(
          AnalyticsEvents.messageSent, {'conversation_id': conversationId});
    }
    return !result.hasError;
  }

  /// Uploads [bytes] to the conversation's attachment folder, then posts a
  /// message pointing at it — covers images, PDFs, and any other file type
  /// (spec: "all other type of file format").
  Future<bool> sendAttachment(
    String conversationId, {
    required List<int> bytes,
    required String fileName,
    required MessageType type,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(messageRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      final path = await repo.uploadAttachment(conversationId,
          bytes: bytes, fileName: fileName);
      await repo.sendAttachmentMessage(conversationId, path, type,
          fileName: fileName);
    });
    state = result;
    if (!result.hasError) {
      ref.read(analyticsServiceProvider).log(
          AnalyticsEvents.messageSent, {'conversation_id': conversationId});
    }
    return !result.hasError;
  }

  Future<bool> deleteMessage(String messageId) async {
    final result = await AsyncValue.guard(
        () => ref.read(messageRepositoryProvider).deleteMessage(messageId));
    state = result;
    return !result.hasError;
  }
}

final messageControllerProvider =
    AsyncNotifierProvider<MessageController, void>(MessageController.new);
