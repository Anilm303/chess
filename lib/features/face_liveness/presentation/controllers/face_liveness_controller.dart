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
  bool _stateChanged = false;
  int _consecutiveFramesWithoutFace = 0;
  static const int _faceDetectionTimeout = 5;

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
    _stateChanged = false;

    try {
      final metrics = await _repository.analyzeImage(
        image,
        previewSize: previewSize,
      );
      if (metrics == null) return;

      // 🔥 Optimization: Only update if state actually changed
      if (metrics.faceCount == 0) {
        _consecutiveFramesWithoutFace++;
        if (_consecutiveFramesWithoutFace > _faceDetectionTimeout) {
          _updateState(
            LivenessStep.alignFace,
            'No face found. Keep face in frame.',
          );
        }
        return;
      }
      _consecutiveFramesWithoutFace = 0;

      if (metrics.faceCount > 1) {
        _updateState(
          LivenessStep.failed,
          'Multiple faces detected. Only one person allowed.',
        );
        _finalize();
        return;
      }

      if (!metrics.isInsideGuide) {
        _updateState(LivenessStep.alignFace, 'Center your face in the circle');
        return;
      }

      _singleFace = metrics.faceCount == 1;
      _spoofScore = metrics.spoofScore;

      final avgEyeOpen =
          (metrics.leftEyeOpenProbability + metrics.rightEyeOpenProbability) /
          2;

      // 🔥 Optimization: Batch state updates to reduce notifyListeners() calls
      if (!_blinkDetected) {
        if (!_eyesWereOpen && avgEyeOpen > 0.70) {
          _eyesWereOpen = true;
          _stateChanged = true;
        }
        if (_eyesWereOpen && avgEyeOpen < 0.35) {
          _blinkDetected = true;
          _updateState(
            LivenessStep.turnHead,
            LivenessStep.turnHead.instruction,
          );
          return;
        }
        _updateState(LivenessStep.blink, LivenessStep.blink.instruction);
        return;
      }

      if (!_turnDetected) {
        if (metrics.headYaw.abs() > 15) {
          _turnDetected = true;
          _updateState(LivenessStep.smile, LivenessStep.smile.instruction);
          return;
        }
        _updateState(LivenessStep.turnHead, LivenessStep.turnHead.instruction);
        return;
      }

      if (!_smileDetected) {
        if (metrics.smileProbability > 0.60) {
          _smileDetected = true;
          _updateState(
            LivenessStep.verifying,
            LivenessStep.verifying.instruction,
          );
          return;
        }
        _updateState(LivenessStep.smile, LivenessStep.smile.instruction);
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

        final success = _result!.isLive;
        _updateState(
          success ? LivenessStep.success : LivenessStep.failed,
          _result!.message,
        );
        _finalize();
      }
    } catch (e) {
      _updateState(LivenessStep.failed, 'Processing error: $e');
      _finalize();
    } finally {
      _isBusy = false;
      if (_stateChanged) {
        notifyListeners();
      }
    }
  }

  // 🔥 Optimization: Only notify listeners on actual state changes
  void _updateState(LivenessStep newStep, String newHint) {
    if (_step != newStep || _hint != newHint) {
      _step = newStep;
      _hint = newHint;
      _stateChanged = true;
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
