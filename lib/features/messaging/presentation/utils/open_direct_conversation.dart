import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../providers/message_providers.dart';

/// Resolves (creating it first if necessary) the direct 1:1 conversation
/// with [otherProfileId] and navigates to it — the single implementation
/// behind every "Message"/"Chat" button in the app (Profile, Buddies,
/// Local discovery, ...).
///
/// Before this existed, each call site awaited
/// `directConversationIdProvider(...).future` inline with no try/catch, so
/// whatever the RPC threw (not authenticated, blocked user, a transient
/// error) vanished into an unhandled Future rejection — the button visibly
/// did nothing and there was no way to tell it had even tried. That was the
/// actual root cause behind "Message doesn't work", not a routing or id
/// mismatch: the create-or-find call itself already resolves the correct
/// conversation for the correct pair of users, and `directConversationIdProvider`
/// already `.watch`-caches per `otherProfileId`; the missing piece was
/// simply surfacing failures instead of swallowing them.
Future<void> openDirectConversation(
  BuildContext context,
  WidgetRef ref,
  String otherProfileId, {
  String? prefillText,
}) async {
  try {
    final conversationId =
        await ref.read(directConversationIdProvider(otherProfileId).future);
    if (context.mounted) {
      context.push(RoutePaths.chatOf(conversationId), extra: prefillText);
    }
  } catch (e) {
    if (context.mounted) {
      context.showSnack('Could not open chat: $e', isError: true);
    }
  }
}
