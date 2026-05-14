import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../domain/entities/frame_metrics.dart';
import '../../domain/entities/liveness_result.dart';
import '../../domain/repositories/face_liveness_repository.dart';
import '../../ml/anti_spoof_engine.dart';

class FaceLivenessRepositoryImpl implements FaceLivenessRepository {
  final FaceDetector _faceDetector;
  final AntiSpoofEngine _antiSpoofEngine;

  Offset? _lastFaceCenter;
  late Size _cachedPreviewSize;
  late double _cachedGuideRadius;
  bool _guideRadiusCached = false;

  FaceLivenessRepositoryImpl()
    : _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableLandmarks: false,
          enableClassification: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      ),
      _antiSpoofEngine = AntiSpoofEngine() {
    _antiSpoofEngine.init();
  }

  @override
  Future<FrameMetrics?> analyzeImage(
    InputImage image, {
    required Size previewSize,
  }) async {
    // 🔥 Optimization: Cache guide radius to avoid recalculation every frame
    if (!_guideRadiusCached || _cachedPreviewSize != previewSize) {
      _cachedPreviewSize = previewSize;
      _cachedGuideRadius = previewSize.shortestSide * 0.30;
      _guideRadiusCached = true;
    }

    final faces = await _faceDetector.processImage(image);

    if (faces.isEmpty) {
      _lastFaceCenter = null;
      return const FrameMetrics(
        faceCount: 0,
        leftEyeOpenProbability: 0,
        rightEyeOpenProbability: 0,
        smileProbability: 0,
        headYaw: 0,
        spoofScore: 0,
        isInsideGuide: false,
        hasEnoughMotion: false,
      );
    }

    final face = faces.first;
    final rect = face.boundingBox;
    final center = rect.center;

    // 🔥 Optimization: Calculate motion only once
    final motion = _lastFaceCenter == null
        ? 0.0
        : (center - _lastFaceCenter!).distance;
    _lastFaceCenter = center;

    // 🔥 Optimization: Null-coalescing with caching
    final leftEye = face.leftEyeOpenProbability ?? 0.0;
    final rightEye = face.rightEyeOpenProbability ?? 0.0;
    final smile = face.smilingProbability ?? 0.0;
    final yaw = face.headEulerAngleY ?? 0.0;

    final isInsideGuide = _isFaceInsideGuide(center, previewSize);

    final spoofScore = _antiSpoofEngine.score(
      yaw: yaw,
      smileProb: smile,
      eyeProbDelta: (leftEye - rightEye).abs(),
      faceMotion: motion,
    );

    return FrameMetrics(
      faceCount: faces.length,
      leftEyeOpenProbability: leftEye,
      rightEyeOpenProbability: rightEye,
      smileProbability: smile,
      headYaw: yaw,
      spoofScore: spoofScore,
      isInsideGuide: isInsideGuide,
      hasEnoughMotion: motion > 1.6,
    );
  }

  // 🔥 Optimization: Use Offset directly instead of converting Rect
  bool _isFaceInsideGuide(Offset faceCenter, Size previewSize) {
    final center = Offset(previewSize.width / 2, previewSize.height / 2);
    return (faceCenter - center).distance <= _cachedGuideRadius * 0.65;
  }

  @override
  LivenessResult buildResult({
    required bool blinkDetected,
    required bool turnDetected,
    required bool smileDetected,
    required double spoofScore,
    required bool singleFace,
  }) {
    final isLive =
        blinkDetected &&
        turnDetected &&
        smileDetected &&
        singleFace &&
        spoofScore >= 0.45;

    return LivenessResult(
      isLive: isLive,
      message: isLive
          ? 'Liveness verification successful.'
          : 'Could not verify a live face. Please retry in better light.',
      score: spoofScore,
      blinkDetected: blinkDetected,
      turnDetected: turnDetected,
      smileDetected: smileDetected,
      singleFace: singleFace,
    );
  }

  @override
  Future<void> dispose() async {
    await _faceDetector.close();
    _antiSpoofEngine.dispose();
  }
}
