import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/permissions.dart';
import '../core/ui_helpers.dart';
import '../core/validators.dart';
import '../features/customer_resolver.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/list_query.dart';
import '../models/promotion.dart';
import '../models/review.dart';
import '../models/supplier.dart';
import '../repositories/catalog_repositories.dart';
import '../state/auth_notifier.dart';
import '../widgets/entity_table.dart';
import 'simple_entity_list_screen.dart';

Widget _cell(String text, {bool deleted = false}) => Text(
  text.isEmpty ? '—' : text,
  style: deleted
      ? const TextStyle(
          decoration: TextDecoration.lineThrough,
          color: Colors.grey,
        )
      : null,
);

Future<List<CrudOption>> _productOptions(ProductRepository repo) async {
  final page = await repo.find(const ProductListQuery(size: 200, sort: 'name'));
  return [for (final p in page.items) CrudOption(p.id, p.name)];
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final manage = Permissions.can(user, AppPermission.manageCatalog);
    return SimpleEntityListScreen<Category>(
      title: 'Категории',
      entityLabel: 'категория',
      repository: context.read<CategoryRepository>(),
      idOf: (c) => c.id,
      isDeleted: (c) => c.isDeleted,
      sort: 'name',
      canCreate: manage,
      canEdit: manage,
      canDelete: manage,
      canHardDelete: Permissions.can(user, AppPermission.hardDelete),
      canRestore: Permissions.can(user, AppPermission.restoreDeleted),
      columns: [
        TableColumnSpec<Category>(
          label: 'Название',
          sortField: 'name',
          build: (c) => _cell(c.name, deleted: c.isDeleted),
        ),
        TableColumnSpec<Category>(
          label: 'Описание',
          build: (c) => _cell(c.description ?? ''),
        ),
      ],
      fields: const [
        CrudField(key: 'name', label: 'Название', required: true),
        CrudField(
          key: 'description',
          label: 'Описание',
          type: CrudFieldType.multiline,
        ),
      ],
      initialValues: (c) => {'name': c.name, 'description': c.description},
      buildEntity: (v, initial) => Category(
        id: initial?.id ?? '',
        name: v['name'] as String,
        description: nullIfBlank(v['description']),
      ),
    );
  }
}

