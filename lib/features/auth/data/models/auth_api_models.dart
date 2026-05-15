import 'package:equatable/equatable.dart';

import 'user_model.dart';

class LoginRequest extends Equatable {
  const LoginRequest({
    required this.identifier,
    required this.password,
  });

  final String identifier;
  final String password;

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'password': password,
      };

  @override
  List<Object?> get props => [identifier, password];
}

class LoginResponse extends Equatable {
  const LoginResponse({
    this.accessToken,
    this.refreshToken,
    this.requiresOtp = false,
    this.message,
    this.user,
  });

  final String? accessToken;
  final String? refreshToken;
  final bool requiresOtp;
  final String? message;
  final UserModel? user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    return LoginResponse(
      accessToken: json['access_token']?.toString() ??
          json['accessToken']?.toString() ??
          json['token']?.toString(),
      refreshToken: json['refresh_token']?.toString() ?? json['refreshToken']?.toString(),
      requiresOtp: json['requires_otp'] == true || json['requiresOtp'] == true,
      message: json['message']?.toString(),
      user: userRaw is Map<String, dynamic>
          ? UserModel.fromJson(userRaw)
          : null,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, requiresOtp, message, user];
}

class VerifyOtpRequest extends Equatable {
  const VerifyOtpRequest({
    required this.identifier,
    required this.code,
  });

  final String identifier;
  final String code;

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'code': code,
      };

  @override
  List<Object?> get props => [identifier, code];
}

class VerifyOtpResponse extends Equatable {
  const VerifyOtpResponse({
    required this.accessToken,
    this.refreshToken,
    required this.user,
    this.requiresDeviceRegistration = false,
  });

  final String accessToken;
  final String? refreshToken;
  final UserModel user;
  final bool requiresDeviceRegistration;

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    return VerifyOtpResponse(
      accessToken: json['access_token']?.toString() ??
          json['accessToken']?.toString() ??
          '',
      refreshToken: json['refresh_token']?.toString() ?? json['refreshToken']?.toString(),
      user: userRaw is Map<String, dynamic>
          ? UserModel.fromJson(userRaw)
          : UserModel(id: '', fullName: ''),
      requiresDeviceRegistration: json['requires_device_registration'] == true ||
          json['requiresDeviceRegistration'] == true,
    );
  }

  @override
  List<Object?> get props =>
      [accessToken, refreshToken, user, requiresDeviceRegistration];
}

class RegisterDeviceRequest extends Equatable {
  const RegisterDeviceRequest({
    required this.deviceId,
    required this.model,
    required this.osVersion,
    required this.appVersion,
  });

  final String deviceId;
  final String model;
  final String osVersion;
  final String appVersion;

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'model': model,
        'os_version': osVersion,
        'app_version': appVersion,
      };

  @override
  List<Object?> get props => [deviceId, model, osVersion, appVersion];
}
