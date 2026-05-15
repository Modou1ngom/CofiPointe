/// Chemins relatifs à [EnvConfig.apiBaseUrl], en pratique le préfixe Laravel
/// `.../api/mobile` (voir `routes/api.php`, groupe `prefix('mobile')`).
///
/// Récap des routes protégées (sauf login / verify-otp) : en-tête
/// `Authorization: Bearer {token}` + middleware `auth:sanctum`, `api.active`.
///
/// | Méthode | Chemin | Contrôleur |
/// | POST | /login | MobileAuthController@login |
/// | POST | /verify-otp | MobileAuthController@verifyOtp |
/// | POST | /logout | MobileAuthController@logout |
/// | POST | /register-device | MobileAuthController@registerDevice (204) |
/// | POST | /attendance/checkin | MobileAttendanceController@checkin |
/// | POST | /attendance/checkout | MobileAttendanceController@checkout |
/// | GET | /attendance/history | MobileAttendanceController@history |
/// | GET | /profile | MobileProfileController@show |
/// | GET | /notifications | MobileNotificationController@index |
/// | GET | /pointage/sites | PointageMobileController@sites |
/// | POST | /pointage | PointageMobileController@store |
/// | GET | /pointage/today | PointageMobileController@today |
abstract final class ApiEndpoints {
  static const login = '/login';
  static const verifyOtp = '/verify-otp';
  static const logout = '/logout';
  static const registerDevice = '/register-device';

  static const checkIn = '/attendance/checkin';
  static const checkOut = '/attendance/checkout';
  static const attendanceHistory = '/attendance/history';

  static const profile = '/profile';
  static const notifications = '/notifications';

  /// Flux pointage « classique » (code_public + sens), distinct du flux QR biométrique.
  static const pointageSites = '/pointage/sites';
  static const pointage = '/pointage';
  static const pointageToday = '/pointage/today';
}
