import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../models/leitura.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

final leituraRepositoryProvider = Provider<LeituraRepository>((ref) {
  return LeituraRepository(
    ref.read(apiServiceProvider),
    ref.read(storageServiceProvider),
  );
});

final leiturasProvider =
    FutureProvider.autoDispose.family<List<Leitura>, int>((ref, colmeiaId) {
  return ref.read(leituraRepositoryProvider).getLeituras(colmeiaId);
});

class LeituraRepository {
  final ApiService _api;
  final StorageService _storage;

  LeituraRepository(this._api, this._storage);

  Future<List<Leitura>> getLeituras(int colmeiaId) async {
    final res = await _api.dio.get(ApiConstants.dados(colmeiaId));
    return (res.data as List)
        .map((j) => Leitura.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Sends BLE-collected readings to the cloud. Called after a BLE sync session.
  Future<int> syncPending(int colmeiaId) async {
    final pending = _storage.getPendingLeituras(colmeiaId);
    if (pending.isEmpty) return 0;

    await _api.dio.post(
      ApiConstants.colmeiaLeituras(colmeiaId),
      data: {'leituras': pending.map((l) => l.toApiJson()).toList()},
    );

    for (final l in pending) {
      await _storage.removePendingLeitura(l.colmeiaId, l.timestamp);
    }
    return pending.length;
  }

  int pendingCount(int colmeiaId) => _storage.pendingCount(colmeiaId);
}
