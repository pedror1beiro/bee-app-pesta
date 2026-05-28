import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/leitura.dart';

class WeightCard extends StatelessWidget {
  final double peso;
  final List<Leitura> leituras;

  const WeightCard({super.key, required this.peso, required this.leituras});

  @override
  Widget build(BuildContext context) {
    final gain = leituras.length > 1
        ? peso - leituras.first.peso
        : 0.0;
    final progress = ((peso - 20.0) / 30.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: const Border(top: BorderSide(color: AppTheme.honey, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.scale_rounded, color: AppTheme.honey, size: 16),
            const SizedBox(width: 6),
            const Text('PESO TOTAL',
                style: TextStyle(
                    fontSize: 10, color: AppTheme.bark30, letterSpacing: 0.8)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.leaf.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)} kg',
                style: const TextStyle(
                    fontSize: 9, color: AppTheme.leafLt, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(peso.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w700, color: AppTheme.honey, height: 1)),
            const Padding(
              padding: EdgeInsets.only(bottom: 4, left: 4),
              child: Text('kg', style: TextStyle(fontSize: 14, color: AppTheme.bark30)),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.bark60.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.honey),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Capacidade estimada de mel',
              style: TextStyle(fontSize: 10, color: AppTheme.bark30)),
        ],
      ),
    );
  }
}
