import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(const ColmeiaSmartApp());
}

// ─────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────
class AppTheme {
  static const bark    = Color(0xFF1C110A);
  static const bark60  = Color(0xFF5C3A1E);
  static const bark30  = Color(0xFFA07850);
  static const honey   = Color(0xFFE8922A);
  static const honeyLt = Color(0xFFF5B95D);
  static const wax     = Color(0xFFFFF8EC);
  static const leaf    = Color(0xFF3D6B45);
  static const leafLt  = Color(0xFF6FAA79);
  static const sky     = Color(0xFF4A90B8);
  static const danger  = Color(0xFFD94F4F);
  static const surface = Color(0xFF2A1A0C);
  static const card    = Color(0xFF362213);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bark,
    colorScheme: const ColorScheme.dark(
      primary: honey,
      secondary: leafLt,
      surface: surface,
      onSurface: wax,
    ),
    fontFamily: 'Courier', // fallback; in real project add Google Fonts
    appBarTheme: const AppBarTheme(
      backgroundColor: bark,
      foregroundColor: wax,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Courier',
        color: wax,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: honey,
      unselectedLabelColor: bark30,
      indicatorColor: honey,
      indicatorSize: TabBarIndicatorSize.label,
    ),
  );
}

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────
class HiveReading {
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final double weight;

  const HiveReading({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.weight,
  });

  String get timeLabel =>
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

  String get dateLabel =>
      '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')} ${timeLabel}';
}

// ─────────────────────────────────────────────
// MOCK DATA GENERATOR
// ─────────────────────────────────────────────
List<HiveReading> generateMockReadings() {
  final rng = Random(42);
  final readings = <HiveReading>[];
  final now = DateTime.now();

  for (int daysBack = 6; daysBack >= 0; daysBack--) {
    for (int hour = 0; hour < 24; hour++) {
      final ts = now.subtract(Duration(days: daysBack, hours: hour));
      readings.add(HiveReading(
        timestamp: ts,
        temperature: 32.0 + sin(hour / 4.0) * 2.5 + rng.nextDouble() * 0.6,
        humidity:    62.0 + cos(hour / 5.0) * 8.0 + rng.nextDouble() * 2.0,
        weight:      26.5 + (6 - daysBack) * 0.3 + hour * 0.008 + rng.nextDouble() * 0.15,
      ));
    }
  }
  return readings;
}

// ─────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────
class ColmeiaSmartApp extends StatelessWidget {
  const ColmeiaSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Colmeia Smart',
      theme: AppTheme.theme,
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ─────────────────────────────────────────────
// MAIN SHELL (Tab Navigator)
// ─────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final List<HiveReading> _allReadings = generateMockReadings();

  // BLE / sync state
  bool _isSyncing = false;
  bool _isConnected = false;
  DateTime? _lastSync;

  List<HiveReading> get _todayReadings {
    final today = DateTime.now();
    return _allReadings.where((r) =>
      r.timestamp.day == today.day &&
      r.timestamp.month == today.month).toList();
  }

  HiveReading? get _latestReading =>
      _allReadings.isNotEmpty ? _allReadings.last : null;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _simulateSync() async {
    setState(() { _isSyncing = true; });
    await Future.delayed(const Duration(seconds: 3));
    final rng = Random();
    _allReadings.add(HiveReading(
      timestamp: DateTime.now(),
      temperature: 33.5 + rng.nextDouble() * 0.8,
      humidity:    68.0 + rng.nextDouble() * 4.0,
      weight:      _allReadings.last.weight + 0.05 + rng.nextDouble() * 0.1,
    ));
    setState(() {
      _isSyncing = false;
      _isConnected = true;
      _lastSync = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          _HexBadge(size: 28),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('COLMEIA SMART', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppTheme.wax)),
              Text('Protótipo', style: TextStyle(fontSize: 10, color: AppTheme.bark30, letterSpacing: 0.3)),
            ],
          ),
        ]),
        actions: [
          _BleBadge(isConnected: _isConnected, isSyncing: _isSyncing),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'DASHBOARD'),
            Tab(text: 'HISTÓRICO'),
            Tab(text: 'SISTEMA'),
          ],
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          unselectedLabelStyle: const TextStyle(fontSize: 11, letterSpacing: 1.0),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          DashboardTab(
            latest: _latestReading,
            todayReadings: _todayReadings,
            lastSync: _lastSync,
            isSyncing: _isSyncing,
            onSync: _isSyncing ? null : _simulateSync,
          ),
          HistoricoTab(readings: _allReadings),
          const SistemaTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DASHBOARD TAB
