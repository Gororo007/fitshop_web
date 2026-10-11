import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_exceptions.dart';
import '../core/form_errors.dart';
import '../core/ui_helpers.dart';
import '../core/validators.dart';
import '../models/list_query.dart';
import '../models/load_status.dart';
import '../repositories/catalog_repositories.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/async_body.dart';
import '../widgets/entity_table.dart';
import '../widgets/pagination_bar.dart';

enum CrudFieldType {
  text,
  multiline,
  number,
  integer,
  email,
  phone,
  boolean,
  date,
  dropdown,
  multiSelect,
}

class CrudOption {
  const CrudOption(this.value, this.label);
  final String value;
  final String label;
}

/// Declarative description of one form field of [SimpleEntityListScreen].
///
/// Value types in the values map passed to `buildEntity`:
/// text/number/integer/email/phone/multiline give a `String`,
/// boolean gives a `bool`, date gives a nullable `DateTime`,
/// dropdown gives a nullable `String` and multiSelect gives a `List<String>`.
class CrudField {
  const CrudField({
    required this.key,
    required this.label,
    this.type = CrudFieldType.text,
    this.required = false,
    this.validator,
    this.loadOptions,
    this.serverKey,
    this.helper,
  });

  final String key;
  final String label;
  final CrudFieldType type;
  final bool required;
  final String? Function(String? value)? validator;
  final Future<List<CrudOption>> Function()? loadOptions;

  /// PocketBase field name for server errors (defaults to [key]).
  final String? serverKey;
  final String? helper;

  bool get isTextLike =>
      type == CrudFieldType.text ||
      type == CrudFieldType.multiline ||
      type == CrudFieldType.number ||
      type == CrudFieldType.integer ||
      type == CrudFieldType.email ||
      type == CrudFieldType.phone;
}

/// Generic list + create/edit dialog screen for simple catalog entities.
class SimpleEntityListScreen<T> extends StatefulWidget {
  const SimpleEntityListScreen({
    super.key,
    required this.title,
    required this.repository,
    required this.columns,
    required this.idOf,
    required this.fields,
    required this.initialValues,
    required this.buildEntity,
    this.isDeleted,
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canHardDelete = false,
    this.canRestore = false,
    this.searchEnabled = true,
    this.expand,
    this.sort = '-created',
    this.entityLabel = 'запись',
  });

  final String title;
  final EntityListRepository<T> repository;
  final List<TableColumnSpec<T>> columns;
  final String Function(T item) idOf;
  final List<CrudField> fields;
  final Map<String, dynamic> Function(T item) initialValues;
  final FutureOr<T> Function(Map<String, dynamic> values, T? initial)
  buildEntity;
  final bool Function(T item)? isDeleted;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final bool canHardDelete;
  final bool canRestore;
  final bool searchEnabled;
  final String? expand;
  final String sort;
  final String entityLabel;

  @override
  State<SimpleEntityListScreen<T>> createState() =>
      _SimpleEntityListScreenState<T>();
}

