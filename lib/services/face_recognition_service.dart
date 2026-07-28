import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/errors/failures.dart';
import 'secure_storage_service.dart';

/// Reconnaissance faciale **custom** (hors Face ID / local_auth) :
/// détection ML Kit + empreinte de landmarks normalisés stockée localement.
class FaceRecognitionService {
  FaceRecognitionService(this._storage);

  final SecureStorageService _storage;

  static const matchThreshold = 0.88;
  static const _landmarkTypes = <FaceLandmarkType>[
    FaceLandmarkType.leftEye,
    FaceLandmarkType.rightEye,
    FaceLandmarkType.noseBase,
    FaceLandmarkType.leftMouth,
    FaceLandmarkType.rightMouth,
    FaceLandmarkType.bottomMouth,
    FaceLandmarkType.leftCheek,
    FaceLandmarkType.rightCheek,
    FaceLandmarkType.leftEar,
    FaceLandmarkType.rightEar,
  ];

  FaceDetector? _detector;

  FaceDetector get _faceDetector {
    return _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: false,
        enableClassification: false,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.18,
      ),
    );
  }

  Future<bool> hasEnrolledFace() async {
    final v = await _storage.readFaceTemplate();
    return v != null && v.trim().isNotEmpty;
  }

  Future<void> clearEnrollment() => _storage.writeFaceTemplate(null);

  /// Analyse une photo (chemin fichier) et renvoie l’empreinte faciale.
  Future<List<double>> extractEmbeddingFromFile(String imagePath) async {
    if (kIsWeb) {
      throw const BiometricFailure(
        'La reconnaissance faciale custom n’est pas disponible sur le web.',
      );
    }

    final input = InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector.processImage(input);
    if (faces.isEmpty) {
      throw const BiometricFailure(
        'Aucun visage détecté. Centrez votre visage et réessayez.',
      );
    }
    if (faces.length > 1) {
      throw const BiometricFailure(
        'Plusieurs visages détectés. Restez seul devant la caméra.',
      );
    }

    final face = faces.first;
    _assertFaceQuality(face);
    return embeddingFromFace(face);
  }

  void _assertFaceQuality(Face face) {
    final yaw = (face.headEulerAngleY ?? 0).abs();
    final pitch = (face.headEulerAngleX ?? 0).abs();
    if (yaw > 28 || pitch > 28) {
      throw const BiometricFailure(
        'Visage trop incliné. Regardez droit vers la caméra.',
      );
    }
    final box = face.boundingBox;
    if (box.width < 80 || box.height < 80) {
      throw const BiometricFailure(
        'Approchez-vous : le visage est trop petit dans le cadre.',
      );
    }
  }

  List<double> embeddingFromFace(Face face) {
    final box = face.boundingBox;
    final w = box.width == 0 ? 1.0 : box.width;
    final h = box.height == 0 ? 1.0 : box.height;
    final out = <double>[];

    for (final type in _landmarkTypes) {
      final pos = face.landmarks[type]?.position;
      if (pos == null) {
        out.addAll(const [0.0, 0.0]);
      } else {
        out.add((pos.x - box.left) / w);
        out.add((pos.y - box.top) / h);
      }
    }

    out.add((face.headEulerAngleY ?? 0) / 90.0);
    out.add((face.headEulerAngleZ ?? 0) / 90.0);
    out.add((face.headEulerAngleX ?? 0) / 90.0);
    return out;
  }

  Future<void> enrollFromFile(String imagePath) async {
    final embedding = await extractEmbeddingFromFile(imagePath);
    await _storage.writeFaceTemplate(jsonEncode(embedding));
  }

  /// Compare la photo courante au modèle enrôlé.
  /// Retourne un nonce à envoyer au serveur si OK.
  Future<String> verifyFromFile(String imagePath) async {
    final raw = await _storage.readFaceTemplate();
    if (raw == null || raw.trim().isEmpty) {
      throw const BiometricFailure(
        'Aucun visage enrôlé. Réactivez la reconnaissance faciale.',
      );
    }

    late final List<double> enrolled;
    try {
      enrolled = (jsonDecode(raw) as List)
          .map((e) => (e as num).toDouble())
          .toList();
    } catch (_) {
      throw const BiometricFailure(
        'Modèle facial corrompu. Réenrôlez votre visage.',
      );
    }

    final probe = await extractEmbeddingFromFile(imagePath);
    final score = cosineSimilarity(enrolled, probe);
    if (score < matchThreshold) {
      throw BiometricFailure(
        'Visage non reconnu (score ${(score * 100).toStringAsFixed(0)} %). Réessayez.',
      );
    }

    final digest = base64Url.encode(utf8.encode(jsonEncode(probe)))
        .replaceAll('=', '');
    return 'face_custom:$digest:${DateTime.now().millisecondsSinceEpoch}';
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    if (n == 0) return 0;
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}
