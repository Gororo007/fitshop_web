import 'package:flutter/material.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    this.onPageSizeChanged,
    this.pageSizeOptions = const [10, 20, 50],
  });

  final int page;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final List<int> pageSizeOptions;

  @override
  Widget build(BuildContext context) {
    final safeTotalPages = totalPages < 1 ? 1 : totalPages;
    final safePage = page.clamp(1, safeTotalPages);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Всего: $totalItems'),
        Text('Страница $safePage из $safeTotalPages'),
        IconButton(
          tooltip: 'Первая',
          onPressed: safePage > 1 ? () => onPageChanged(1) : null,
          icon: const Icon(Icons.first_page),
        ),
        IconButton(
          tooltip: 'Назад',
          onPressed: safePage > 1 ? () => onPageChanged(safePage - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Вперёд',
          onPressed: safePage < safeTotalPages
              ? () => onPageChanged(safePage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          tooltip: 'Последняя',
          onPressed: safePage < safeTotalPages
              ? () => onPageChanged(safeTotalPages)
              : null,
          icon: const Icon(Icons.last_page),
        ),
        if (onPageSizeChanged != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('На странице:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: pageSizeOptions.contains(pageSize)
                    ? pageSize
                    : pageSizeOptions.first,
                items: [
                  for (final n in pageSizeOptions)
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (v) {
                  if (v != null) onPageSizeChanged!(v);
                },
              ),
            ],
          ),
      ],
    );
  }
}
