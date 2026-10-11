import '../core/api_client.dart';
import '../core/config.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/list_query.dart';
import '../models/loyalty_card.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/promotion.dart';
import '../models/review.dart';
import '../models/supplier.dart';
import 'pb_collection_repository.dart';

/// Shared CRUD contract for list screens ([EntityListNotifier]).
abstract interface class EntityListRepository<T> {
  Future<PageResult<T>> list(ListQuery query);

  Future<T?> getById(String id);

  Future<T> create(T entity);

  Future<T> update(String id, T entity);

  Future<void> softDelete(String id);

  Future<void> hardDelete(String id);

  Future<void> restore(String id);

  Future<int> bulkSoftDelete(List<String> ids);
}

class ProductListQuery {
  const ProductListQuery({
    this.search,
    this.brandId,
    this.categoryId,
    this.minPrice,
    this.maxPrice,
    this.includeDeleted = false,
    this.sort = '-created',
    this.page = 1,
    this.size = AppConfig.defaultPageSize,
  });

  final String? search;
  final String? brandId;
  final String? categoryId;
  final double? minPrice;
  final double? maxPrice;
  final bool includeDeleted;
  final String sort;
  final int page;
  final int size;

  ProductListQuery copyWith({
    String? search,
    Object? brandId = _unset,
    Object? categoryId = _unset,
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    bool? includeDeleted,
    String? sort,
    int? page,
    int? size,
  }) {
    return ProductListQuery(
      search: search ?? this.search,
      brandId: brandId == _unset ? this.brandId : brandId as String?,
      categoryId: categoryId == _unset
          ? this.categoryId
          : categoryId as String?,
      minPrice: minPrice == _unset ? this.minPrice : minPrice as double?,
      maxPrice: maxPrice == _unset ? this.maxPrice : maxPrice as double?,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }

  static const _unset = Object();

  ListQuery toListQuery() {
    final filters = <String>[];
    if (brandId != null && brandId!.isNotEmpty) {
      filters.add('brand = "${_escape(brandId!)}"');
    }
    if (categoryId != null && categoryId!.isNotEmpty) {
      filters.add('categories ~ "${_escape(categoryId!)}"');
    }
    if (minPrice != null) {
      filters.add('price >= ${minPrice!}');
    }
    if (maxPrice != null) {
      filters.add('price <= ${maxPrice!}');
    }
    return ListQuery(
      page: page,
      perPage: size,
      sort: sort,
      search: search,
      filter: filters.isEmpty ? null : filters.join(' && '),
      expand: 'brand',
      includeDeleted: includeDeleted,
    );
  }

  static String _escape(String value) => value.replaceAll('"', '\\"');
}

abstract interface class ProductRepository {
  Future<PageResult<Product>> find(ProductListQuery query);

  Future<Product?> getById(String id);

  Future<Product> create(Product product);

  Future<Product> update(Product product);

  Future<void> softDelete(String id);

  Future<void> hardDelete(String id);

  Future<void> restore(String id);

  Future<int> bulkSoftDelete(List<String> ids);
}

abstract interface class CategoryRepository
    extends EntityListRepository<Category> {}

abstract interface class BrandRepository extends EntityListRepository<Brand> {}

abstract interface class SupplierRepository
    extends EntityListRepository<Supplier> {}

abstract interface class CustomerRepository
    extends EntityListRepository<Customer> {}

abstract interface class LoyaltyCardRepository
    extends EntityListRepository<LoyaltyCard> {}

abstract interface class PromotionRepository
    extends EntityListRepository<Promotion> {}

abstract interface class ReviewRepository
    extends EntityListRepository<Review> {}

abstract interface class ShopOrderRepository
    extends EntityListRepository<ShopOrder> {}

abstract interface class OrderItemRepository {
  Future<PageResult<OrderItem>> listByOrder(String orderId, {ListQuery? query});

  /// Lists order items across all orders (used for analytics).
  Future<PageResult<OrderItem>> list(ListQuery query);

  Future<OrderItem?> getById(String id);

  Future<OrderItem> create(OrderItem item);

  Future<OrderItem> update(OrderItem item);

  Future<void> hardDelete(String id);
}

class _PbEntityRepository<T> implements EntityListRepository<T> {
  _PbEntityRepository({
    required PbCollectionRepository<T> pb,
    required Map<String, dynamic> Function(T entity) toBody,
    this.searchField,
  }) : _pb = pb,
       _toBody = toBody;

  final PbCollectionRepository<T> _pb;
  final Map<String, dynamic> Function(T entity) _toBody;
  final String? searchField;

  @override
  Future<PageResult<T>> list(ListQuery query) =>
      _pb.list(query, searchField: searchField);

