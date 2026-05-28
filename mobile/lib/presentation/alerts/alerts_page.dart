import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/alerta.dart';
import '../../data/repositories/colmeia_repository.dart';
import '../../shared/widgets/loading_error_view.dart';

class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertasAsync = ref.watch(alertasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ALERTAS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(alertasProvider),
          ),
        ],
      ),
      body: alertasAsync.when(
        loading: () => const LoadingView(),
        error:   (e, _) => ErrorView(
          message: 'Erro ao carregar alertas.',
          onRetry: () => ref.invalidate(alertasProvider),
        ),
        data: (alertas) {
          final unread = alertas.where((a) => !a.lido).toList();
          final read   = alertas.where((a) =>  a.lido).toList();

          if (alertas.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 56, color: AppTheme.bark30),
                  SizedBox(height: 12),
                  Text('Sem alertas.',
                      style: TextStyle(color: AppTheme.bark30, fontSize: 15)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.honey,
            backgroundColor: AppTheme.card,
            onRefresh: () async => ref.invalidate(alertasProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (unread.isNotEmpty) ...[
                  const _GroupHeader('NÃO LIDOS'),
                  ...unread.map((a) => _AlertTile(
                    alerta: a,
                    onMarkRead: () async {
                      await ref.read(colmeiaRepositoryProvider).markAlertaAsRead(a.id);
                      ref.invalidate(alertasProvider);
                    },
                  )),
                  const SizedBox(height: 16),
                ],
                if (read.isNotEmpty) ...[
                  const _GroupHeader('LIDOS'),
                  ...read.map((a) => _AlertTile(alerta: a)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String text;
  const _GroupHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.bark30,
                letterSpacing: 1.2)),
      );
}

class _AlertTile extends StatelessWidget {
  final Alerta alerta;
  final VoidCallback? onMarkRead;
  const _AlertTile({required this.alerta, this.onMarkRead});

  static const _icons = {
    'temperatura': Icons.thermostat_rounded,
    'humidade':    Icons.water_drop_rounded,
    'peso':        Icons.scale_rounded,
    'bateria':     Icons.battery_alert_rounded,
  };

  static const _colors = {
    'temperatura': AppTheme.danger,
    'humidade':    AppTheme.sky,
    'peso':        AppTheme.honey,
    'bateria':     AppTheme.leafLt,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[alerta.tipo] ?? AppTheme.honey;
    final icon  = _icons[alerta.tipo]  ?? Icons.warning_rounded;

    return Opacity(
      opacity: alerta.lido ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: alerta.lido
                  ? AppTheme.bark60.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alerta.mensagem,
                      style: const TextStyle(
                          color: AppTheme.wax,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(AppDateUtils.formatFull(alerta.criadoEm),
                      style: const TextStyle(
                          color: AppTheme.bark30, fontSize: 10)),
                ],
              ),
            ),
            if (onMarkRead != null)
              IconButton(
                icon: const Icon(Icons.check_circle_outline_rounded,
                    color: AppTheme.leafLt, size: 20),
                tooltip: 'Marcar como lido',
                onPressed: onMarkRead,
              ),
          ],
        ),
      ),
    );
  }
}