// ─────────────────────────────────────────────
class DashboardTab extends StatelessWidget {
  final HiveReading? latest;
  final List<HiveReading> todayReadings;
  final DateTime? lastSync;
  final bool isSyncing;
  final VoidCallback? onSync;

  const DashboardTab({
    super.key,
    required this.latest,
    required this.todayReadings,
    required this.lastSync,
    required this.isSyncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hive identity card
          _HiveIdentityCard(lastSync: lastSync, isSyncing: isSyncing),
          const SizedBox(height: 16),

          // Metrics grid
          if (latest != null) ...[
            Row(children: [
              Expanded(child: _MetricCard(
                label: 'TEMPERATURA',
                value: '${latest!.temperature.toStringAsFixed(1)}°C',
                icon: Icons.thermostat_rounded,
                accentColor: AppTheme.danger,
                statusText: latest!.temperature > 36 ? 'ATENÇÃO' : 'Normal',
                isWarning: latest!.temperature > 36,
              )),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard(
                label: 'HUMIDADE',
                value: '${latest!.humidity.toStringAsFixed(0)}%',
                icon: Icons.water_drop_rounded,
                accentColor: AppTheme.sky,
                statusText: latest!.humidity > 70 ? 'ALTA' : 'Normal',
                isWarning: latest!.humidity > 70,
              )),
            ]),
            const SizedBox(height: 12),
            _WeightCard(reading: latest!, allReadings: todayReadings),
          ],
          const SizedBox(height: 20),

          // Hourly strip title
          const _SectionLabel('LEITURAS DE HOJE — HORA A HORA'),
          const SizedBox(height: 10),
          _HourlyStrip(readings: todayReadings),
          const SizedBox(height: 24),

          // Sync button
          _SyncButton(isSyncing: isSyncing, onSync: onSync),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HIVE IDENTITY CARD
// ─────────────────────────────────────────────
class _HiveIdentityCard extends StatelessWidget {
  final DateTime? lastSync;
  final bool isSyncing;

  const _HiveIdentityCard({required this.lastSync, required this.isSyncing});

  @override
  Widget build(BuildContext context) {
    final syncText = lastSync != null
        ? '${lastSync!.hour.toString().padLeft(2,'0')}:${lastSync!.minute.toString().padLeft(2,'0')}'
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.honey.withOpacity(0.25), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Colmeia #3 — Sector B',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.wax)),
                const SizedBox(height: 4),
                const Text('ESP32 · MAC 24:6F:28:AA:BB',
                    style: TextStyle(fontSize: 11, color: AppTheme.bark30, letterSpacing: 0.3)),
                const SizedBox(height: 10),
                Row(children: [
                  _StatusPill(
                    label: isSyncing ? 'A sincronizar…' : 'Online',
                    color: isSyncing ? AppTheme.honey : AppTheme.leafLt,
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(label: 'Sync $syncText', color: AppTheme.bark30),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              _HexBadge(size: 48, large: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
    );
  }
}

// ─────────────────────────────────────────────
// METRIC CARD
// ─────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String statusText;
  final bool isWarning;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.statusText,
    required this.isWarning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border(top: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: accentColor, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.bark30, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: accentColor,
            height: 1,
          )),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (isWarning ? AppTheme.honey : AppTheme.leaf).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusText,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isWarning ? AppTheme.honeyLt : AppTheme.leafLt,
                  letterSpacing: 0.5,
                )),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WEIGHT CARD (full width)
// ─────────────────────────────────────────────
class _WeightCard extends StatelessWidget {
  final HiveReading reading;
  final List<HiveReading> allReadings;

  const _WeightCard({required this.reading, required this.allReadings});

  @override
  Widget build(BuildContext context) {
    final weekGain = allReadings.isNotEmpty
        ? reading.weight - allReadings.first.weight
        : 0.0;
    final progress = ((reading.weight - 20.0) / 30.0).clamp(0.0, 1.0);

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
            const Text('PESO TOTAL', style: TextStyle(fontSize: 10, color: AppTheme.bark30, letterSpacing: 0.8)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.leaf.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${weekGain.toStringAsFixed(2)} kg esta semana',
                style: const TextStyle(fontSize: 9, color: AppTheme.leafLt, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${reading.weight.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppTheme.honey, height: 1)),
            const Padding(
              padding: EdgeInsets.only(bottom: 4, left: 4),
              child: Text('kg', style: TextStyle(fontSize: 16, color: AppTheme.bark30)),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.bark60.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.honey),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 5),
          const Text('Capacidade estimada de mel', style: TextStyle(fontSize: 10, color: AppTheme.bark30)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOURLY STRIP
// ─────────────────────────────────────────────
class _HourlyStrip extends StatelessWidget {
  final List<HiveReading> readings;
  const _HourlyStrip({required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(
        child: Text('Sem leituras hoje.', style: TextStyle(color: AppTheme.bark30)),
      );
    }
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: readings.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = readings[i];
          final isLatest = i == readings.length - 1;
          return _HourPill(reading: r, isLatest: isLatest);
        },
      ),
    );
  }
}

class _HourPill extends StatelessWidget {
  final HiveReading reading;
  final bool isLatest;
  const _HourPill({required this.reading, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isLatest ? AppTheme.honey : AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLatest ? AppTheme.honey : AppTheme.bark60.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: isLatest ? [
          BoxShadow(color: AppTheme.honey.withOpacity(0.35), blurRadius: 12, spreadRadius: 1)
        ] : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            reading.timeLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isLatest ? AppTheme.bark : AppTheme.bark30,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${reading.temperature.toStringAsFixed(1)}°',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isLatest ? AppTheme.bark : AppTheme.wax,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${reading.humidity.toStringAsFixed(0)}%',
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

// ─────────────────────────────────────────────
// SYNC BUTTON
// ─────────────────────────────────────────────
class _SyncButton extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback? onSync;
  const _SyncButton({required this.isSyncing, required this.onSync});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onSync,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSyncing ? AppTheme.bark60 : AppTheme.honey,
          foregroundColor: AppTheme.bark,
          elevation: isSyncing ? 0 : 6,
          shadowColor: AppTheme.honey.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSyncing)
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.honeyLt),
              )
            else
              const Icon(Icons.bluetooth_searching_rounded, size: 20),
            const SizedBox(width: 10),
            Text(
              isSyncing ? 'A procurar ESP32 (Colmeia_Smart)…' : 'Sincronizar via BLE',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HISTÓRICO TAB
// ─────────────────────────────────────────────
class HistoricoTab extends StatelessWidget {
  final List<HiveReading> readings;
  const HistoricoTab({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    final sorted = readings.reversed.toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const _SectionLabel('TODAS AS LEITURAS'),
              const Spacer(),
              TextButton.icon(
                onPressed: () {}, // TODO: export CSV
                icon: const Icon(Icons.download_rounded, size: 16, color: AppTheme.bark30),
                label: const Text('Exportar CSV',
                    style: TextStyle(fontSize: 12, color: AppTheme.bark30)),
              ),
            ],
          ),
        ),
        // Table header
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              Expanded(flex: 3, child: _TableHeader('DATA / HORA')),
              Expanded(flex: 2, child: _TableHeader('TEMP')),
              Expanded(flex: 2, child: _TableHeader('HR')),
              Expanded(flex: 2, child: _TableHeader('PESO')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final r = sorted[i];
              final isEven = i % 2 == 0;
              return Container(
                color: isEven ? AppTheme.bark : AppTheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(r.dateLabel,
                        style: const TextStyle(fontSize: 11, color: AppTheme.bark30, fontFamily: 'Courier'))),
                    Expanded(flex: 2, child: Text('${r.temperature.toStringAsFixed(1)}°C',
                        style: const TextStyle(fontSize: 12, color: AppTheme.danger, fontFamily: 'Courier'))),
                    Expanded(flex: 2, child: Text('${r.humidity.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, color: AppTheme.sky, fontFamily: 'Courier'))),
                    Expanded(flex: 2, child: Text('${r.weight.toStringAsFixed(2)} kg',
                        style: const TextStyle(fontSize: 12, color: AppTheme.honey, fontFamily: 'Courier'))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: AppTheme.bark30, letterSpacing: 0.8,
        ));
  }
}

// ─────────────────────────────────────────────
// SISTEMA TAB
// ─────────────────────────────────────────────
class SistemaTab extends StatelessWidget {
  const SistemaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SysItem(icon: Icons.battery_charging_full_rounded, label: 'Bateria (2× 18650)', value: '78% · ~48h', color: AppTheme.leafLt, barValue: 0.78),
        SizedBox(height: 10),
        _SysItem(icon: Icons.bluetooth_rounded, label: 'BLE (Colmeia_Smart)', value: 'Aguarda ligação', color: AppTheme.bark30, barValue: 0.0),
        SizedBox(height: 10),
        _SysItem(icon: Icons.sd_card_rounded, label: 'MicroSD', value: '4.1 MB / 32 GB', color: AppTheme.sky, barValue: 0.02),
        SizedBox(height: 10),
        _SysItem(icon: Icons.access_time_rounded, label: 'RTC DS3231', value: 'Sincronizado · <2 ppm drift', color: AppTheme.leafLt, barValue: 1.0),
        SizedBox(height: 10),
        _SysItem(icon: Icons.nights_stay_rounded, label: 'Deep Sleep', value: 'Próximo ciclo: 47 min', color: AppTheme.honey, barValue: 0.22),
        SizedBox(height: 10),
        _SysItem(icon: Icons.thermostat_rounded, label: 'Sensor SHT30', value: 'Operacional · Cal. 0.0°C', color: AppTheme.danger, barValue: 1.0),
        SizedBox(height: 10),
        _SysItem(icon: Icons.scale_rounded, label: 'HX711 Célula de Carga', value: 'Calibrado · Tara 0.00 kg', color: AppTheme.honey, barValue: 1.0),
      ],
    );
  }
}

class _SysItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double barValue;

  const _SysItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.barValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.bark60.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.wax)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 11, color: AppTheme.bark30)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: barValue,
                    backgroundColor: AppTheme.bark60.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: barValue > 0 ? AppTheme.leafLt : AppTheme.danger,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────
class _HexBadge extends StatelessWidget {
  final double size;
  final bool large;
  const _HexBadge({required this.size, this.large = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: _HexPainter(color: AppTheme.honey),
        child: Center(
          child: Text('🐝', style: TextStyle(fontSize: size * 0.45)),
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  final Color color;
  const _HexPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 180) * (60 * i - 30);
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.color != color;
}

class _BleBadge extends StatelessWidget {
  final bool isConnected;
  final bool isSyncing;
  const _BleBadge({required this.isConnected, required this.isSyncing});

  @override
  Widget build(BuildContext context) {
    final color = isSyncing ? AppTheme.honeyLt : isConnected ? AppTheme.leafLt : AppTheme.bark30;
    return Row(
      children: [
        Icon(
          isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
          color: color, size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          isConnected ? 'LIGADO' : 'BLE',
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: AppTheme.bark30, letterSpacing: 1.2,
      ),
    );
  }
}