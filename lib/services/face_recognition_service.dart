import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../core/errors/failures.dart';
import 'secure_storage_service.dart';

/// Reconnaissance faciale custom (Android natif).
///
/// Ancien matching landmarks = trop similaire entre personnes (faux positifs).
/// Ici : crop du visage → patch 64×64 gris → similarité cosinus + L2 strictes.
class FaceRecognitionService {
  FaceRecognitionService(this._storage);

  final SecureStorageService _storage;

  /// Seuil cosinus (vecteurs normalisés). Plus haut = moins de faux positifs.
  static const matchThreshold = 0.90;

  /// Distance L2 max complémentaire (même espace normalisé).
  static const maxL2Distance = 0.48;

  static const enrollSampleCount = 3;
  static const _patchSize = 64;
  static const _pixelCount = _patchSize * _patchSize;
  static const _templateVersion = 3;

  FaceDetector? _detector;

  FaceDetector get _faceDetector {
    return _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: false,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.2,
      ),
    );
  }

  Future<bool> hasEnrolledFace() async {
    final samples = await _readSamples();
    return samples.isNotEmpty;
  }

  Future<void> clearEnrollment() => _storage.writeFaceTemplate(null);

  /// Empreinte normalisée (pour matching).
  Future<List<double>> extractEmbeddingFromFile(String imagePath) async {
    final patch = await _extractPatchBytes(imagePath);
    return _normalizePatch(patch);
  }

  Future<Uint8List> _extractPatchBytes(String imagePath) async {
    if (kIsWeb) {
      throw const BiometricFailure(
        'La reconnaissance faciale photo n’est pas disponible sur iPhone/web. '
        'Utilisez l’APK Android, ou choisissez Empreinte / matricule.',
      );
    }

    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const BiometricFailure('Image illisible. Reprenez la photo.');
    }

    final input = InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector.processImage(input);
    if (faces.isEmpty) {
      throw const BiometricFailure(
        'Aucun visage détecté. Centrez votre visage, bonne lumière, réessayez.',
      );
    }
    if (faces.length > 1) {
      throw const BiometricFailure(
        'Plusieurs visages détectés. Restez seul devant la caméra.',
      );
    }

    final face = faces.first;
    _assertFaceQuality(face);
    return _facePatchBytes(decoded, face);
  }

  void _assertFaceQuality(Face face) {
    final yaw = (face.headEulerAngleY ?? 0).abs();
    final pitch = (face.headEulerAngleX ?? 0).abs();
    if (yaw > 25 || pitch > 25) {
      throw const BiometricFailure(
        'Visage trop incliné. Regardez droit vers la caméra.',
      );
    }
    final box = face.boundingBox;
    if (box.width < 120 || box.height < 120) {
      throw const BiometricFailure(
        'Approchez-vous : le visage est trop petit dans le cadre.',
      );
    }
    final leftOpen = face.leftEyeOpenProbability;
    final rightOpen = face.rightEyeOpenProbability;
    if (leftOpen != null &&
        rightOpen != null &&
        leftOpen < 0.25 &&
        rightOpen < 0.25) {
      throw const BiometricFailure(
        'Ouvrez les yeux et regardez la caméra.',
      );
    }
    if (face.landmarks[FaceLandmarkType.leftEye]?.position == null ||
        face.landmarks[FaceLandmarkType.rightEye]?.position == null ||
        face.landmarks[FaceLandmarkType.noseBase]?.position == null) {
      throw const BiometricFailure(
        'Visage mal détecté. Améliorez l’éclairage et recentrez-vous.',
      );
    }
  }

  Uint8List _facePatchBytes(img.Image source, Face face) {
    final box = face.boundingBox;
    final padX = box.width * 0.18;
    final padY = box.height * 0.22;
    final x0 = (box.left - padX).round().clamp(0, source.width - 1);
    final y0 = (box.top - padY).round().clamp(0, source.height - 1);
    final x1 = (box.right + padX).round().clamp(x0 + 1, source.width);
    final y1 = (box.bottom + padY).round().clamp(y0 + 1, source.height);

    var crop = img.copyCrop(
      source,
      x: x0,
      y: y0,
      width: x1 - x0,
      height: y1 - y0,
    );
    crop = img.copyResize(
      crop,
      width: _patchSize,
      height: _patchSize,
      interpolation: img.Interpolation.average,
    );
    crop = img.grayscale(crop);
    crop = img.adjustColor(crop, contrast: 1.15);

    final out = Uint8List(_pixelCount);
    var i = 0;
    for (var y = 0; y < _patchSize; y++) {
      for (var x = 0; x < _patchSize; x++) {
        out[i++] = crop.getPixel(x, y).luminance.toInt().clamp(0, 255);
      }
    }
    return out;
  }

  List<double> _normalizePatch(Uint8List patch) {
    if (patch.length != _pixelCount) {
      throw const BiometricFailure('Empreinte faciale invalide.');
    }
    final values = Float64List(_pixelCount);
    var sum = 0.0;
    for (var i = 0; i < _pixelCount; i++) {
      values[i] = patch[i].toDouble();
      sum += values[i];
    }
    final mean = sum / _pixelCount;
    var normSq = 0.0;
    for (var i = 0; i < _pixelCount; i++) {
      values[i] = values[i] - mean;
      normSq += values[i] * values[i];
    }
    final norm = math.sqrt(normSq);
    if (norm < 1e-6) {
      throw const BiometricFailure(
        'Photo trop uniforme (mauvaise lumière). Réessayez.',
      );
    }
    for (var i = 0; i < _pixelCount; i++) {
      values[i] /= norm;
    }
    return List<double>.unmodifiable(values);
  }

  Future<void> enrollFromFile(String imagePath) async {
    final embedding = await extractEmbeddingFromFile(imagePath);
    await enrollEmbeddings([embedding]);
  }

  Future<void> enrollEmbeddings(List<List<double>> embeddings) async {
    if (embeddings.isEmpty) {
      throw const BiometricFailure('Aucune empreinte faciale à enregistrer.');
    }
    if (embeddings.any((e) => e.length != _pixelCount)) {
      throw const BiometricFailure('Empreinte faciale invalide.');
    }
    if (embeddings.length >= 2) {
      for (var i = 1; i < embeddings.length; i++) {
        final sim = cosineSimilarity(embeddings[0], embeddings[i]);
        if (sim < 0.82) {
          throw const BiometricFailure(
            'Les photos ne correspondent pas assez. '
            'Reprenez les 3 captures avec le même visage, bonne lumière.',
          );
        }
      }
    }
    final packed = embeddings.map(_packNormalized).toList();
    final payload = {
      'v': _templateVersion,
      'encoding': 'f32',
      'samples': packed,
    };
    await _storage.writeFaceTemplate(jsonEncode(payload));
    await _storage.writeBiometricMode('face_custom');
  }

  String _packNormalized(List<double> embedding) {
    final bd = ByteData(_pixelCount * 4);
    for (var i = 0; i < _pixelCount; i++) {
      bd.setFloat32(i * 4, embedding[i], Endian.little);
    }
    return base64Encode(bd.buffer.asUint8List());
  }

  List<double>? _unpackSample(String b64, {required String encoding}) {
    try {
      final raw = base64Decode(b64);
      if (encoding == 'u8') {
        if (raw.length != _pixelCount) return null;
        return _normalizePatch(Uint8List.fromList(raw));
      }
      // float32
      if (raw.length != _pixelCount * 4) return null;
      final bd = ByteData.sublistView(raw);
      final out = Float64List(_pixelCount);
      for (var i = 0; i < _pixelCount; i++) {
        out[i] = bd.getFloat32(i * 4, Endian.little);
      }
      return List<double>.unmodifiable(out);
    } catch (_) {
      return null;
    }
  }

  Future<String> verifyFromFile(String imagePath) async {
    final samples = await _readSamples();
    if (samples.isEmpty) {
      throw const BiometricFailure(
        'Aucun visage enrôlé (ou ancien modèle obsolète). '
        'Réactivez la reconnaissance faciale dans Profil (3 photos).',
      );
    }

    final probe = await extractEmbeddingFromFile(imagePath);
    var best = -1.0;
    var bestL2 = double.infinity;
    for (final enrolled in samples) {
      if (enrolled.length != probe.length) continue;
      final sim = cosineSimilarity(enrolled, probe);
      final l2 = l2Distance(enrolled, probe);
      if (sim > best) {
        best = sim;
        bestL2 = l2;
      }
    }

    if (best < matchThreshold || bestL2 > maxL2Distance) {
      throw BiometricFailure(
        'Visage non reconnu (score ${(best * 100).clamp(0, 100).toStringAsFixed(0)} %). '
        'Bonne lumière, visage de face. Sinon réenrôlez dans Profil.',
      );
    }

    final digest =
        sha256.convert(utf8.encode(probe.take(64).join(','))).toString();
    return 'face_custom:$digest:${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<List<List<double>>> _readSamples() async {
    final raw = await _storage.readFaceTemplate();
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return const [];
      if (decoded is Map) {
        final v = decoded['v'];
        if (v is! num || v.toInt() < _templateVersion) {
          return const [];
        }
        final encoding = (decoded['encoding'] as String?) ?? 'f32';
        final samples = decoded['samples'];
        if (samples is! List) return const [];
        final out = <List<double>>[];
        for (final s in samples) {
          if (s is! String) continue;
          final emb = _unpackSample(s, encoding: encoding);
          if (emb != null && emb.length == _pixelCount) out.add(emb);
        }
        return out;
      }
    } catch (_) {}
    return const [];
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

  static double l2Distance(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return math.sqrt(sum);
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}
