import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';
import 'error_view.dart';
import 'loading_view.dart';

/// Standard loading / error(+retry) handling for an [AsyncValue]; empty states are
/// up to the [data] builder because "empty" depends on the data type.
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({super.key, required this.value, required this.data, required this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(message: AppException.from(error).message, onRetry: onRetry),
    );
  }
}