class _SimpleEntityListScreenState<T> extends State<SimpleEntityListScreen<T>> {
  late final EntityListNotifier<T> _notifier;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notifier = EntityListNotifier<T>(
      widget.repository,
      initialQuery: ListQuery(sort: widget.sort, expand: widget.expand),
    )..idExtractor = widget.idOf;
    _notifier.load();
  }

  @override
  void dispose() {
    _notifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  ListQuery _rebuild({String? search, bool? includeDeleted, int? page}) {
    final q = _notifier.query;
    return ListQuery(
      page: page ?? 1,
      perPage: q.perPage,
      sort: q.sort,
      search: search ?? q.search,
      filter: q.filter,
      expand: q.expand,
      includeDeleted: includeDeleted ?? q.includeDeleted,
    );
  }

  void _search() {
    final text = _searchController.text.trim();
    _notifier.applyQuery(
      ListQuery(
        perPage: _notifier.query.perPage,
        sort: _notifier.query.sort,
        search: text.isEmpty ? null : text,
        filter: _notifier.query.filter,
        expand: _notifier.query.expand,
        includeDeleted: _notifier.query.includeDeleted,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) showSnack(context, success);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _openForm([T? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EntityFormDialog<T>(
        title: item == null
            ? 'Создать: ${widget.entityLabel}'
            : 'Редактировать: ${widget.entityLabel}',
        fields: widget.fields,
        initial: item == null ? const {} : widget.initialValues(item),
        onSubmit: (values) async {
          final entity = await widget.buildEntity(values, item);
          if (item == null) {
            await widget.repository.create(entity);
          } else {
            await widget.repository.update(widget.idOf(item), entity);
          }
        },
      ),
    );
    if (saved == true) {
      await _notifier.load();
      if (mounted) showSnack(context, 'Сохранено');
    }
  }

  Future<void> _softDelete(T item) async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить?',
      message: 'Запись будет помечена удалённой (можно восстановить).',
      confirmLabel: 'Удалить',
    );
    if (!ok) return;
    await _run(() => _notifier.softDelete(widget.idOf(item)), 'Удалено');
  }

  Future<void> _hardDelete(T item) async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить навсегда?',
      message: 'Это действие необратимо.',
      confirmLabel: 'Удалить навсегда',
    );
    if (!ok) return;
    await _run(
      () => _notifier.hardDelete(widget.idOf(item)),
      'Удалено навсегда',
    );
  }

  Future<void> _bulkDelete() async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить выбранные?',
      message: 'Выбрано записей: ${_notifier.selected.length}.',
      confirmLabel: 'Удалить',
    );
    if (!ok) return;
    await _run(() async {
      await _notifier.bulkSoftDeleteSelected();
    }, 'Удалено');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final result = _notifier.result;
        final query = _notifier.query;
        final showActions =
            widget.canEdit ||
            widget.canDelete ||
            widget.canHardDelete ||
            widget.canRestore;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (widget.canCreate)
                    FilledButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                    ),
                  if (widget.canDelete && _notifier.hasSelection)
                    OutlinedButton.icon(
                      onPressed: _bulkDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        'Удалить выбранные (${_notifier.selected.length})',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.searchEnabled)
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Поиск',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Сбросить',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _search();
                            },
                          ),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                  if (widget.canRestore)
                    FilterChip(
                      label: const Text('Показать удалённые'),
                      selected: query.includeDeleted,
                      onSelected: (v) =>
                          _notifier.applyQuery(_rebuild(includeDeleted: v)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AsyncBody(
                  status: _notifier.status,
                  error: _notifier.error,
                  onRetry: _notifier.load,
                  isEmpty: result.items.isEmpty,
                  builder: (context) => EntityTable<T>(
                    columns: widget.columns,
                    items: result.items,
                    idOf: widget.idOf,
                    selected: _notifier.selected,
                    onToggleSelect: widget.canDelete
                        ? _notifier.toggleSelection
                        : null,
                    sortField: _notifier.sortField,
                    sortAscending: _notifier.sortAscending,
                    onSort: _notifier.toggleSort,
                    actions: showActions ? _rowActions : null,
                  ),
                ),
              ),
              if (_notifier.status == LoadStatus.success)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PaginationBar(
                    page: result.page,
                    totalPages: result.totalPages,
                    totalItems: result.totalItems,
                    pageSize: query.perPage,
                    onPageChanged: _notifier.setPage,
                    onPageSizeChanged: _notifier.setPageSize,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _rowActions(T item) {
    final deleted = widget.isDeleted?.call(item) ?? false;
    return [
      if (widget.canEdit && !deleted)
        IconButton(
          tooltip: 'Редактировать',
          icon: const Icon(Icons.edit),
          onPressed: () => _openForm(item),
        ),
      if (widget.canDelete && !deleted)
        IconButton(
          tooltip: 'Удалить',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _softDelete(item),
        ),
      if (widget.canRestore && deleted)
        IconButton(
          tooltip: 'Восстановить',
          icon: const Icon(Icons.restore),
          onPressed: () =>
              _run(() => _notifier.restore(widget.idOf(item)), 'Восстановлено'),
        ),
      if (widget.canHardDelete)
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => _hardDelete(item),
        ),
    ];
  }
}

class _EntityFormDialog<T> extends StatefulWidget {
  const _EntityFormDialog({
    required this.title,
    required this.fields,
    required this.initial,
    required this.onSubmit,
  });

  final String title;
  final List<CrudField> fields;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic> values) onSubmit;

  @override
  State<_EntityFormDialog<T>> createState() => _EntityFormDialogState<T>();
}

