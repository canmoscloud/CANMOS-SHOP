import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'app/app.dart';
import 'core/config/env_config.dart';
import 'core/services/auth_service.dart';
import 'core/services/caixa_service.dart';
import 'core/services/payment_service.dart';
import 'core/services/produto_service.dart';
import 'core/services/subscription_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/venda_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  await SupabaseService.initialize();

  Stripe.publishableKey = EnvConfig().stripePublishableKey;

  // Carrega o tema antes do primeiro frame: criar o service dentro do
  // provider exibiria o tema claro por um instante antes de trocar.
  final themeService = ThemeService();
  await themeService.carregar();

  runApp(CanmosShopApp(themeService: themeService));
}

class CanmosShopApp extends StatelessWidget {
  final ThemeService themeService;

  const CanmosShopApp({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ChangeNotifierProvider(create: (_) => ProdutoService()),
        ChangeNotifierProvider(create: (_) => VendaService()),
        ChangeNotifierProvider(create: (_) => CaixaService()),
        ChangeNotifierProvider(create: (_) => PaymentService()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'CANMOS-SHOP',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeService.themeMode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('pt', 'BR')],
            locale: const Locale('pt', 'BR'),
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