class BrandsScreen extends StatelessWidget {
  const BrandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final manage = Permissions.can(user, AppPermission.manageCatalog);
    return SimpleEntityListScreen<Brand>(
      title: 'Бренды',
      entityLabel: 'бренд',
      repository: context.read<BrandRepository>(),
      idOf: (b) => b.id,
      isDeleted: (b) => b.isDeleted,
      sort: 'name',
      canCreate: manage,
      canEdit: manage,
      canDelete: manage,
      canHardDelete: Permissions.can(user, AppPermission.hardDelete),
      canRestore: Permissions.can(user, AppPermission.restoreDeleted),
      columns: [
        TableColumnSpec<Brand>(
          label: 'Название',
          sortField: 'name',
          build: (b) => _cell(b.name, deleted: b.isDeleted),
        ),
        TableColumnSpec<Brand>(
          label: 'Страна',
          sortField: 'country',
          build: (b) => _cell(b.country ?? ''),
        ),
      ],
      fields: const [
        CrudField(key: 'name', label: 'Название', required: true),
        CrudField(key: 'country', label: 'Страна'),
      ],
      initialValues: (b) => {'name': b.name, 'country': b.country},
      buildEntity: (v, initial) => Brand(
        id: initial?.id ?? '',
        name: v['name'] as String,
        country: nullIfBlank(v['country']),
      ),
    );
  }
}

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final manage = Permissions.can(user, AppPermission.manageCatalog);
    return SimpleEntityListScreen<Supplier>(
      title: 'Поставщики',
      entityLabel: 'поставщик',
      repository: context.read<SupplierRepository>(),
      idOf: (s) => s.id,
      isDeleted: (s) => s.isDeleted,
      sort: 'name',
      canCreate: manage,
      canEdit: manage,
      canDelete: manage,
      canHardDelete: Permissions.can(user, AppPermission.hardDelete),
      canRestore: Permissions.can(user, AppPermission.restoreDeleted),
      columns: [
        TableColumnSpec<Supplier>(
          label: 'Название',
          sortField: 'name',
          build: (s) => _cell(s.name, deleted: s.isDeleted),
        ),
        TableColumnSpec<Supplier>(
          label: 'Контакт',
          build: (s) => _cell(s.contact ?? ''),
        ),
        TableColumnSpec<Supplier>(
          label: 'Телефон',
          build: (s) => _cell(s.phone ?? ''),
        ),
      ],
      fields: const [
        CrudField(key: 'name', label: 'Название', required: true),
        CrudField(key: 'contact', label: 'Контактное лицо'),
        CrudField(key: 'phone', label: 'Телефон', type: CrudFieldType.phone),
      ],
      initialValues: (s) => {
        'name': s.name,
        'contact': s.contact,
        'phone': s.phone,
      },
      buildEntity: (v, initial) => Supplier(
        id: initial?.id ?? '',
        name: v['name'] as String,
        contact: nullIfBlank(v['contact']),
        phone: nullIfBlank(v['phone']),
      ),
    );
  }
}

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final manage = Permissions.can(user, AppPermission.manageCustomers);
    return SimpleEntityListScreen<Customer>(
      title: 'Клиенты',
      entityLabel: 'клиент',
      repository: context.read<CustomerRepository>(),
      idOf: (c) => c.id,
      isDeleted: (c) => c.isDeleted,
      sort: 'full_name',
      canCreate: manage,
      canEdit: manage,
      canDelete: manage,
      canHardDelete: Permissions.can(user, AppPermission.hardDelete),
      canRestore: Permissions.can(user, AppPermission.restoreDeleted),
      columns: [
        TableColumnSpec<Customer>(
          label: 'ФИО',
          sortField: 'full_name',
          build: (c) => _cell(c.fullName, deleted: c.isDeleted),
        ),
        TableColumnSpec<Customer>(
          label: 'Телефон',
          build: (c) => _cell(c.phone ?? ''),
        ),
        TableColumnSpec<Customer>(
          label: 'Email',
          build: (c) => _cell(c.email ?? ''),
        ),
      ],
      fields: const [
        CrudField(key: 'full_name', label: 'ФИО', required: true),
        CrudField(
          key: 'phone',
          label: 'Телефон',
          type: CrudFieldType.phone,
          required: true,
        ),
        CrudField(key: 'email', label: 'Email', type: CrudFieldType.email),
      ],
      initialValues: (c) => {
        'full_name': c.fullName,
        'phone': c.phone,
        'email': c.email,
      },
      buildEntity: (v, initial) => Customer(
        id: initial?.id ?? '',
        fullName: v['full_name'] as String,
        phone: nullIfBlank(v['phone']),
        email: nullIfBlank(v['email']),
        userId: initial?.userId,
      ),
    );
  }
}

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final manage = Permissions.can(user, AppPermission.managePromotions);
    final products = context.read<ProductRepository>();
    return SimpleEntityListScreen<Promotion>(
      title: 'Акции',
      entityLabel: 'акция',
      repository: context.read<PromotionRepository>(),
      idOf: (p) => p.id,
      isDeleted: (p) => p.deleted != null,
      sort: 'name',
      canCreate: manage,
      canEdit: manage,
      canDelete: manage,
      canHardDelete: Permissions.can(user, AppPermission.hardDelete),
      canRestore: Permissions.can(user, AppPermission.restoreDeleted),
      columns: [
        TableColumnSpec<Promotion>(
          label: 'Название',
          sortField: 'name',
          build: (p) => _cell(p.name, deleted: p.deleted != null),
        ),
        TableColumnSpec<Promotion>(
          label: 'Скидка',
          numeric: true,
          build: (p) => Text('${p.discountPercent.toStringAsFixed(0)}%'),
        ),
        TableColumnSpec<Promotion>(
          label: 'Активна',
          build: (p) => Icon(
            p.active ? Icons.check_circle : Icons.cancel_outlined,
            color: p.active ? Colors.green : Colors.grey,
          ),
        ),
        TableColumnSpec<Promotion>(
          label: 'Период',
          build: (p) =>
              Text('${formatDate(p.startDate)} — ${formatDate(p.endDate)}'),
        ),
        TableColumnSpec<Promotion>(
          label: 'Товаров',
          numeric: true,
          build: (p) => Text('${p.productIds.length}'),
        ),
      ],
      fields: [
        const CrudField(key: 'name', label: 'Название', required: true),
        CrudField(
          key: 'discount',
          label: 'Скидка, %',
          type: CrudFieldType.number,
          serverKey: 'discount_percent',
          validator: (v) {
            final err = Validators.positiveNumber(v, label: 'Скидка');
            if (err != null) return err;
            if (parseDouble(v) > 100) return 'Скидка не более 100%';
            return null;
          },
        ),
        const CrudField(
          key: 'active',
          label: 'Активна',
          type: CrudFieldType.boolean,
        ),
        const CrudField(
          key: 'start',
          label: 'Начало',
          type: CrudFieldType.date,
          serverKey: 'start_date',
        ),
        const CrudField(
          key: 'end',
          label: 'Окончание',
          type: CrudFieldType.date,
          serverKey: 'end_date',
        ),
        CrudField(
          key: 'products',
          label: 'Товары',
          type: CrudFieldType.multiSelect,
          loadOptions: () => _productOptions(products),
        ),
      ],
      initialValues: (p) => {
        'name': p.name,
        'discount': p.discountPercent.toString(),
        'active': p.active,
        'start': p.startDate,
        'end': p.endDate,
        'products': p.productIds,
      },
      buildEntity: (v, initial) {
        final start = v['start'] as DateTime?;
        final end = v['end'] as DateTime?;
        return Promotion(
          id: initial?.id ?? '',
          name: v['name'] as String,
          discountPercent: parseDouble(v['discount']),
          active: v['active'] as bool,
          startDate: start == null
              ? null
              : DateTime.utc(start.year, start.month, start.day),
          endDate: end == null
              ? null
              : DateTime.utc(end.year, end.month, end.day, 23, 59, 59),
          productIds: List<String>.from(v['products'] as List),
        );
      },
    );
  }
}

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final staff = Permissions.isStaff(user);
    final products = context.read<ProductRepository>();
    final customers = context.read<CustomerRepository>();
    final resolver = CustomerResolver(customers);

    return SimpleEntityListScreen<Review>(
      title: 'Отзывы',
      entityLabel: 'отзыв',
      repository: context.read<ReviewRepository>(),
      expand: 'product,customer',
      idOf: (r) => r.id,
      isDeleted: (r) => r.deleted != null,
      canCreate: user != null,
      canEdit: staff,
      canDelete: staff,
      canHardDelete: Permissions.can(user, AppPermission.hardDelete),
      canRestore: Permissions.can(user, AppPermission.restoreDeleted),
      columns: [
        TableColumnSpec<Review>(
          label: 'Товар',
          build: (r) =>
              _cell(r.productName ?? r.productId, deleted: r.deleted != null),
        ),
        TableColumnSpec<Review>(
          label: 'Клиент',
          build: (r) => _cell(r.customerName ?? ''),
        ),
        TableColumnSpec<Review>(
          label: 'Оценка',
          sortField: 'rating',
          numeric: true,
          build: (r) {
            final stars = r.rating.clamp(0, 5);
            return Text('${'★' * stars}${'☆' * (5 - stars)}');
          },
        ),
        TableColumnSpec<Review>(
          label: 'Комментарий',
          build: (r) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              r.comment ?? '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      fields: [
        CrudField(
          key: 'product',
          label: 'Товар',
          type: CrudFieldType.dropdown,
          required: true,
          loadOptions: () => _productOptions(products),
        ),
        if (staff)
          CrudField(
            key: 'customer',
            label: 'Клиент',
            type: CrudFieldType.dropdown,
            required: true,
            loadOptions: () async {
              final page = await customers.list(
                const ListQuery(perPage: 200, sort: 'full_name'),
              );
              return [for (final c in page.items) CrudOption(c.id, c.fullName)];
            },
          ),
        CrudField(
          key: 'rating',
          label: 'Оценка (1–5)',
          type: CrudFieldType.integer,
          required: true,
          validator: Validators.rating,
        ),
        const CrudField(
          key: 'comment',
          label: 'Комментарий',
          type: CrudFieldType.multiline,
        ),
      ],
      initialValues: (r) => {
        'product': r.productId,
        'customer': r.customerId,
        'rating': '${r.rating}',
        'comment': r.comment,
      },
      buildEntity: (v, initial) async {
        String customerId;
        if (staff) {
          customerId = v['customer'] as String;
        } else {
          customerId = (await resolver.ensure(user!)).id;
        }
        return Review(
          id: initial?.id ?? '',
          productId: v['product'] as String,
          customerId: customerId,
          rating: parseInt(v['rating']),
          comment: nullIfBlank(v['comment']),
        );
      },
    );
  }
}
