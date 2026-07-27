import 'package:equatable/equatable.dart';

import '../../../../core/utils/app_date_format.dart';
import '../../../../models/office_zone.dart';

class AttendanceRecord extends Equatable {
  const AttendanceRecord({
    required this.id,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.status = 'present',
  });

  final String id;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) => AppDateFormat.parseApi(v);

    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      date: parseDt(json['date']) ?? DateTime.now(),
      checkIn: parseDt(json['check_in'] ?? json['checkIn']),
      checkOut: parseDt(json['check_out'] ?? json['checkOut']),
      status: json['status']?.toString() ?? 'present',
    );
  }

  @override
  List<Object?> get props => [id, date, checkIn, checkOut, status];
}

class AttendanceScanRequest extends Equatable {
  const AttendanceScanRequest({
    required this.qrPayload,
    required this.latitude,
    required this.longitude,
    this.deviceId,
    this.serialNumber,
  });

  final String qrPayload;
  final double latitude;
  final double longitude;
  final String? deviceId;
  final String? serialNumber;

  Map<String, dynamic> toJson() => {
        'qr_payload': qrPayload,
        'latitude': latitude,
        'longitude': longitude,
        if (deviceId != null && deviceId!.trim().isNotEmpty)
          'device_id': deviceId!.trim(),
        if (serialNumber != null && serialNumber!.trim().isNotEmpty)
          'serial_number': serialNumber!.trim(),
      };

  @override
  List<Object?> get props =>
      [qrPayload, latitude, longitude, deviceId, serialNumber];
}

class AttendanceScanResponse extends Equatable {
  const AttendanceScanResponse({
    required this.valid,
    this.message,
    this.officeZone,
    this.isVirtual = false,
    this.requiresMatricule = false,
    this.requiresEmail = false,
    this.requiresOtp = false,
    this.authMode,
    this.agenceNom,
  });

  final bool valid;
  final String? message;
  final OfficeZone? officeZone;
  final bool isVirtual;
  final bool requiresMatricule;
  final bool requiresEmail;
  final bool requiresOtp;
  final String? authMode;
  final String? agenceNom;

  factory AttendanceScanResponse.fromJson(Map<String, dynamic> json) {
    final zoneRaw = json['office_zone'] ?? json['officeZone'];
    final agenceRaw = json['agence'];
    final agence = agenceRaw is Map ? Map<String, dynamic>.from(agenceRaw) : null;
    final isVirtual = json['is_virtual'] == true ||
        json['isVirtual'] == true ||
        agence?['is_virtual'] == true;
    final authMode =
        json['auth_mode']?.toString() ?? json['authMode']?.toString();
    final requiresEmail = json['requires_email'] == true ||
        json['requiresEmail'] == true ||
        authMode == 'email_otp' ||
        isVirtual;
    return AttendanceScanResponse(
      valid: json['valid'] == true,
      message: json['message']?.toString(),
      officeZone: zoneRaw is Map
          ? OfficeZone.fromJson(Map<String, dynamic>.from(zoneRaw))
          : null,
      isVirtual: isVirtual,
      requiresMatricule: false,
      requiresEmail: requiresEmail,
      requiresOtp: json['requires_otp'] == true ||
          json['requiresOtp'] == true ||
          requiresEmail,
      authMode: authMode,
      agenceNom: agence?['nom']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        valid,
        message,
        officeZone,
        isVirtual,
        requiresMatricule,
        requiresEmail,
        requiresOtp,
        authMode,
        agenceNom,
      ];
}

class AttendanceSubmitRequest extends Equatable {
  const AttendanceSubmitRequest({
    required this.qrPayload,
    required this.latitude,
    required this.longitude,
    required this.biometricNonce,
    required this.type,
    this.deviceId,
    this.serialNumber,
    this.matricule,
    this.email,
    this.otpCode,
  });

  final String qrPayload;
  final double latitude;
  final double longitude;
  final String biometricNonce;
  /// `checkin` ou `checkout`
  final String type;
  final String? deviceId;
  final String? serialNumber;
  final String? matricule;
  final String? email;
  final String? otpCode;

