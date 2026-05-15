import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.fullName,
    this.email,
    this.matricule,
    this.avatarUrl,
    this.jobTitle,
    this.phone,
    this.department,
    this.linkedDevice,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? matricule;
  final String? avatarUrl;
  final String? jobTitle;
  final String? phone;
  final String? department;
  final String? linkedDevice;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ??
          json['fullName']?.toString() ??
          json['name']?.toString() ??
          '',
      email: json['email']?.toString(),
      matricule: json['matricule']?.toString(),
      avatarUrl: json['avatar_url']?.toString() ?? json['avatarUrl']?.toString(),
      jobTitle: json['job_title']?.toString() ?? json['jobTitle']?.toString(),
      phone: json['phone']?.toString() ?? json['phone_number']?.toString(),
      department: json['department']?.toString(),
      linkedDevice:
          json['linked_device']?.toString() ?? json['linkedDevice']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'matricule': matricule,
        'avatar_url': avatarUrl,
        'job_title': jobTitle,
        'phone': phone,
        'department': department,
        'linked_device': linkedDevice,
      };

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        matricule,
        avatarUrl,
        jobTitle,
        phone,
        department,
        linkedDevice,
      ];
}
