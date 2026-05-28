import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/colmeia.dart';
import '../../data/repositories/colmeia_repository.dart';
import '../../data/repositories/leitura_repository.dart';
import '../../shared/widgets/hex_badge.dart';
import '../../shared/widgets/loading_error_view.dart';
import 'hive_detail_page.dart';

class HivesListPage extends ConsumerWidget {
  const HivesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colmeiasAsync = ref.watch(colmeiasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          HexBadge(size: 28),
          SizedBox(width: 10),
          Text('COLMEIA SMART'),
        ]),
      ),
      body: colmeiasAsync.when(
        loading: () => const LoadingView(),
        error:   (e, _) => ErrorView(
          message: 'Erro ao carregar colmeias.',
          onRetry: () => ref.invalidate(colmeiasProvider),
        ),
        data: (colmeias) {
          if (colmeias.isEmpty) {
            return _EmptyState(
              onAdd: () => _showAddDialog(context, ref),
            );
          }
          return RefreshIndicator(
            color: AppTheme.honey,
            backgroundColor: AppTheme.card,
            onRefresh: () async => ref.invalidate(colmeiasProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: colmeias.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _HiveCard(
                colmeia: colmeias[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HiveDetailPage(colmeia: colmeias[i]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.honey,
        foregroundColor: AppTheme.bark,
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final nomeCtrl = TextEditingController();
    final macCtrl  = TextEditingController();
    final locCtrl  = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: const Text('Nova Colmeia',
              style: TextStyle(color: AppTheme.wax)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(error!,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                ),
              TextField(
                controller: nomeCtrl,
                style: const TextStyle(color: AppTheme.wax),
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locCtrl,
                style: const TextStyle(color: AppTheme.wax),
                decoration: const InputDecoration(labelText: 'Localização (opcional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: macCtrl,
                style: const TextStyle(
                    color: AppTheme.wax, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'MAC do ESP32 (opcional)',
                  hintText: '28:05:A5:74:07:8C',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppTheme.bark30)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nomeCtrl.text.trim().isEmpty) {
                  setState(() => error = 'O nome é obrigatório.');
                  return;
                }
                try {
                  await ref.read(colmeiaRepositoryProvider).createColmeia(
                    nome: nomeCtrl.text.trim(),
                    localizacao: locCtrl.text.trim().isEmpty
                        ? null
                        : locCtrl.text.trim(),
                    macAddress: macCtrl.text.trim().isEmpty
                        ? null
                        : macCtrl.text.trim().toUpperCase(),
                  );
                  ref.invalidate(colmeiasProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setState(() => error = e.toString().replaceAll('Exception: ', ''));
                }
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    nomeCtrl.dispose();
    macCtrl.dispose();
    locCtrl.dispose();
  }
}

// ─── Hive card ─────────────────────────────────────────────────────────────

class _HiveCard extends ConsumerWidget {
  final Colmeia colmeia;
  final VoidCallback onTap;
  const _HiveCard({required this.colmeia, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leiturasAsync = ref.watch(leiturasProvider(colmeia.id));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.honey.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(colmeia.nome,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: AppTheme.wax)),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.bark30),
            ]),
            if (colmeia.localizacao != null) ...[
              const SizedBox(height: 2),
              Text(colmeia.localizacao!,
                  style: const TextStyle(fontSize: 11, color: AppTheme.bark30)),
            ],
            const SizedBox(height: 12),
            leiturasAsync.when(
              loading: () => const LinearProgressIndicator(
                  color: AppTheme.honey, backgroundColor: AppTheme.bark60),
              error: (_, _) => const Text('Sem dados',
                  style: TextStyle(color: AppTheme.bark30, fontSize: 12)),
              data: (leituras) {
                if (leituras.isEmpty) {
                  return const Text('A aguardar primeiras leituras…',
                      style: TextStyle(color: AppTheme.bark30, fontSize: 12));
                }
                final l = leituras.last;
                return Column(
                  children: [
                    Row(children: [
                      _Stat('${l.temperatura.toStringAsFixed(1)}°C',
                          Icons.thermostat_rounded, AppTheme.danger),
                      const SizedBox(width: 16),
                      _Stat('${l.humidade.toStringAsFixed(0)}%',
                          Icons.water_drop_rounded, AppTheme.sky),
                      const SizedBox(width: 16),
                      _Stat('${l.peso.toStringAsFixed(1)} kg',
                          Icons.scale_rounded, AppTheme.honey),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.access_time_rounded,
                          size: 11, color: AppTheme.bark30),
                      const SizedBox(width: 4),
                      Text(
                        AppDateUtils.formatDateTime(l.timestamp),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.bark30),
                      ),
                    ]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final IconData icon;
  final Color color;
  const _Stat(this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 4),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HexBadge(size: 72),
          const SizedBox(height: 16),
          const Text('Ainda não tens colmeias registadas.',
              style: TextStyle(color: AppTheme.bark30, fontSize: 15)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar primeira colmeia'),
          ),
        ],
      ),
    );
  }
}
