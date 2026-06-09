import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/colmeia.dart';
import '../../data/models/leitura.dart';
import '../../data/repositories/colmeia_repository.dart';
import '../../data/repositories/leitura_repository.dart';
import '../../shared/widgets/loading_error_view.dart';
import 'widgets/hourly_strip.dart';
import 'widgets/metric_card.dart';
import 'widgets/weight_card.dart';

class HiveDetailPage extends ConsumerStatefulWidget {
  final Colmeia colmeia;
  const HiveDetailPage({super.key, required this.colmeia});

  @override
  ConsumerState<HiveDetailPage> createState() => _HiveDetailPageState();
}

class _HiveDetailPageState extends ConsumerState<HiveDetailPage> {
  late Colmeia _colmeia;
  bool _updatingModo = false;

  @override
  void initState() {
    super.initState();
    _colmeia = widget.colmeia;
  }

  Future<void> _toggleModo() async {
    final novoModo = _colmeia.isPremium ? 'base' : 'premium';
    setState(() => _updatingModo = true);
    try {
      final updated = await ref
          .read(colmeiaRepositoryProvider)
          .updateModo(_colmeia.id, novoModo);
      setState(() => _colmeia = updated);
      ref.invalidate(colmeiasProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Modo alterado para ${novoModo.toUpperCase()}.'),
          backgroundColor: novoModo == 'premium' ? AppTheme.honey : AppTheme.bark60,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erro ao alterar modo.'),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      setState(() => _updatingModo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leiturasAsync = ref.watch(leiturasProvider(_colmeia.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(_colmeia.nome),
        actions: [
          _updatingModo
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.honey),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: _toggleModo,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _colmeia.isPremium
                            ? AppTheme.honey.withValues(alpha: 0.18)
                            : AppTheme.bark60.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _colmeia.isPremium ? AppTheme.honey : AppTheme.bark60,
                          width: 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          _colmeia.isPremium
                              ? Icons.stars_rounded
                              : Icons.battery_saver_rounded,
                          size: 14,
                          color: _colmeia.isPremium ? AppTheme.honey : AppTheme.bark30,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _colmeia.isPremium ? 'PREMIUM' : 'BASE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _colmeia.isPremium ? AppTheme.honey : AppTheme.bark30,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(leiturasProvider(_colmeia.id)),
          ),
        ],
      ),
      body: leiturasAsync.when(
        loading: () => const LoadingView(),
        error:   (e, _) => ErrorView(
          message: 'Erro ao carregar dados.',
          onRetry: () => ref.invalidate(leiturasProvider(_colmeia.id)),
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
