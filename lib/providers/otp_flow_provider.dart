import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifiant en cours pour l’écran OTP (email ou matricule).
final otpIdentifierProvider = StateProvider<String?>((ref) => null);
