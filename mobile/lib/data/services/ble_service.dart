import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/ble_constants.dart';
import '../models/leitura.dart';
import 'api_service.dart' show storageServiceProvider;
import 'storage_service.dart';

// ─── State ─────────────────────────────────────────────────────────────────

enum BleStatus { idle, scanning, connecting, syncing, completed, error }

class BleState {
  final BleStatus status;
  final List<ScanResult> devices;
  final BluetoothDevice? activeDevice;
  final int linesReceived;
  final int linesSynced;
  final String? errorMessage;

  const BleState({
    this.status = BleStatus.idle,
    this.devices = const [],
    this.activeDevice,
    this.linesReceived = 0,
    this.linesSynced = 0,
    this.errorMessage,
  });

  BleState copyWith({
    BleStatus? status,
    List<ScanResult>? devices,
    BluetoothDevice? activeDevice,
    int? linesReceived,
    int? linesSynced,
    String? errorMessage,
  }) =>
      BleState(
        status:        status        ?? this.status,
        devices:       devices       ?? this.devices,
        activeDevice:  activeDevice  ?? this.activeDevice,
        linesReceived: linesReceived ?? this.linesReceived,
        linesSynced:   linesSynced   ?? this.linesSynced,
        errorMessage:  errorMessage  ?? this.errorMessage,
      );
}

// ─── Provider ──────────────────────────────────────────────────────────────

final bleProvider =
    StateNotifierProvider<BleNotifier, BleState>((ref) {
  return BleNotifier(ref.read(storageServiceProvider));
});

// ─── Notifier ──────────────────────────────────────────────────────────────

class BleNotifier extends StateNotifier<BleState> {
  BleNotifier(this._storage) : super(const BleState());

  final StorageService _storage;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _dataSub;
  BluetoothCharacteristic? _cmdChar;
  final List<Leitura> _received = [];
  final StringBuffer _buf = StringBuffer();
  int? _colmeiaId;

  // ─── Scan ────────────────────────────────────────────────────

  Future<void> startScan() async {
    if (state.status == BleStatus.scanning) return;
    await FlutterBluePlus.stopScan();
    state = const BleState(status: BleStatus.scanning);

    await FlutterBluePlus.startScan(
      withServices: [Guid(BleConstants.serviceUuid)],
      timeout: const Duration(seconds: 15),
    );

    _scanSub = FlutterBluePlus.scanResults.listen(
      (results) => state = state.copyWith(devices: results),
    );
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    state = state.copyWith(status: BleStatus.idle);
  }

  // ─── Connect + sync ──────────────────────────────────────────

  Future<void> connectAndSync(BluetoothDevice device, int colmeiaId) async {
    stopScan();
    _colmeiaId = colmeiaId;
    _received.clear();
    _buf.clear();

    state = state.copyWith(
      status: BleStatus.connecting,
      activeDevice: device,
      linesReceived: 0,
    );

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      await device.requestMtu(512);

      final services = await device.discoverServices();
      final svc = services.firstWhere(
        (s) => s.serviceUuid.str128.toLowerCase() ==
            BleConstants.serviceUuid.toLowerCase(),
      );

      final dataChar = svc.characteristics.firstWhere(
        (c) => c.characteristicUuid.str128.toLowerCase() ==
            BleConstants.charDataUuid.toLowerCase(),
      );
      _cmdChar = svc.characteristics.firstWhere(
        (c) => c.characteristicUuid.str128.toLowerCase() ==
            BleConstants.charCommandUuid.toLowerCase(),
      );

      await dataChar.setNotifyValue(true);
      _dataSub = dataChar.onValueReceived.listen(_onData);

      state = state.copyWith(status: BleStatus.syncing);
      await _cmdChar!.write(utf8.encode(BleConstants.cmdSync));
    } catch (e) {
      state = state.copyWith(
        status: BleStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ─── Incoming BLE data ───────────────────────────────────────

  void _onData(List<int> data) {
    _buf.write(utf8.decode(data, allowMalformed: true));
    final lines = _buf.toString().split('\n');

    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line == BleConstants.cmdEnd) { _finish(); return; }
      if (line.isEmpty || line.startsWith('timestamp')) continue;

      final l = Leitura.fromCsvLine(line, colmeiaId: _colmeiaId!);
      if (l != null) {
        _received.add(l);
        state = state.copyWith(linesReceived: _received.length);
      }
    }
    _buf
      ..clear()
      ..write(lines.last);
  }

  Future<void> _finish() async {
    _dataSub?.cancel();
    await _cmdChar?.device.disconnect();

    if (_received.isEmpty) {
      state = state.copyWith(status: BleStatus.completed);
      return;
    }

    // Persist locally regardless of connectivity
    await _storage.savePendingLeituras(_received);
    state = state.copyWith(
      status: BleStatus.completed,
      linesReceived: _received.length,
      linesSynced: 0,
      errorMessage: 'Dados guardados. Sincroniza quando tiveres internet.',
    );

    _received.clear();
    _buf.clear();
  }

  void reset() => state = const BleState();

  @override
  void dispose() {
    _scanSub?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }
}
