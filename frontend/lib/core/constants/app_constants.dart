class AppConstants {
  static const String appName = 'CANMOS-SHOP';
  static const String appVersion = '1.0.0';
  static const int produtoLimitFree = 3;
  static const int vendaLimitFree = 5;

  // Stripe Price IDs - substituir pelos IDs reais do Stripe Dashboard
  static const String stripePricePremiumMonthly = String.fromEnvironment(
    'STRIPE_PRICE_PREMIUM',
    defaultValue: '',
  );

  // URLs
  static const String supportEmail = 'canmos.cloud@gmail.com';
}
