import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../entities/frame_metrics.dart';
import '../entities/liveness_result.dart';

abstract class FaceLivenessRepository {
  Future<FrameMetrics?> analyzeImage(
    InputImage image, {
    required Size previewSize,
  });

  LivenessResult buildResult({
    required bool blinkDetected,
    required bool turnDetected,
    required bool smileDetected,
    required double spoofScore,
    required bool singleFace,
  });

  Future<void> dispose();
}
