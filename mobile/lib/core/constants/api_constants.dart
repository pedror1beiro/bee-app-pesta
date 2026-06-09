class ApiConstants {
  static const baseUrl = 'https://bee-app-pesta.up.railway.app';

  static const login        = '/api/auth/login';
  static const registar     = '/api/auth/registar';
  static const refresh      = '/api/auth/refresh';
  static const logout       = '/api/auth/logout';
  static const colmeias     = '/api/colmeias';
  static const alertas      = '/api/alertas';

  static String dados(int colmeiaId)       => '/api/dados/$colmeiaId';
  static String alertaLido(int id)         => '/api/alertas/$id/lido';
  static String colmeiaLeituras(int id)    => '/api/colmeias/$id/leituras';
  static String deleteColmeia(int id)      => '/api/colmeias/$id';
  static String colmeiaModo(int id)        => '/api/colmeias/$id/modo';
}
