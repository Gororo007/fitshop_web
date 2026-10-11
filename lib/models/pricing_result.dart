class PricingLineBreakdown {
  const PricingLineBreakdown({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineSubtotal,
    required this.promotionDiscount,
    required this.lineTotal,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double lineSubtotal;
  final double promotionDiscount;
  final double lineTotal;
}

class PricingResult {
  const PricingResult({
    required this.lines,
    required this.subtotal,
    required this.promotionDiscountTotal,
    required this.loyaltyDiscountPercent,
    required this.loyaltyDiscountAmount,
    required this.shippingCost,
    required this.freeShippingApplied,
    required this.grandTotal,
  });

  final List<PricingLineBreakdown> lines;
  final double subtotal;
  final double promotionDiscountTotal;
  final double loyaltyDiscountPercent;
  final double loyaltyDiscountAmount;
  final double shippingCost;
  final bool freeShippingApplied;
  final double grandTotal;
}
