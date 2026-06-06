import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info
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
                      color: auth.isAdmin ? AppTheme.primary.withOpacity(0.1) : AppTheme.secondary.withOpacity(0.1),
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

          // Plan info
          Card(
            child: ListTile(
              leading: const Icon(Icons.card_giftcard, color: AppTheme.primary),
              title: const Text('Plano'),
              subtitle: const Text('Free'),
              trailing: const Chip(label: Text('Gratuito')),
            ),
          ),

          const SizedBox(height: 16),

          // Info
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

          // Limits info
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Limites do Plano Free', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                _limitTile('Produtos', '3', Icons.inventory_2),
                _limitTile('Vendas', '5', Icons.shopping_cart),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Logout
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
}
