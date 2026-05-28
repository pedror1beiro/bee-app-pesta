import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/leitura.dart';

class HourlyStrip extends StatelessWidget {
  final List<Leitura> leituras;
  const HourlyStrip({super.key, required this.leituras});

  @override
  Widget build(BuildContext context) {
    if (leituras.isEmpty) {
      return const Center(
        child: Text('Sem leituras.',
            style: TextStyle(color: AppTheme.bark30)),
      );
    }
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: leituras.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final r = leituras[i];
          final isLatest = i == leituras.length - 1;
          return _HourPill(leitura: r, isLatest: isLatest);
        },
      ),
    );
  }
}

class _HourPill extends StatelessWidget {
  final Leitura leitura;
  final bool isLatest;
  const _HourPill({required this.leitura, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isLatest ? AppTheme.honey : AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLatest ? AppTheme.honey : AppTheme.bark60.withValues(alpha: 0.5),
        ),
        boxShadow: isLatest
            ? [BoxShadow(
                color: AppTheme.honey.withValues(alpha: 0.35),
                blurRadius: 12, spreadRadius: 1)]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppDateUtils.formatTime(leitura.timestamp),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isLatest ? AppTheme.bark : AppTheme.bark30,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${leitura.temperatura.toStringAsFixed(1)}°',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isLatest ? AppTheme.bark : AppTheme.wax,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${leitura.humidade.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              color: isLatest ? AppTheme.bark60 : AppTheme.bark30,
            ),
          ),
        ],
      ),
    );
  }
}
