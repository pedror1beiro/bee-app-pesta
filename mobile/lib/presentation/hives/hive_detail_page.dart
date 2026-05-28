import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/colmeia.dart';
import '../../data/models/leitura.dart';
import '../../data/repositories/leitura_repository.dart';
import '../../shared/widgets/loading_error_view.dart';
import 'widgets/hourly_strip.dart';
import 'widgets/metric_card.dart';
import 'widgets/weight_card.dart';

class HiveDetailPage extends ConsumerWidget {
  final Colmeia colmeia;
  const HiveDetailPage({super.key, required this.colmeia});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leiturasAsync = ref.watch(leiturasProvider(colmeia.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(colmeia.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(leiturasProvider(colmeia.id)),
          ),
        ],
      ),
      body: leiturasAsync.when(
        loading: () => const LoadingView(),
        error:   (e, _) => ErrorView(
          message: 'Erro ao carregar dados.',
          onRetry: () => ref.invalidate(leiturasProvider(colmeia.id)),
        ),
        data: (leituras) {
          if (leituras.isEmpty) {
            return const Center(
              child: Text('Sem dados para esta colmeia.',
                  style: TextStyle(color: AppTheme.bark30)),
            );
          }
          final latest = leituras.last;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Latest readings grid
                Row(children: [
                  Expanded(
                    child: MetricCard(
                      label: 'TEMPERATURA',
                      value: '${latest.temperatura.toStringAsFixed(1)}°C',
                      icon: Icons.thermostat_rounded,
                      accentColor: AppTheme.danger,
                      statusText: latest.temperatura > 36 ? 'ATENÇÃO' : 'Normal',
                      isWarning: latest.temperatura > 36,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: 'HUMIDADE',
                      value: '${latest.humidade.toStringAsFixed(0)}%',
                      icon: Icons.water_drop_rounded,
                      accentColor: AppTheme.sky,
                      statusText: latest.humidade > 70 ? 'ALTA' : 'Normal',
                      isWarning: latest.humidade > 70,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                WeightCard(peso: latest.peso, leituras: leituras),
                const SizedBox(height: 20),

                // Hourly strip
                const _SectionTitle('LEITURAS RECENTES'),
                const SizedBox(height: 10),
                HourlyStrip(leituras: leituras),
                const SizedBox(height: 24),

                // Charts
                const _SectionTitle('TEMPERATURA (°C)'),
                const SizedBox(height: 8),
                _LineCard(
                  leituras: leituras,
                  getValue: (l) => l.temperatura,
                  color: AppTheme.danger,
                  minY: 25,
                  maxY: 45,
                ),
                const SizedBox(height: 16),

                const _SectionTitle('HUMIDADE (%)'),
                const SizedBox(height: 8),
                _LineCard(
                  leituras: leituras,
                  getValue: (l) => l.humidade,
                  color: AppTheme.sky,
                  minY: 0,
                  maxY: 100,
                ),
                const SizedBox(height: 16),

                const _SectionTitle('ATIVIDADE DAS ABELHAS'),
                const SizedBox(height: 8),
                _ActivityCard(leituras: leituras),
                const SizedBox(height: 16),

                const _SectionTitle('BATERIA (V)'),
                const SizedBox(height: 8),
                _LineCard(
                  leituras: leituras,
                  getValue: (l) => l.nivelBateria,
                  color: AppTheme.leafLt,
                  minY: 3.0,
                  maxY: 4.3,
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.bark30,
            letterSpacing: 1.2),
      );
}

// ─── Line chart card ───────────────────────────────────────────────────────

class _LineCard extends StatelessWidget {
  final List<Leitura> leituras;
  final double Function(Leitura) getValue;
  final Color color;
  final double minY;
  final double maxY;

  const _LineCard({
    required this.leituras,
    required this.getValue,
    required this.color,
    required this.minY,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final spots = leituras.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), getValue(e.value)))
        .toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(color: AppTheme.bark30, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (leituras.length / 4).ceilToDouble(),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= leituras.length) return const SizedBox();
                  return Text(
                    AppDateUtils.formatTime(leituras[i].timestamp),
                    style: const TextStyle(color: AppTheme.bark30, fontSize: 9),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Activity bar chart ────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final List<Leitura> leituras;
  const _ActivityCard({required this.leituras});

  @override
  Widget build(BuildContext context) {
    final groups = leituras.asMap().entries.map((e) {
      return BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(
            toY: e.value.entradasAbelhas.toDouble(),
            color: AppTheme.leafLt,
            width: 6,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
        BarChartRodData(
            toY: e.value.saidasAbelhas.toDouble(),
            color: AppTheme.danger,
            width: 6,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
      ]);
    }).toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: BarChart(
        BarChartData(
          barGroups: groups,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i % 4 != 0 || i >= leituras.length) {
                    return const SizedBox();
                  }
                  return Text(
                    AppDateUtils.formatTime(leituras[i].timestamp),
                    style: const TextStyle(color: AppTheme.bark30, fontSize: 9),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
