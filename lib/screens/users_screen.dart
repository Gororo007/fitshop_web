import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/ui_helpers.dart';
import '../core/validators.dart';
import '../models/app_user.dart';
import '../models/load_status.dart';
import '../repositories/user_repository.dart';
import '../state/auth_notifier.dart';
import '../widgets/async_body.dart';
import '../widgets/entity_table.dart';
import '../widgets/pagination_bar.dart';

/// Admin: list users and change their role.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _search = TextEditingController();
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  List<AppUser> _users = const [];
  int _page = 1;
  int _perPage = 20;
  int _totalPages = 1;
  int _totalItems = 0;
  String? _query;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final repo = context.read<UserRepository>();
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final res = await repo.list(
        page: page ?? _page,
        perPage: _perPage,
        search: _query,
      );
      if (!mounted) return;
      setState(() {
        _users = res.items;
        _page = res.page;
        _totalPages = res.totalPages;
        _totalItems = res.totalItems;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _status = LoadStatus.error;
      });
    }
  }

  void _doSearch() {
    final text = _search.text.trim();
    _query = text.isEmpty ? null : text;
    _load(page: 1);
  }

  Future<void> _changeRole(AppUser user, UserRole role) async {
    if (role == user.role) return;
    final repo = context.read<UserRepository>();
    setState(() => _busy.add(user.id));
    try {
      await repo.updateRole(user.id, role);
      if (mounted) showSnack(context, 'Роль изменена');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(user.id));
    }
  }

  Future<void> _createUser() async {
    final created = await showDialog<_NewUserData>(
      context: context,
      builder: (ctx) => const _CreateUserDialog(),
    );
    if (created == null || !mounted) return;

    final repo = context.read<UserRepository>();
    try {
      await repo.create(
        email: created.email,
        name: created.name,
        password: created.password,
        role: created.role,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Пользователь создан'),
          content: SelectableText(
            'Email: ${created.email}\n'
            'Пароль: ${created.password}\n'
            'Роль: ${userRoleLabel(created.role)}\n\n'
            'Сохраните пароль — в базе он хранится только в виде хеша '
            'и повторно посмотреть его нельзя.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: '${created.email}\n${created.password}'),
                );
                Navigator.of(ctx).pop();
              },
              child: const Text('Копировать'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthNotifier>().user;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Пользователи',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: _createUser,
                icon: const Icon(Icons.person_add),
                label: const Text('Создать'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Поиск по имени или email',
                isDense: true,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Сбросить',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _search.clear();
                    _doSearch();
                  },
                ),
              ),
              onSubmitted: (_) => _doSearch(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncBody(
              status: _status,
              error: _error,
              onRetry: _load,
              isEmpty: _users.isEmpty,
              emptyMessage: 'Пользователи не найдены',
              builder: (context) => EntityTable<AppUser>(
                items: _users,
                idOf: (u) => u.id,
                columns: [
                  TableColumnSpec<AppUser>(
                    label: 'Имя',
                    build: (u) => Text(u.name),
                  ),
                  TableColumnSpec<AppUser>(
                    label: 'Email',
                    build: (u) => Text(u.email),
                  ),
                  TableColumnSpec<AppUser>(
                    label: 'Подтверждён',
                    build: (u) => Icon(
                      u.verified ? Icons.check_circle : Icons.cancel_outlined,
                      color: u.verified ? Colors.green : Colors.grey,
                    ),
                  ),
                  TableColumnSpec<AppUser>(
                    label: 'Роль',
                    build: (u) {
                      if (_busy.contains(u.id)) {
                        return const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      final isMe = me?.id == u.id;
                      return DropdownButton<UserRole>(
                        value: u.role,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final r in UserRole.values)
                            DropdownMenuItem(
                              value: r,
                              child: Text(userRoleLabel(r)),
                            ),
                        ],
                        // Admins cannot change their own role.
                        onChanged: isMe
                            ? null
                            : (r) {
                                if (r != null) _changeRole(u, r);
                              },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_status == LoadStatus.success)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PaginationBar(
                page: _page,
                totalPages: _totalPages,
                totalItems: _totalItems,
                pageSize: _perPage,
                onPageChanged: (p) => _load(page: p),
                onPageSizeChanged: (s) {
                  _perPage = s;
                  _load(page: 1);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NewUserData {
  const _NewUserData({
    required this.email,
    required this.name,
    required this.password,
    required this.role,
  });

  final String email;
  final String name;
  final String password;
  final UserRole role;
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  UserRole _role = UserRole.customer;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Пароль всегда задаётся явно при создании — сразу генерируем рабочий.
    final generated = PbUserRepository.generatePassword();
    _password.text = generated;
    _confirm.text = generated;
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _generatePassword() {
    final generated = PbUserRepository.generatePassword();
    setState(() {
      _password.text = generated;
      _confirm.text = generated;
      _obscure = false;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _NewUserData(
        email: _email.text.trim(),
        name: _name.text.trim(),
        password: _password.text,
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новый пользователь'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => Validators.requiredField(v, label: 'Имя'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email (логин)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Пароль *',
                    border: const OutlineInputBorder(),
                    helperText: 'Обязателен: от 8 символов, цифра и спецсимвол',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Показать' : 'Скрыть',
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Повтор пароля *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Повторите пароль';
                    if (v != _password.text) return 'Пароли не совпадают';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _generatePassword,
                    icon: const Icon(Icons.casino),
                    label: const Text('Сгенерировать пароль'),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(
                    labelText: 'Роль',
                    border: OutlineInputBorder(),
                    helperText:
                        'Покупатель / Менеджер / Администратор — разные разделы',
                  ),
                  items: [
                    for (final r in UserRole.values)
                      DropdownMenuItem(value: r, child: Text(userRoleLabel(r))),
                  ],
                  onChanged: (r) {
                    if (r != null) setState(() => _role = r);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Создать')),
      ],
    );
  }
}
