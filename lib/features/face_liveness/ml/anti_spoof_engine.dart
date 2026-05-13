import 'dart:math';

import 'package:flutter/foundation.dart';

class AntiSpoofEngine {
  final List<double> _motionHistory = <double>[];

  void init() {
    debugPrint('🛡️ AntiSpoofEngine: Using heuristic anti-spoof mode');
  }

  double score({
    required double yaw,
    required double smileProb,
    required double eyeProbDelta,
    required double faceMotion,
  }) {
    final motionSignal = min(1.0, faceMotion * 25);
    _motionHistory.add(motionSignal);
    if (_motionHistory.length > 20) {
      _motionHistory.removeAt(0);
    }

    final avgMotion = _motionHistory.isEmpty
        ? 0.0
        : _motionHistory.reduce((a, b) => a + b) / _motionHistory.length;

    // Heuristic anti-spoof scoring
    final yawSignal = (yaw.abs() / 20).clamp(0.0, 1.0);
    final eyeSignal = eyeProbDelta.clamp(0.0, 1.0);
    final smileSignal = smileProb.clamp(0.0, 1.0);

    return (0.45 * avgMotion +
            0.3 * yawSignal +
            0.15 * eyeSignal +
            0.1 * smileSignal)
        .clamp(0.0, 1.0);
  }

  void dispose() {
    _motionHistory.clear();
  }
}
