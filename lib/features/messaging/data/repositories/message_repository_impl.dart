import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/message_repository.dart';

const _chatAttachmentsBucket = 'chat-attachments';

class MessageRepositoryImpl implements MessageRepository {
  MessageRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ConversationSummary>> getMyConversations(String myId) async {
    try {
      final myMemberships = await _client
          .from(Tables.conversationMembers)
          .select('conversation_id')
          .eq('profile_id', myId);
      final conversationIds = (myMemberships as List)
          .map((e) => e['conversation_id'] as String)
          .toList();
      if (conversationIds.isEmpty) return [];

      final otherMembers = await _client
          .from(Tables.conversationMembers)
          .select(
              'conversation_id, profile_id, profiles(full_name, avatar_url)')
          .inFilter('conversation_id', conversationIds)
          .neq('profile_id', myId);

      final lastMessages = await _client
          .from(Tables.messages)
          .select('conversation_id, content, message_type, created_at')
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false);

      final lastMessageByConversation = <String, Map<String, dynamic>>{};
      for (final m in (lastMessages as List)) {
        final convId = m['conversation_id'] as String;
        lastMessageByConversation.putIfAbsent(
            convId, () => m as Map<String, dynamic>);
      }

      final summaries = <ConversationSummary>[];
      for (final row in (otherMembers as List)) {
        final convId = row['conversation_id'] as String;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final last = lastMessageByConversation[convId];

        String? lastMessagePreview;
        if (last != null) {
          lastMessagePreview = last['message_type'] == 'text'
              ? last['content'] as String?
              : 'Sent an attachment';
        }

        summaries.add(ConversationSummary(
          conversationId: convId,
          otherProfileId: row['profile_id'] as String,
          otherName: profile?['full_name'] as String? ?? 'Community member',
          otherAvatarUrl: profile?['avatar_url'] as String?,
          lastMessage: lastMessagePreview,
          lastMessageAt: last != null
              ? DateTime.parse(last['created_at'] as String)
              : null,
        ));
      }

      summaries.sort((a, b) {
        if (a.lastMessageAt == null) return 1;
        if (b.lastMessageAt == null) return -1;
        return b.lastMessageAt!.compareTo(a.lastMessageAt!);
      });
      return summaries;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> getOrCreateDirectConversation(String otherProfileId) async {
    try {
      final id = await _client.rpc(
        'get_or_create_direct_conversation',
        params: {'other_profile_id': otherProfileId},
      );
      return id as String;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<Message>> getMessages(String conversationId,
      {int limit = 50, DateTime? before}) async {
    try {
      var query = _client
          .from(Tables.messages)
          .select()
          .eq('conversation_id', conversationId);
      if (before != null) {
        query = query.lt('created_at', before.toIso8601String());
      }
      final data =
          await query.order('created_at', ascending: false).limit(limit);
      return (data as List)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) {
    // Unlike the regular Postgrest query builder, [SupabaseStreamBuilder]'s
    // `.order()` defaults `ascending` to **false** — omitting it here (as
    // this used to) silently streamed newest-first, which both chat screens'
    // non-reversed ListViews then rendered with the newest message at the
    // top instead of the bottom. Every consumer of this stream assumes
    // chronological (oldest-first) order, so make that explicit.
    return _client
        .from(Tables.messages)
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(Message.fromJson).toList());
  }

  @override
  Future<void> sendTextMessage(String conversationId, String content) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.messages).insert({
        'conversation_id': conversationId,
        'sender_id': myId,
        'message_type': 'text',
        'content': content,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> sendAttachmentMessage(
    String conversationId,
    String attachmentUrl,
    MessageType type, {
    String? fileName,
  }) async {
    try {
      final myId = _client.auth.currentUser!.id;
      await _client.from(Tables.messages).insert({
        'conversation_id': conversationId,
        'sender_id': myId,
        'message_type': type.value,
        'attachment_url': attachmentUrl,
        'content': fileName,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> uploadAttachment(String conversationId,
      {required List<int> bytes, required String fileName}) async {
    try {
      final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final path =
          '$conversationId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await _client.storage
          .from(_chatAttachmentsBucket)
          .uploadBinary(path, Uint8List.fromList(bytes));
      return path;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> getAttachmentSignedUrl(String storagePath) async {
    try {
      return await _client.storage
          .from(_chatAttachmentsBucket)
          .createSignedUrl(storagePath, 3600);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      await _client.from(Tables.messages).update({
        'deleted_at': DateTime.now().toIso8601String(),
        'content': null
      }).eq('id', messageId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> markConversationRead(String conversationId, String myId) async {
    try {
      await _client
          .from(Tables.conversationMembers)
          .update({'last_read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('profile_id', myId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
