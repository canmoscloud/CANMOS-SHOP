import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _planInfo;
  bool _loadingPlan = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlan());
  }

  Future<void> _loadPlan() async {
    final auth = context.read<AuthService>();
    final plan = await auth.getActivePlan();
    if (mounted) {
      setState(() {
        _planInfo = plan;
        _loadingPlan = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final themeService = context.watch<ThemeService>();

    final planoData = _planInfo != null ? _planInfo!['planos'] as Map<String, dynamic>? : null;
    final planoNome = planoData?['nome'] as String? ?? 'Free';
    final limiteProdutos = planoData?['limite_produtos'] as int? ?? 3;
    final limiteVendas = planoData?['limite_vendas'] as int? ?? 5;
    final precoMensal = (planoData?['preco_mensal'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      (auth.userName?[0] ?? 'U').toUpperCase(),
                      style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(auth.userName ?? 'Usuário', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(auth.user?.email ?? '', style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: auth.isAdmin ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      auth.isAdmin ? 'Admin' : 'Operador',
                      style: TextStyle(
                        color: auth.isAdmin ? AppTheme.primary : AppTheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: const Icon(Icons.card_giftcard, color: AppTheme.primary),
              title: const Text('Plano'),
              subtitle: _loadingPlan
                  ? const Text('Carregando...')
                  : Text(planoNome),
              trailing: planoNome == 'Free'
                  ? ElevatedButton(
                      onPressed: () => _fazerUpgrade(),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      child: const Text('Upgrade', style: TextStyle(color: Colors.white)),
                    )
                  : Chip(
                      label: Text(precoMensal > 0 ? 'R\$ ${precoMensal.toStringAsFixed(2)}/mês' : 'Gratuito'),
                    ),
            ),
          ),

          if (planoNome != 'Free') ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.manage_accounts, color: AppTheme.primary),
                title: const Text('Gerenciar Assinatura'),
                subtitle: const Text('Alterar plano ou cancelar'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _abrirPortalAssinatura(),
              ),
            ),
          ],

          const SizedBox(height: 16),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode, color: AppTheme.primary),
                  title: const Text('Modo Escuro'),
                  value: themeService.isDark,
                  onChanged: (v) => themeService.setDark(v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Versão'),
                  trailing: Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Suporte'),
                  subtitle: const Text('canmos.cloud@gmail.com'),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Limites do Plano $planoNome', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                _limitTile(
                  'Produtos',
                  limiteProdutos == -1 ? 'Ilimitado' : limiteProdutos.toString(),
                  Icons.inventory_2,
                ),
                _limitTile(
                  'Vendas',
                  limiteVendas == -1 ? 'Ilimitado' : limiteVendas.toString(),
                  Icons.shopping_cart,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => auth.signOut(),
              icon: const Icon(Icons.logout, color: AppTheme.error),
              label: const Text('Sair', style: TextStyle(color: AppTheme.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _limitTile(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(title),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _fazerUpgrade() async {
    final auth = context.read<AuthService>();
    if (auth.empresaId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    final subService = context.read<SubscriptionService>();
    const priceId = AppConstants.stripePricePremiumMonthly;
    if (priceId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configure o ID do preço no Stripe Dashboard'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      return;
    }
    final url = await subService.criarCheckoutSession(
      empresaId: auth.empresaId!,
      priceId: priceId,
    );

    if (mounted) Navigator.pop(context);

    if (url != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Redirecionando para pagamento...'),
          backgroundColor: AppTheme.success,
        ),
      );
      // Em um app real, abriria a URL no navegador
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao criar sessão de pagamento'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _abrirPortalAssinatura() async {
    final auth = context.read<AuthService>();
    if (auth.empresaId == null) return;

    final subService = context.read<SubscriptionService>();
    final url = await subService.abrirPortalAssinatura(empresaId: auth.empresaId!);

    if (url != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abrindo portal de gerenciamento...'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }
}
