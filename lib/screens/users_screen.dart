import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui_helpers.dart';
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

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthNotifier>().user;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Пользователи',
            style: Theme.of(context).textTheme.headlineSmall,
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
