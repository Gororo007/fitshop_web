import 'package:flutter/material.dart';

import '../models/load_status.dart';

class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.status,
    required this.builder,
    this.error,
    this.isEmpty = false,
    this.emptyMessage = 'Ничего не найдено',
    this.onRetry,
    this.loadingMessage,
  });

  final LoadStatus status;
  final String? error;
  final bool isEmpty;
  final String emptyMessage;
  final VoidCallback? onRetry;
  final String? loadingMessage;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (loadingMessage != null) ...[
                const SizedBox(height: 16),
                Text(loadingMessage!),
              ],
            ],
          ),
        );
      case LoadStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(error ?? 'Произошла ошибка', textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить'),
                  ),
                ],
              ],
            ),
          ),
        );
      case LoadStatus.success:
        if (isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(emptyMessage, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        return builder(context);
    }
  }
}
