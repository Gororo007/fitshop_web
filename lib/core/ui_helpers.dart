import 'package:flutter/material.dart';

import 'api_exceptions.dart';

String errorMessage(Object e) => e is ApiException ? e.message : '$e';

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Подтвердить',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

String formatMoney(double value) => '${value.toStringAsFixed(2)} ₽';

String formatDate(DateTime? date) {
  if (date == null) return '—';
  final d = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

String formatDateTime(DateTime? date) {
  if (date == null) return '—';
  final d = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${formatDate(d)} ${two(d.hour)}:${two(d.minute)}';
}

double parseDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}'.trim().replaceAll(',', '.')) ?? 0;
}

int parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}'.trim()) ?? parseDouble(value).round();
}

String? nullIfBlank(Object? value) {
  final s = value?.toString().trim();
  if (s == null || s.isEmpty) return null;
  return s;
}

/// Short human-friendly id for tables (PocketBase ids are 15 chars).
String shortId(String id) => id.length <= 6 ? id : id.substring(0, 6);
