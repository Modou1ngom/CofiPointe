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
  });

  final String qrPayload;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
        'qr_payload': qrPayload,
        'latitude': latitude,
        'longitude': longitude,
      };

  @override
  List<Object?> get props => [qrPayload, latitude, longitude];
}

class AttendanceScanResponse extends Equatable {
  const AttendanceScanResponse({
    required this.valid,
    this.message,
    this.officeZone,
  });

  final bool valid;
  final String? message;
  final OfficeZone? officeZone;

  factory AttendanceScanResponse.fromJson(Map<String, dynamic> json) {
    final zoneRaw = json['office_zone'] ?? json['officeZone'];
    return AttendanceScanResponse(
      valid: json['valid'] == true,
      message: json['message']?.toString(),
      officeZone: zoneRaw is Map
          ? OfficeZone.fromJson(Map<String, dynamic>.from(zoneRaw))
          : null,
    );
  }

  @override
  List<Object?> get props => [valid, message, officeZone];
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
  });

  final String qrPayload;
  final double latitude;
  final double longitude;
  final String biometricNonce;
  /// `checkin` ou `checkout`
  final String type;
  final String? deviceId;
  final String? serialNumber;

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
      ];
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
    return AttendanceSubmitResponse(
      id: json['id']?.toString() ?? '',
      recordedAt: AppDateFormat.parseApi(
            json['recorded_at'] ?? json['recordedAt'],
          ) ??
          DateTime.now(),
      type: json['type']?.toString() ?? 'checkin',
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
