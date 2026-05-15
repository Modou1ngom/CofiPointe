import '../datasources/auth_remote_datasource.dart';
import '../models/auth_api_models.dart';

class AuthRepository {
  AuthRepository(this._remote);

  final AuthRemoteDataSource _remote;

  Future<LoginResponse> login(LoginRequest request) => _remote.login(request);

  Future<VerifyOtpResponse> verifyOtp(VerifyOtpRequest request) =>
      _remote.verifyOtp(request);

  Future<void> registerDevice(RegisterDeviceRequest request) =>
      _remote.registerDevice(request);

  Future<void> logout() => _remote.logout();
}