  Map<String, dynamic> toJson() => {
        'qr_payload': qrPayload,
        'latitude': latitude,
        'longitude': longitude,
        'biometric_nonce': biometricNonce,
        'type': type,
        if (deviceId != null && deviceId!.trim().isNotEmpty)
          'device_id': deviceId!.trim(),
        if (serialNumber != null && serialNumber!.trim().isNotEmpty)
          'serial_number': serialNumber!.trim(),
        if (matricule != null && matricule!.trim().isNotEmpty)
          'matricule': matricule!.trim(),
        if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
        if (otpCode != null && otpCode!.trim().isNotEmpty)
          'otp_code': otpCode!.trim(),
      };

  @override
  List<Object?> get props => [
        qrPayload,
        latitude,
        longitude,
        biometricNonce,
        type,
        deviceId,
        serialNumber,
        matricule,
        email,
        otpCode,
      ];
}

class VirtualOtpRequest extends Equatable {
  const VirtualOtpRequest({
    required this.qrPayload,
    required this.email,
    this.latitude,
    this.longitude,
    this.deviceId,
    this.serialNumber,
  });

  final String qrPayload;
  final String email;
  final double? latitude;
  final double? longitude;
  final String? deviceId;
  final String? serialNumber;

  Map<String, dynamic> toJson() => {
        'qr_payload': qrPayload,
        'email': email.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (deviceId != null && deviceId!.trim().isNotEmpty)
          'device_id': deviceId!.trim(),
        if (serialNumber != null && serialNumber!.trim().isNotEmpty)
          'serial_number': serialNumber!.trim(),
      };

  @override
  List<Object?> get props =>
      [qrPayload, email, latitude, longitude, deviceId, serialNumber];
}

class VirtualOtpResponse extends Equatable {
  const VirtualOtpResponse({
    required this.ok,
    this.message,
    this.email,
  });

  final bool ok;
  final String? message;
  final String? email;

  factory VirtualOtpResponse.fromJson(Map<String, dynamic> json) {
    return VirtualOtpResponse(
      ok: json['ok'] == true,
      message: json['message']?.toString(),
      email: json['email']?.toString(),
    );
  }

  @override
  List<Object?> get props => [ok, message, email];
}

class AttendanceSubmitResponse extends Equatable {
  const AttendanceSubmitResponse({
    required this.id,
    required this.recordedAt,
    required this.type,
    this.message,
  });

  final String id;
  final DateTime recordedAt;
  final String type;
  final String? message;

  factory AttendanceSubmitResponse.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString() ??
        json['pointage_type']?.toString() ??
        'checkin';
    final normalized = rawType.trim().toLowerCase();
    final type = (normalized == 'depart' ||
            normalized == 'sortie' ||
            normalized == 'checkout')
        ? 'checkout'
        : 'checkin';
    return AttendanceSubmitResponse(
      id: json['id']?.toString() ?? '',
      recordedAt: AppDateFormat.parseApi(
            json['recorded_at'] ?? json['recordedAt'],
          ) ??
          DateTime.now(),
      type: type,
      message: json['message']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, recordedAt, type, message];
}

class PendingAttendance extends Equatable {
  const PendingAttendance({
    required this.id,
    required this.encryptedPayload,
    required this.createdAt,
    this.syncStatus = 'pending',
  });

  final String id;
  final String encryptedPayload;
  final DateTime createdAt;
  final String syncStatus;

  Map<String, dynamic> toJson() => {
        'id': id,
        'encrypted_payload': encryptedPayload,
        'created_at': createdAt.toIso8601String(),
        'sync_status': syncStatus,
      };

  factory PendingAttendance.fromJson(Map<String, dynamic> json) {
    return PendingAttendance(
      id: json['id']?.toString() ?? '',
      encryptedPayload: json['encrypted_payload']?.toString() ?? '',
      createdAt:
          AppDateFormat.parseApi(json['created_at']) ?? DateTime.now(),
      syncStatus: json['sync_status']?.toString() ?? 'pending',
    );
  }

  @override
  List<Object?> get props => [id, encryptedPayload, createdAt, syncStatus];
}