  @override
  Future<T?> getById(String id) async {
    try {
      return await _pb.getById(id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<T> create(T entity) => _pb.create(_toBody(entity));

  @override
  Future<T> update(String id, T entity) => _pb.update(id, _toBody(entity));

  @override
  Future<void> softDelete(String id) async {
    await _pb.softDelete(id);
  }

  @override
  Future<void> hardDelete(String id) => _pb.hardDelete(id);

  @override
  Future<void> restore(String id) async {
    await _pb.restore(id);
  }

  @override
  Future<int> bulkSoftDelete(List<String> ids) => _pb.bulkSoftDelete(ids);
}

class PbCategoryRepository extends _PbEntityRepository<Category>
    implements CategoryRepository {
  PbCategoryRepository(ApiClient client)
    : super(
        pb: PbCollectionRepository<Category>(
          client: client,
          collection: 'categories',
          fromJson: Category.fromJson,
        ),
        toBody: (c) => c.toJson(),
        searchField: 'name',
      );
}

class PbBrandRepository extends _PbEntityRepository<Brand>
    implements BrandRepository {
  PbBrandRepository(ApiClient client)
    : super(
        pb: PbCollectionRepository<Brand>(
          client: client,
          collection: 'brands',
          fromJson: Brand.fromJson,
        ),
        toBody: (b) => b.toJson(),
        searchField: 'name',
      );
}

class PbSupplierRepository extends _PbEntityRepository<Supplier>
    implements SupplierRepository {
  PbSupplierRepository(ApiClient client)
    : super(
        pb: PbCollectionRepository<Supplier>(
          client: client,
          collection: 'suppliers',
          fromJson: Supplier.fromJson,
        ),
        toBody: (s) => s.toJson(),
        searchField: 'name',
      );
}

class PbProductRepository implements ProductRepository {
  PbProductRepository(ApiClient client)
    : _pb = PbCollectionRepository<Product>(
        client: client,
        collection: 'products',
        fromJson: Product.fromJson,
      );

  final PbCollectionRepository<Product> _pb;

  @override
  Future<PageResult<Product>> find(ProductListQuery query) =>
      _pb.list(query.toListQuery(), searchField: 'name');

  @override
  Future<Product?> getById(String id) async {
    try {
      return await _pb.getById(id, expand: 'brand');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Product> create(Product product) => _pb.create(product.toJson());

  @override
  Future<Product> update(Product product) =>
      _pb.update(product.id, product.toJson());

  @override
  Future<void> softDelete(String id) async {
    await _pb.softDelete(id);
  }

  @override
  Future<void> hardDelete(String id) => _pb.hardDelete(id);

  @override
  Future<void> restore(String id) async {
    await _pb.restore(id);
  }

  @override
  Future<int> bulkSoftDelete(List<String> ids) => _pb.bulkSoftDelete(ids);
}

class PbCustomerRepository extends _PbEntityRepository<Customer>
    implements CustomerRepository {
  PbCustomerRepository(ApiClient client)
    : super(
        pb: PbCollectionRepository<Customer>(
          client: client,
          collection: 'customers',
          fromJson: Customer.fromJson,
        ),
        toBody: (c) => c.toJson(),
        searchField: 'full_name',
      );
}

class PbLoyaltyCardRepository extends _PbEntityRepository<LoyaltyCard>
    implements LoyaltyCardRepository {
  PbLoyaltyCardRepository(ApiClient client)
    : super(
        pb: PbCollectionRepository<LoyaltyCard>(
          client: client,
          collection: 'loyalty_cards',
          fromJson: LoyaltyCard.fromJson,
        ),
        toBody: (c) => c.toJson(),
      );
}

class PbPromotionRepository extends _PbEntityRepository<Promotion>
    implements PromotionRepository {
  PbPromotionRepository(ApiClient client)
    : super(
        pb: PbCollectionRepository<Promotion>(
          client: client,
          collection: 'promotions',
          fromJson: Promotion.fromJson,
        ),
        toBody: (p) => p.toJson(),
        searchField: 'name',
      );
}

class PbReviewRepository extends _PbEntityRepository<Review>
    implements ReviewRepository {
  PbReviewRepository(ApiClient client)
    : super(
        pb: PbCollectionRepository<Review>(
          client: client,
          collection: 'reviews',
          fromJson: Review.fromJson,
        ),
        toBody: (r) => r.toJson(),
        searchField: 'comment',
      );
}

class PbShopOrderRepository extends _PbEntityRepository<ShopOrder>
    implements ShopOrderRepository {
  PbShopOrderRepository(ApiClient client)
    : super(
        pb: PbCollectionRepository<ShopOrder>(
          client: client,
          collection: 'orders',
          fromJson: ShopOrder.fromJson,
        ),
        toBody: (o) => o.toJson(),
      );
}

class PbOrderItemRepository implements OrderItemRepository {
  PbOrderItemRepository(ApiClient client)
    : _pb = PbCollectionRepository<OrderItem>(
        client: client,
        collection: 'order_items',
        fromJson: OrderItem.fromJson,
      );

  final PbCollectionRepository<OrderItem> _pb;

  @override
  Future<PageResult<OrderItem>> listByOrder(
    String orderId, {
    ListQuery? query,
  }) {
    final base = query ?? const ListQuery();
    final orderFilter = 'order = "${orderId.replaceAll('"', '\\"')}"';
    final merged = base.filter == null || base.filter!.isEmpty
        ? orderFilter
        : '($orderFilter) && (${base.filter})';
    // order_items has no soft-delete field, so do not filter on `deleted`.
    final q = base.copyWith(
      filter: merged,
      expand: 'product',
      includeDeleted: true,
    );
    return _pb.list(q);
  }

  @override
  Future<PageResult<OrderItem>> list(ListQuery query) {
    return _pb.list(query.copyWith(expand: 'product', includeDeleted: true));
  }

  @override
  Future<OrderItem?> getById(String id) async {
    try {
      return await _pb.getById(id, expand: 'product');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<OrderItem> create(OrderItem item) => _pb.create(item.toJson());

  @override
  Future<OrderItem> update(OrderItem item) =>
      _pb.update(item.id, item.toJson());

  @override
  Future<void> hardDelete(String id) => _pb.hardDelete(id);
}
