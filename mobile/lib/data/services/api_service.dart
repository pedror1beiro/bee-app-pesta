import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import 'storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.read(storageServiceProvider));
});

class ApiService {
  late final Dio dio;
  final StorageService _storage;

  ApiService(this._storage) {
    dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(_AuthInterceptor(dio, _storage));
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final StorageService _storage;
  bool _refreshing = false;

  _AuthInterceptor(this._dio, this._storage);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (!options.path.contains('/auth/')) {
      final token = await _storage.getAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthFailure = err.response?.statusCode == 401 ||
        err.response?.statusCode == 403;
    final isRefreshPath = err.requestOptions.path.contains('/auth/refresh');

    if (isAuthFailure && !isRefreshPath && !_refreshing) {
      _refreshing = true;
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null) throw Exception('no refresh token');

        final raw = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
        final res = await raw.post(ApiConstants.refresh,
            data: {'refreshToken': refreshToken});

        final newToken = res.data['accessToken'] as String;
        await _storage.saveAccessToken(newToken);
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';

        final retry = await _dio.fetch(err.requestOptions);
        _refreshing = false;
        return handler.resolve(retry);
      } catch (_) {
        _refreshing = false;
        await _storage.clearAll();
      }
    }
    handler.next(err);
  }
}
