import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });

  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;
}

class EntityTable<T> extends StatelessWidget {
  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
  });

  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final String Function(T item) idOf;
  final Set<String> selected;
  final ValueChanged<String>? onToggleSelect;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showSelection = onToggleSelect != null;

    DataColumn columnFor(TableColumnSpec<T> spec) {
      final field = spec.sortField;
      Widget label = Text(spec.label);
      if (field != null && onSort != null) {
        final active = sortField == field;
        label = InkWell(
          onTap: () => onSort!(field),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(spec.label),
              if (active) ...[
                const SizedBox(width: 4),
                Icon(
                  sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
              ],
            ],
          ),
        );
      }
      return DataColumn(label: label, numeric: spec.numeric);
    }

    final dataColumns = <DataColumn>[
      if (showSelection) const DataColumn(label: Text('')),
      ...columns.map(columnFor),
      if (actions != null) const DataColumn(label: Text('Действия')),
    ];

    final rows = <DataRow>[
      for (final item in items)
        DataRow(
          selected: selected.contains(idOf(item)),
          cells: [
            if (showSelection)
              DataCell(
                Checkbox(
                  value: selected.contains(idOf(item)),
                  onChanged: (_) => onToggleSelect!(idOf(item)),
                ),
              ),
            ...columns.map((c) => DataCell(c.build(item))),
            if (actions != null)
              DataCell(
                Row(mainAxisSize: MainAxisSize.min, children: actions!(item)),
              ),
          ],
        ),
    ];

    final table = DataTable(
      columns: dataColumns,
      rows: rows,
      showCheckboxColumn: false,
    );

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: width),
            child: table,
          ),
        ),
      ),
    );
  }
}