class _EntityFormDialogState<T> extends State<_EntityFormDialog<T>> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};
  final Map<String, List<CrudOption>> _options = {};
  Map<String, String> _serverErrors = {};
  String? _formError;
  bool _loadingOptions = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final initial = widget.initial[f.key];
      if (f.isTextLike) {
        _controllers[f.key] = TextEditingController(
          text: initial == null ? '' : '$initial',
        );
      } else if (f.type == CrudFieldType.boolean) {
        _values[f.key] = initial as bool? ?? false;
      } else if (f.type == CrudFieldType.multiSelect) {
        _values[f.key] = <String>[
          ...((initial as List?)?.map((e) => '$e') ?? const <String>[]),
        ];
      } else {
        _values[f.key] = initial;
      }
    }
    _loadAllOptions();
  }

  Future<void> _loadAllOptions() async {
    try {
      for (final f in widget.fields) {
        if (f.loadOptions != null) {
          _options[f.key] = await f.loadOptions!();
        }
      }
    } catch (e) {
      _formError = 'Не удалось загрузить справочники: ${errorMessage(e)}';
    }
    if (mounted) setState(() => _loadingOptions = false);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateText(CrudField f, String? value) {
    final blank = value == null || value.trim().isEmpty;
    String? local;
    if (f.validator != null) {
      local = f.validator!(value);
    } else if (f.required && blank) {
      local = '${f.label} обязательно';
    } else if (!blank) {
      switch (f.type) {
        case CrudFieldType.email:
          local = Validators.email(value);
        case CrudFieldType.phone:
          local = Validators.phone(value);
        case CrudFieldType.number:
          local = Validators.nonNegativeNumber(value, label: f.label);
        case CrudFieldType.integer:
          local = Validators.nonNegativeNumber(value, label: f.label);
          if (local == null && int.tryParse(value.trim()) == null) {
            local = '${f.label} должно быть целым числом';
          }
        default:
          break;
      }
    }
    return local ?? _serverErrors[f.serverKey ?? f.key];
  }

  Future<void> _pickDate(CrudField f) async {
    final current = _values[f.key] as DateTime?;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _values[f.key] = picked;
        _serverErrors.remove(f.serverKey ?? f.key);
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _serverErrors = {};
      _formError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    final values = <String, dynamic>{
      for (final f in widget.fields)
        f.key: f.isTextLike ? _controllers[f.key]!.text.trim() : _values[f.key],
    };
    setState(() => _saving = true);
    try {
      await widget.onSubmit(values);
      if (mounted) Navigator.of(context).pop(true);
    } on ValidationException catch (e) {
      final errors = fieldErrorsOf(e);
      setState(() {
        _saving = false;
        _serverErrors = errors;
        _formError = errors.isEmpty ? e.message : null;
      });
      _formKey.currentState?.validate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _formError = errorMessage(e);
        });
      }
    }
  }

  Widget _buildField(CrudField f) {
    final errorKey = f.serverKey ?? f.key;
    switch (f.type) {
      case CrudFieldType.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          value: _values[f.key] as bool,
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
      case CrudFieldType.date:
        final date = _values[f.key] as DateTime?;
        return FormField<DateTime>(
          validator: (_) {
            if (f.required && _values[f.key] == null) {
              return '${f.label} обязательно';
            }
            return _serverErrors[errorKey];
          },
          builder: (state) => InputDecorator(
            decoration: InputDecoration(
              labelText: f.label,
              border: const OutlineInputBorder(),
              errorText: state.errorText,
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: InkWell(
              onTap: () => _pickDate(f),
              child: Text(date == null ? 'Не выбрано' : formatDate(date)),
            ),
          ),
        );
      case CrudFieldType.dropdown:
        final options = _options[f.key] ?? const <CrudOption>[];
        final current = _values[f.key] as String?;
        return DropdownButtonFormField<String>(
          initialValue: options.any((o) => o.value == current) ? current : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: f.label,
            border: const OutlineInputBorder(),
            helperText: f.helper,
          ),
          items: [
            for (final o in options)
              DropdownMenuItem(value: o.value, child: Text(o.label)),
          ],
          onChanged: (v) => setState(() {
            _values[f.key] = v;
            _serverErrors.remove(errorKey);
          }),
          validator: (v) {
            if (f.required && (v == null || v.isEmpty)) {
              return '${f.label} обязательно';
            }
            return _serverErrors[errorKey];
          },
        );
      case CrudFieldType.multiSelect:
        final options = _options[f.key] ?? const <CrudOption>[];
        final selected = _values[f.key] as List<String>;
        return FormField<List<String>>(
          validator: (_) {
            if (f.required && selected.isEmpty) {
              return '${f.label}: выберите хотя бы один вариант';
            }
            return _serverErrors[errorKey];
          },
          builder: (state) => InputDecorator(
            decoration: InputDecoration(
              labelText: f.label,
              border: const OutlineInputBorder(),
              errorText: state.errorText,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final o in options)
                      FilterChip(
                        label: Text(o.label),
                        selected: selected.contains(o.value),
                        onSelected: (v) => setState(() {
                          if (v) {
                            selected.add(o.value);
                          } else {
                            selected.remove(o.value);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      case CrudFieldType.text:
      case CrudFieldType.multiline:
      case CrudFieldType.number:
      case CrudFieldType.integer:
      case CrudFieldType.email:
      case CrudFieldType.phone:
        final numeric =
            f.type == CrudFieldType.number || f.type == CrudFieldType.integer;
        return TextFormField(
          controller: _controllers[f.key],
          maxLines: f.type == CrudFieldType.multiline ? 3 : 1,
          keyboardType: switch (f.type) {
            CrudFieldType.email => TextInputType.emailAddress,
            CrudFieldType.phone => TextInputType.phone,
            CrudFieldType.multiline => TextInputType.multiline,
            _ =>
              numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
          },
          decoration: InputDecoration(
            labelText: f.required ? '${f.label} *' : f.label,
            helperText: f.helper,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _serverErrors.remove(errorKey),
          validator: (v) => _validateText(f, v),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: _loadingOptions
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_formError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _formError!,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      for (final f in widget.fields) ...[
                        _buildField(f),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: (_saving || _loadingOptions) ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}
