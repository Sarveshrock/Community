import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../providers/post_providers.dart';
import '../widgets/post_card.dart';

/// A single post, full-size — also the landing target when a "you were
/// mentioned in a post" notification is tapped.
class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postDetailProvider(postId));

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: ResponsiveCenter(
        child: postAsync.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(postDetailProvider(postId)),
          ),
          data: (post) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PostCard(post: post, openOnTap: false),
          ),
        ),
      ),
    );
  }
}
