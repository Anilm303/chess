import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/liveness_step.dart';
import '../../ml/input_image_converter.dart';
import '../../ml/input_image_converter_optimized.dart';
import '../controllers/face_liveness_controller.dart';
import '../widgets/liveness_status_card.dart';
import '../widgets/scanner_overlay.dart';
import 'liveness_failure_screen.dart';
import 'liveness_success_screen.dart';

class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({super.key});

  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen> {
  final FaceLivenessController _livenessController = FaceLivenessController();

  CameraController? _cameraController;
  CameraDescription? _frontCamera;
  bool _processing = false;
  bool _navigated = false;
  String? _capturedPath;
  int _frameCount = 0;
  static const int _frameSkip = 2; // Process every 3rd frame (30 FPS → 10 FPS)
  int _lastProcessedFrame = -_frameSkip;

  @override
  void initState() {
    super.initState();
    unawaited(_initCamera());
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final front = cams.where(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (front.isEmpty) {
        _showError('Front camera not available');
        return;
      }

      _frontCamera = front.first;
      _cameraController = CameraController(
        _frontCamera!,
        ResolutionPreset.low, // 🔥 Reduced from 'medium' for faster processing
        imageFormatGroup: ImageFormatGroup.nv21,
        enableAudio: false,
        fps: 15, // 🔥 Limit FPS to reduce frame processing load
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() {});

      _startFrameProcessing();
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  // 🔥 Optimized frame processing with intelligent frame skipping
  void _startFrameProcessing() {
    _cameraController?.startImageStream((image) {
      _frameCount++;

      // 🔥 Skip frames to reduce ML processing load
      if (_frameCount - _lastProcessedFrame < _frameSkip) {
        return; // Skip this frame, process next qualified frame
      }

      if (_processing || _navigated) {
        return;
      }

      _lastProcessedFrame = _frameCount;
      _processFrameAsync(image);
    });
  }

  // 🔥 Non-blocking async frame processing
  Future<void> _processFrameAsync(CameraImage image) async {
    _processing = true;
    try {
      // 🔥 Optimized image conversion (minimal copies)
      final input = cameraImageToInputImageOptimized(image, _frontCamera!);
      if (input == null) return;

      // 🔥 Process without blocking UI
      await _livenessController.processImage(
        input,
        previewSize:
            _cameraController!.value.previewSize ?? const Size(360, 480),
      );

      // 🔥 Check if verification is complete
      if (!mounted || _navigated || !_livenessController.isDone) return;

      _navigated = true;
      await _cameraController?.stopImageStream();

      // 🔥 Capture image after successful detection
      if (_livenessController.step == LivenessStep.success) {
        try {
          final pic = await _cameraController?.takePicture();
          _capturedPath = pic?.path;
        } catch (e) {
          debugPrint('Failed to capture image: $e');
          _capturedPath = null;
        }

        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LivenessSuccessScreen(
              message:
                  _livenessController.result?.message ??
                  'Verification succeeded.',
              capturedPath: _capturedPath,
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LivenessFailureScreen(
            reason:
                _livenessController.result?.message ?? _livenessController.hint,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Frame processing error: $e');
    } finally {
      _processing = false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _livenessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _livenessController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF020B14),
          appBar: AppBar(
            title: const Text('Face Liveness Check'),
            backgroundColor: Colors.transparent,
            actions: [
              TextButton(
                onPressed: _livenessController.retry,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Color(0xFF00D4FF)),
                ),
              ),
            ],
          ),
          body:
              _cameraController == null ||
                  !_cameraController!.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    Positioned.fill(child: CameraPreview(_cameraController!)),
                    const Positioned.fill(child: ScannerOverlay()),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 14,
                      child: LivenessStatusCard(
                        step: _livenessController.step,
                        hint: _livenessController.hint,
                        blinkDetected: _livenessController.blinkDetected,
                        turnDetected: _livenessController.turnDetected,
                        smileDetected: _livenessController.smileDetected,
                        spoofScore: _livenessController.spoofScore,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
