import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/colmeia_repository.dart';
import '../../data/repositories/leitura_repository.dart';
import '../../data/services/ble_service.dart';
import '../../shared/widgets/loading_error_view.dart';

class BleSyncPage extends ConsumerWidget {
  const BleSyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.watch(bleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SINCRONIZAÇÃO BLE'),
        actions: [
          if (ble.status != BleStatus.idle && ble.status != BleStatus.completed)
            IconButton(
              icon: const Icon(Icons.stop_rounded, color: AppTheme.danger),
              onPressed: () {
                ref.read(bleProvider.notifier).stopScan();
                ref.read(bleProvider.notifier).reset();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          _StatusCard(ble: ble),
          const SizedBox(height: 16),

          // Scan / action button
          _ActionButton(ble: ble),
          const SizedBox(height: 20),

          // Discovered devices
          if (ble.status == BleStatus.scanning && ble.devices.isNotEmpty) ...[
            const _SectionHeader('DISPOSITIVOS ENCONTRADOS'),
            ...ble.devices.map((r) => _DeviceTile(result: r)),
            const SizedBox(height: 16),
          ],

          // Pending sync section
          const _SectionHeader('DADOS PENDENTES'),
          const SizedBox(height: 8),
          _PendingSection(),
        ],
      ),
    );
  }
}

// ─── Status card ───────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final BleState ble;
  const _StatusCard({required this.ble});

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, subtitle) = switch (ble.status) {
      BleStatus.idle      => (Icons.bluetooth_rounded,          AppTheme.bark30, 'Pronto',             'Inicia um scan para encontrar o ESP32.'),
      BleStatus.scanning  => (Icons.bluetooth_searching_rounded, AppTheme.honeyLt,'A fazer scan…',     'À procura de dispositivos BLE.'),
      BleStatus.connecting=> (Icons.bluetooth_connected_rounded, AppTheme.honey,  'A ligar…',           'A estabelecer ligação ao ESP32.'),
      BleStatus.syncing   => (Icons.sync_rounded,               AppTheme.leafLt, 'A sincronizar…',    '${ble.linesReceived} linhas recebidas.'),
      BleStatus.completed => (Icons.check_circle_rounded,       AppTheme.leafLt, 'Concluído',          '${ble.linesReceived} leituras recebidas.'),
      BleStatus.error     => (Icons.error_rounded,              AppTheme.danger,  'Erro',              ble.errorMessage ?? ''),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: AppTheme.wax,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text(subtitle,
                style: const TextStyle(color: AppTheme.bark30, fontSize: 12)),
          ]),
        ),
        if (ble.status == BleStatus.scanning || ble.status == BleStatus.syncing)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppTheme.honey),
          ),
      ]),
    );
  }
}

// ─── Action button ─────────────────────────────────────────────────────────

class _ActionButton extends ConsumerWidget {
  final BleState ble;
  const _ActionButton({required this.ble});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ble.status == BleStatus.scanning) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.bark30,
            side: const BorderSide(color: AppTheme.bark60)),
        onPressed: () => ref.read(bleProvider.notifier).stopScan(),
        icon: const Icon(Icons.stop_rounded),
        label: const Text('Parar scan'),
      );
    }
    if (ble.status == BleStatus.connecting || ble.status == BleStatus.syncing) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () => ref.read(bleProvider.notifier).startScan(),
        icon: const Icon(Icons.bluetooth_searching_rounded),
        label: const Text('Iniciar scan BLE'),
      ),
    );
  }
}

// ─── Device tile ───────────────────────────────────────────────────────────

class _DeviceTile extends ConsumerWidget {
  final ScanResult result;
  const _DeviceTile({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colmeiasAsync = ref.watch(colmeiasProvider);
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : result.device.remoteId.str;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: AppTheme.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: const Icon(Icons.memory_rounded, color: AppTheme.honey),
        title: Text(name,
            style: const TextStyle(color: AppTheme.wax, fontSize: 14)),
        subtitle: Text(result.device.remoteId.str,
            style: const TextStyle(
                color: AppTheme.bark30, fontSize: 11, fontFamily: 'monospace')),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12)),
          onPressed: () => _selectColmeia(context, ref, colmeiasAsync),
          child: const Text('Ligar'),
        ),
      ),
    );
  }

  Future<void> _selectColmeia(
      BuildContext context, WidgetRef ref, AsyncValue colmeiasAsync) async {
    final colmeias = colmeiasAsync.valueOrNull ?? [];
    if (colmeias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cria uma colmeia primeiro.')));
      return;
    }

    final selected = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Selecciona a colmeia',
            style: TextStyle(color: AppTheme.wax)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: colmeias.map((c) => ListTile(
            title: Text(c.nome,
                style: const TextStyle(color: AppTheme.wax)),
            subtitle: c.macAddress != null
                ? Text(c.macAddress!,
                    style: const TextStyle(
                        color: AppTheme.bark30, fontSize: 11))
                : null,
            onTap: () => Navigator.pop(context, c),
          )).toList(),
        ),
      ),
    );

    if (selected != null) {
      await ref
          .read(bleProvider.notifier)
          .connectAndSync(result.device, selected.id);
    }
  }
}

// ─── Pending section ───────────────────────────────────────────────────────

class _PendingSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colmeiasAsync = ref.watch(colmeiasProvider);

    return colmeiasAsync.when(
      loading: () => const LoadingView(),
      error: (_, _) => const SizedBox.shrink(),
      data: (colmeias) {
        if (colmeias.isEmpty) return const SizedBox.shrink();

        return Column(
          children: colmeias.map((c) {
            final count = ref.read(leituraRepositoryProvider).pendingCount(c.id);
            if (count == 0) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.honey.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.cloud_upload_rounded,
                    color: AppTheme.honey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nome,
                          style: const TextStyle(
                              color: AppTheme.wax, fontWeight: FontWeight.w600)),
                      Text('$count leituras pendentes',
                          style: const TextStyle(
                              color: AppTheme.bark30, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12)),
                  onPressed: () async {
                    try {
                      final n = await ref
                          .read(leituraRepositoryProvider)
                          .syncPending(c.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('$n leituras sincronizadas!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Sem internet. Tenta mais tarde.')));
                      }
                    }
                  },
                  child: const Text('Sincronizar'),
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
