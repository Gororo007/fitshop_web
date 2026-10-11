import '../../core/config.dart';
import '../../models/loyalty_card.dart';
import '../../models/pricing_result.dart';
import '../../models/product.dart';
import '../../models/promotion.dart';

class OrderLineInput {
  const OrderLineInput({required this.product, required this.quantity});

  final Product product;
  final int quantity;
}

class OrderPricingEngine {
  OrderPricingEngine({
    this.freeShippingThreshold = AppConfig.freeShippingThreshold,
    this.shippingCost = AppConfig.defaultShippingCost,
    DateTime? now,
  }) : _now = now ?? DateTime.now();

  final double freeShippingThreshold;
  final double shippingCost;
  final DateTime _now;

  PricingResult calculate({
    required List<OrderLineInput> lines,
    required List<Promotion> promotions,
    LoyaltyTier? loyaltyTier,
  }) {
    final activePromos = promotions
        .where((p) => p.isActiveOn(_now))
        .toList(growable: false);

    final breakdown = <PricingLineBreakdown>[];
    var subtotal = 0.0;
    var promoTotal = 0.0;

    for (final line in lines) {
      if (line.quantity <= 0) continue;
      final unit = line.product.price;
      final lineSub = unit * line.quantity;
      final discountPercent = _bestPromotionPercent(
        line.product.id,
        activePromos,
      );
      final promoDiscount = lineSub * discountPercent / 100;
      final lineTotal = lineSub - promoDiscount;

      subtotal += lineSub;
      promoTotal += promoDiscount;

      breakdown.add(
        PricingLineBreakdown(
          productId: line.product.id,
          productName: line.product.name,
          quantity: line.quantity,
          unitPrice: unit,
          lineSubtotal: lineSub,
          promotionDiscount: promoDiscount,
          lineTotal: lineTotal,
        ),
      );
    }

    final afterPromo = subtotal - promoTotal;
    final loyaltyPercent = _loyaltyPercent(loyaltyTier);
    final loyaltyDiscount = afterPromo * loyaltyPercent / 100;
    final merchandiseTotal = afterPromo - loyaltyDiscount;

    final freeShipping = merchandiseTotal >= freeShippingThreshold;
    final shipping = freeShipping ? 0.0 : shippingCost;
    final grand = merchandiseTotal + shipping;

    return PricingResult(
      lines: breakdown,
      subtotal: _round(subtotal),
      promotionDiscountTotal: _round(promoTotal),
      loyaltyDiscountPercent: loyaltyPercent,
      loyaltyDiscountAmount: _round(loyaltyDiscount),
      shippingCost: _round(shipping),
      freeShippingApplied: freeShipping,
      grandTotal: _round(grand),
    );
  }

  double _bestPromotionPercent(String productId, List<Promotion> promos) {
    var best = 0.0;
    for (final p in promos) {
      if (p.productIds.contains(productId) && p.discountPercent > best) {
        best = p.discountPercent;
      }
    }
    return best;
  }

  double _loyaltyPercent(LoyaltyTier? tier) {
    switch (tier) {
      case LoyaltyTier.silver:
        return AppConfig.loyaltySilverPercent;
      case LoyaltyTier.gold:
        return AppConfig.loyaltyGoldPercent;
      case LoyaltyTier.bronze:
        return AppConfig.loyaltyBronzePercent;
      case null:
        return 0;
    }
  }

  double _round(double v) => double.parse(v.toStringAsFixed(2));
}
