import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/colmeia_repository.dart';
import '../../shared/widgets/hex_badge.dart';
import '../../shared/widgets/loading_error_view.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('DEFINIÇÕES')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User card
          if (user != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.honey.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.honey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      user.nome.isNotEmpty
                          ? user.nome[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: AppTheme.honey,
                          fontSize: 22,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.nome,
                          style: const TextStyle(
                              color: AppTheme.wax,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(user.email,
                          style: const TextStyle(
                              color: AppTheme.bark30, fontSize: 12)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (user.isAdmin
                              ? Colors.purple
                              : AppTheme.honey).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.isAdmin ? 'Administrador' : 'Apicultor',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: user.isAdmin
                                  ? Colors.purpleAccent
                                  : AppTheme.honeyLt),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),

          const SizedBox(height: 24),
          const _SectionHeader('AS MINHAS COLMEIAS'),
          const SizedBox(height: 8),
          _HivesList(),

          const SizedBox(height: 24),
          const _SectionHeader('CONTA'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.danger),
              title: const Text('Terminar sessão',
                  style: TextStyle(color: AppTheme.danger)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppTheme.card,
                    title: const Text('Terminar sessão?',
                        style: TextStyle(color: AppTheme.wax)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar',
                              style: TextStyle(color: AppTheme.bark30))),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sair')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authProvider.notifier).logout();
                }
              },
            ),
          ),

          const SizedBox(height: 32),
          const Center(
            child: HexBadge(size: 32),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Colmeia Smart v1.0',
                style: TextStyle(color: AppTheme.bark30, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _HivesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colmeiasAsync = ref.watch(colmeiasProvider);

    return colmeiasAsync.when(
      loading: () => const LoadingView(),
      error: (_, _) =>
          const ErrorView(message: 'Erro ao carregar colmeias.'),
      data: (colmeias) {
        if (colmeias.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Sem colmeias registadas.',
                style: TextStyle(color: AppTheme.bark30)),
          );
        }
        return Column(
          children: colmeias.map((c) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.bark60.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.hive_rounded,
                    color: AppTheme.honey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nome,
                          style: const TextStyle(
                              color: AppTheme.wax,
                              fontWeight: FontWeight.w600)),
                      if (c.macAddress != null)
                        Text('MAC: ${c.macAddress}',
                            style: const TextStyle(
                                color: AppTheme.bark30,
                                fontSize: 11,
                                fontFamily: 'monospace')),
                      if (c.localizacao != null)
                        Text(c.localizacao!,
                            style: const TextStyle(
                                color: AppTheme.bark30, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.danger, size: 20),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppTheme.card,
                        title: Text('Eliminar "${c.nome}"?',
                            style: const TextStyle(color: AppTheme.wax)),
                        content: const Text(
                            'Esta acção é irreversível.',
                            style: TextStyle(color: AppTheme.bark30)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar',
                                  style:
                                      TextStyle(color: AppTheme.bark30))),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Eliminar')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(colmeiaRepositoryProvider)
                          .deleteColmeia(c.id);
                      ref.invalidate(colmeiasProvider);
                    }
                  },
                ),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.bark30,
          letterSpacing: 1.2));
}
