import 'package:equatable/equatable.dart';

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
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

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

class AttendanceSubmitRequest extends Equatable {
  const AttendanceSubmitRequest({
    required this.qrPayload,
    required this.latitude,
    required this.longitude,
    required this.biometricNonce,
    required this.type,
  });

  final String qrPayload;
  final double latitude;
  final double longitude;
  final String biometricNonce;
  /// `checkin` ou `checkout`
  final String type;

  Map<String, dynamic> toJson() => {
        'qr_payload': qrPayload,
        'latitude': latitude,
        'longitude': longitude,
        'biometric_nonce': biometricNonce,
        'type': type,
      };

  @override
  List<Object?> get props =>
      [qrPayload, latitude, longitude, biometricNonce, type];
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
      recordedAt: DateTime.tryParse(
            json['recorded_at']?.toString() ??
                json['recordedAt']?.toString() ??
                '',
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
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      syncStatus: json['sync_status']?.toString() ?? 'pending',
    );
  }

  @override
  List<Object?> get props => [id, encryptedPayload, createdAt, syncStatus];
}
