import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/error_mapper.dart';
import 'error_state.dart';
import 'loading_state.dart';

/// Renders an [AsyncValue] with the Loading / Success / Error states every
/// screen must handle (spec section 57 & 71). [isEmpty] + [emptyBuilder] let
/// callers also cover the Empty state without repeating boilerplate.
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.emptyBuilder,
    this.onRetry,
    this.loadingBuilder,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T data)? isEmpty;
  final WidgetBuilder? emptyBuilder;
  final VoidCallback? onRetry;
  final WidgetBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (d) {
        if (isEmpty != null && emptyBuilder != null && isEmpty!(d)) {
          return emptyBuilder!(context);
        }
        return data(d);
      },
      loading: () => loadingBuilder?.call(context) ?? const LoadingState(),
      error: (error, stack) => ErrorState(
        message: mapExceptionToFailure(error).message,
        onRetry: onRetry,
      ),
    );
  }
}
