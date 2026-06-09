import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../models/alerta.dart';
import '../models/colmeia.dart';
import '../services/api_service.dart';

final colmeiaRepositoryProvider = Provider<ColmeiaRepository>((ref) {
  return ColmeiaRepository(ref.read(apiServiceProvider));
});

final colmeiasProvider = FutureProvider.autoDispose<List<Colmeia>>((ref) {
  return ref.read(colmeiaRepositoryProvider).getColmeias();
});

final alertasProvider = FutureProvider.autoDispose<List<Alerta>>((ref) {
  return ref.read(colmeiaRepositoryProvider).getAlertas();
});

class ColmeiaRepository {
  final ApiService _api;
  ColmeiaRepository(this._api);

  Future<List<Colmeia>> getColmeias() async {
    final res = await _api.dio.get(ApiConstants.colmeias);
    return (res.data as List)
        .map((j) => Colmeia.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Colmeia> createColmeia({
    required String nome,
    String? localizacao,
    String? macAddress,
  }) async {
    final res = await _api.dio.post(ApiConstants.colmeias, data: {
      'nome':        nome,
      'localizacao': localizacao,
      'mac_address': macAddress,
    });
    return Colmeia.fromJson(res.data['colmeia'] as Map<String, dynamic>);
  }

  Future<void> deleteColmeia(int id) =>
      _api.dio.delete(ApiConstants.deleteColmeia(id));

  Future<Colmeia> updateModo(int id, String modo) async {
    await _api.dio.put(ApiConstants.colmeiaModo(id), data: {'modo': modo});
    final colmeias = await getColmeias();
    return colmeias.firstWhere((c) => c.id == id);
  }

  Future<List<Alerta>> getAlertas() async {
    final res = await _api.dio.get(ApiConstants.alertas);
    return (res.data as List)
        .map((j) => Alerta.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAlertaAsRead(int id) =>
      _api.dio.patch(ApiConstants.alertaLido(id));
}
