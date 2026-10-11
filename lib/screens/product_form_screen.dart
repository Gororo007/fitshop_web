import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_errors.dart';
import '../core/ui_helpers.dart';
import '../core/validators.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/list_query.dart';
import '../models/load_status.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../repositories/catalog_repositories.dart';
import '../widgets/async_body.dart';

/// Create (`productId == null`) or edit a product.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _description = TextEditingController();

  LoadStatus _status = LoadStatus.loading;
  String? _loadError;
  bool _saving = false;
  String? _formError;
  Map<String, String> _serverErrors = {};

  Product? _product;
  List<Brand> _brands = const [];
  List<Supplier> _suppliers = const [];
  List<Category> _categories = const [];
  String? _brandId;
  String? _supplierId;
  final Set<String> _categoryIds = {};

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _loadError = null;
    });
    final brandRepo = context.read<BrandRepository>();
    final supplierRepo = context.read<SupplierRepository>();
    final categoryRepo = context.read<CategoryRepository>();
    final productRepo = context.read<ProductRepository>();
    try {
      const lookup = ListQuery(perPage: 200, sort: 'name');
      final brands = await brandRepo.list(lookup);
      final suppliers = await supplierRepo.list(lookup);
      final categories = await categoryRepo.list(lookup);
      Product? product;
      if (_isEdit) {
        product = await productRepo.getById(widget.productId!);
        if (product == null) {
          throw const NotFoundException('Товар не найден');
        }
      }
      if (!mounted) return;
      setState(() {
        _brands = brands.items;
        _suppliers = suppliers.items;
        _categories = categories.items;
        _product = product;
        if (product != null) {
          _name.text = product.name;
          _price.text = product.price.toString();
          _stock.text = '${product.stock}';
          _description.text = product.description ?? '';
          _brandId = product.brandId;
          _supplierId = product.supplierId;
          _categoryIds
            ..clear()
            ..addAll(product.categoryIds);
        }
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = errorMessage(e);
        _status = LoadStatus.error;
      });
    }
  }

  String? _server(String key, String? local) => local ?? _serverErrors[key];

  Future<void> _submit() async {
    setState(() {
      _serverErrors = {};
      _formError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final product = Product(
      id: _product?.id ?? '',
      name: _name.text.trim(),
      price: parseDouble(_price.text),
      stock: parseInt(_stock.text),
      description: nullIfBlank(_description.text),
      brandId: _brandId,
      supplierId: _supplierId,
      categoryIds: _categoryIds.toList(),
    );

    setState(() => _saving = true);
    final repo = context.read<ProductRepository>();
    try {
      final saved = _isEdit
          ? await repo.update(product)
          : await repo.create(product);
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Товар обновлён' : 'Товар создан');
      context.go('/products/${saved.id}');
    } on ValidationException catch (e) {
      final errors = fieldErrorsOf(e);
      setState(() {
        _saving = false;
        _serverErrors = errors;
        _formError = errors.isEmpty ? e.message : null;
      });
      _formKey.currentState?.validate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncBody(
      status: _status,
      error: _loadError,
      onRetry: _load,
      builder: (context) => _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Назад',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go('/products'),
                    ),
                    Text(
                      _isEdit ? 'Редактирование товара' : 'Новый товар',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_formError != null) ...[
                  Text(
                    _formError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Название *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _serverErrors.remove('name'),
                  validator: (v) => _server(
                    'name',
                    Validators.requiredField(v, label: 'Название'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Цена, ₽ *',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _serverErrors.remove('price'),
                        validator: (v) => _server(
                          'price',
                          Validators.positiveNumber(v, label: 'Цена'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Остаток на складе *',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _serverErrors.remove('stock'),
                        validator: (v) {
                          var err = Validators.nonNegativeNumber(
                            v,
                            label: 'Остаток',
                          );
                          if (err == null && int.tryParse(v!.trim()) == null) {
                            err = 'Остаток должен быть целым числом';
                          }
                          return _server('stock', err);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _brands.any((b) => b.id == _brandId)
                      ? _brandId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Бренд *',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final b in _brands)
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: (v) {
                    _brandId = v;
                    _serverErrors.remove('brand');
                  },
                  validator: (v) =>
                      _server('brand', v == null ? 'Выберите бренд' : null),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _suppliers.any((s) => s.id == _supplierId)
                      ? _supplierId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Поставщик',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Не выбран'),
                    ),
                    for (final s in _suppliers)
                      DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.name),
                      ),
                  ],
                  onChanged: (v) {
                    _supplierId = v;
                    _serverErrors.remove('supplier');
                  },
                  validator: (_) => _serverErrors['supplier'],
                ),
                const SizedBox(height: 16),
                FormField<Set<String>>(
                  validator: (_) => _serverErrors['categories'],
                  builder: (state) => InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Категории',
                      border: const OutlineInputBorder(),
                      errorText: state.errorText,
                    ),
                    child: _categories.isEmpty
                        ? const Text('Категории не созданы')
                        : Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final c in _categories)
                                FilterChip(
                                  label: Text(c.name),
                                  selected: _categoryIds.contains(c.id),
                                  onSelected: (v) => setState(() {
                                    if (v) {
                                      _categoryIds.add(c.id);
                                    } else {
                                      _categoryIds.remove(c.id);
                                    }
                                  }),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => _serverErrors.remove('description'),
                  validator: (_) => _serverErrors['description'],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Сохранить'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _saving ? null : () => context.go('/products'),
                      child: const Text('Отмена'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
