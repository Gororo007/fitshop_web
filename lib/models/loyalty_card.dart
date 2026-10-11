import 'brand.dart';

enum LoyaltyTier { bronze, silver, gold }

LoyaltyTier loyaltyTierFromString(String? value) {
  switch (value) {
    case 'silver':
      return LoyaltyTier.silver;
    case 'gold':
      return LoyaltyTier.gold;
    default:
      return LoyaltyTier.bronze;
  }
}

String loyaltyTierToString(LoyaltyTier tier) {
  switch (tier) {
    case LoyaltyTier.silver:
      return 'silver';
    case LoyaltyTier.gold:
      return 'gold';
    case LoyaltyTier.bronze:
      return 'bronze';
  }
}

String loyaltyTierLabel(LoyaltyTier tier) {
  switch (tier) {
    case LoyaltyTier.silver:
      return 'Серебро';
    case LoyaltyTier.gold:
      return 'Золото';
    case LoyaltyTier.bronze:
      return 'Бронза';
  }
}

class LoyaltyCard {
  const LoyaltyCard({
    required this.id,
    required this.customerId,
    required this.tier,
    this.points = 0,
    this.deleted,
  });

  final String id;
  final String customerId;
  final LoyaltyTier tier;
  final int points;
  final DateTime? deleted;

  factory LoyaltyCard.fromJson(Map<String, dynamic> json) {
    return LoyaltyCard(
      id: json['id'] as String,
      customerId: json['customer'] as String? ?? '',
      tier: loyaltyTierFromString(json['tier'] as String?),
      points: json['points'] as int? ?? 0,
      deleted: CategoryDate.parse(json['deleted']),
    );
  }

  Map<String, dynamic> toJson() => {
    'customer': customerId,
    'tier': loyaltyTierToString(tier),
    'points': points,
  };
}
