import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../models/utilizador.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiServiceProvider), ref.read(storageServiceProvider));
});

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<Utilizador?>>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(storageServiceProvider),
  );
});

// ─── Repository ────────────────────────────────────────────────────────────

class AuthRepository {
  final ApiService _api;
  final StorageService _storage;

  AuthRepository(this._api, this._storage);

  Future<Utilizador> login(String email, String password) async {
    final res = await _api.dio.post(ApiConstants.login,
        data: {'email': email, 'password': password});
    final user = Utilizador.fromJson(res.data['utilizador'] as Map<String, dynamic>);
    await _storage.saveSession(
      accessToken:  res.data['accessToken']  as String,
      refreshToken: res.data['refreshToken'] as String,
      utilizador:   user,
    );
    return user;
  }

  Future<void> register(String nome, String email, String password) async {
    await _api.dio.post(ApiConstants.registar,
        data: {'nome': nome, 'email': email, 'password': password});
  }

  Future<void> logout() async {
    try {
      final rt = await _storage.getRefreshToken();
      if (rt != null) {
        await _api.dio.post(ApiConstants.logout, data: {'refreshToken': rt});
      }
    } finally {
      await _storage.clearAll();
    }
  }
}

// ─── Notifier ──────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AsyncValue<Utilizador?>> {
  final AuthRepository _repo;
  final StorageService _storage;

  AuthNotifier(this._repo, this._storage) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final user = await _storage.getUser();
      state = AsyncValue.data(user);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.login(email, password);
      state = AsyncValue.data(user);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      rethrow;
    }
  }

  Future<void> register(String nome, String email, String password) =>
      _repo.register(nome, email, password);

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncValue.data(null);
  }
}
