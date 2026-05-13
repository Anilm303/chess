import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Size;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../data/repositories/face_liveness_repository_impl.dart';
import '../../domain/entities/liveness_result.dart';
import '../../domain/entities/liveness_step.dart';
import '../../domain/repositories/face_liveness_repository.dart';

class FaceLivenessController extends ChangeNotifier {
  final FaceLivenessRepository _repository;

  FaceLivenessController({FaceLivenessRepository? repository})
    : _repository = repository ?? FaceLivenessRepositoryImpl();

  LivenessStep _step = LivenessStep.alignFace;
  String _hint = 'Align your face inside the scanner';
  bool _isBusy = false;
  bool _blinkDetected = false;
  bool _turnDetected = false;
  bool _smileDetected = false;
  bool _singleFace = true;
  double _spoofScore = 0;
  LivenessResult? _result;

  bool _eyesWereOpen = false;
  bool _finalized = false;

  LivenessStep get step => _step;
  String get hint => _hint;
  bool get isBusy => _isBusy;
  bool get blinkDetected => _blinkDetected;
  bool get turnDetected => _turnDetected;
  bool get smileDetected => _smileDetected;
  bool get singleFace => _singleFace;
  double get spoofScore => _spoofScore;
  LivenessResult? get result => _result;
  bool get isDone =>
      _step == LivenessStep.success || _step == LivenessStep.failed;

  Future<void> processImage(
    InputImage image, {
    required Size previewSize,
  }) async {
    if (_isBusy || _finalized) return;
    _isBusy = true;

    try {
      final metrics = await _repository.analyzeImage(
        image,
        previewSize: previewSize,
      );
      if (metrics == null) return;

      _singleFace = metrics.faceCount == 1;
      _spoofScore = metrics.spoofScore;

      if (metrics.faceCount == 0) {
        _step = LivenessStep.alignFace;
        _hint = 'No face found. Keep face in frame.';
        return;
      }

      if (metrics.faceCount > 1) {
        _step = LivenessStep.failed;
        _hint = 'Multiple faces detected. Only one person allowed.';
        _finalize();
        return;
      }

      if (!metrics.isInsideGuide) {
        _step = LivenessStep.alignFace;
        _hint = 'Center your face in the circle';
        return;
      }

      final avgEyeOpen =
          (metrics.leftEyeOpenProbability + metrics.rightEyeOpenProbability) /
          2;
      if (!_blinkDetected) {
        _step = LivenessStep.blink;
        _hint = LivenessStep.blink.instruction;
        if (avgEyeOpen > 0.70) {
          _eyesWereOpen = true;
        }
        if (_eyesWereOpen && avgEyeOpen < 0.35) {
          _blinkDetected = true;
          _step = LivenessStep.turnHead;
          _hint = LivenessStep.turnHead.instruction;
        }
        return;
      }

      if (!_turnDetected) {
        _step = LivenessStep.turnHead;
        _hint = LivenessStep.turnHead.instruction;
        if (metrics.headYaw.abs() > 15) {
          _turnDetected = true;
          _step = LivenessStep.smile;
          _hint = LivenessStep.smile.instruction;
        }
        return;
      }

      if (!_smileDetected) {
        _step = LivenessStep.smile;
        _hint = LivenessStep.smile.instruction;
        if (metrics.smileProbability > 0.60) {
          _smileDetected = true;
          _step = LivenessStep.verifying;
          _hint = LivenessStep.verifying.instruction;
        }
        return;
      }

      if (_step == LivenessStep.verifying) {
        _result = _repository.buildResult(
          blinkDetected: _blinkDetected,
          turnDetected: _turnDetected,
          smileDetected: _smileDetected,
          spoofScore: _spoofScore,
          singleFace: _singleFace,
        );

        if (_result!.isLive) {
          _step = LivenessStep.success;
          _hint = _result!.message;
        } else {
          _step = LivenessStep.failed;
          _hint = _result!.message;
        }
        _finalize();
      }
    } catch (e) {
      _step = LivenessStep.failed;
      _hint = 'Processing error: $e';
      _finalize();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _finalize() {
    _finalized = true;
  }

  void retry() {
    _step = LivenessStep.alignFace;
    _hint = LivenessStep.alignFace.instruction;
    _isBusy = false;
    _blinkDetected = false;
    _turnDetected = false;
    _smileDetected = false;
    _singleFace = true;
    _spoofScore = 0;
    _result = null;
    _eyesWereOpen = false;
    _finalized = false;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _repository.dispose();
    super.dispose();
  }
}
