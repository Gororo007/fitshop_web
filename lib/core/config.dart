class AppConfig {
  AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8090',
  );

  static const freeShippingThreshold = 5000.0;
  static const defaultShippingCost = 350.0;
  static const defaultPageSize = 20;

  static const loyaltyBronzePercent = 3.0;
  static const loyaltySilverPercent = 7.0;
  static const loyaltyGoldPercent = 12.0;
}
