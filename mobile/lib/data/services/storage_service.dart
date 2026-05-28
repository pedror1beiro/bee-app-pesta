import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/utilizador.dart';
import '../models/leitura.dart';

class StorageService {
  static const _keyAccess  = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUser    = 'user_data';
  static const _boxPending = 'pending_leituras';

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ─── Tokens ────────────────────────────────────────────────
  Future<String?> getAccessToken()  => _secure.read(key: _keyAccess);
  Future<String?> getRefreshToken() => _secure.read(key: _keyRefresh);

  Future<Utilizador?> getUser() async {
    final s = await _secure.read(key: _keyUser);
    if (s == null) return null;
    return Utilizador.fromJsonString(s);
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required Utilizador utilizador,
  }) async {
    await Future.wait([
      _secure.write(key: _keyAccess,  value: accessToken),
      _secure.write(key: _keyRefresh, value: refreshToken),
      _secure.write(key: _keyUser,    value: utilizador.toJsonString()),
    ]);
  }

  Future<void> saveAccessToken(String token) =>
      _secure.write(key: _keyAccess, value: token);

  Future<void> clearAll() => _secure.deleteAll();

  // ─── Offline BLE queue ─────────────────────────────────────
  Box get _box => Hive.box(_boxPending);

  Future<void> savePendingLeituras(List<Leitura> leituras) async {
    for (final l in leituras) {
      final key = '${l.colmeiaId}_${l.timestamp.millisecondsSinceEpoch}';
      await _box.put(key, jsonEncode(l.toJson()));
    }
  }

  List<Leitura> getPendingLeituras(int colmeiaId) {
    return _box.keys
        .where((k) => k.toString().startsWith('${colmeiaId}_'))
        .map((k) {
          final raw = _box.get(k) as String;
          return Leitura.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        })
        .toList();
  }

  Future<void> removePendingLeitura(int colmeiaId, DateTime timestamp) =>
      _box.delete('${colmeiaId}_${timestamp.millisecondsSinceEpoch}');

  Future<void> clearPendingLeituras() => _box.clear();

  int pendingCount(int colmeiaId) =>
      _box.keys.where((k) => k.toString().startsWith('${colmeiaId}_')).length;
}
