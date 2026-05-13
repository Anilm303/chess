import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/liveness_step.dart';
import '../../ml/input_image_converter.dart';
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
  bool _streaming = false;
  bool _navigated = false;
  String? _capturedPath;

  @override
  void initState() {
    super.initState();
    unawaited(_initCamera());
  }

  Future<void> _initCamera() async {
    final cams = await availableCameras();
    final front = cams.where(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (front.isEmpty) return;

    _frontCamera = front.first;
    _cameraController = CameraController(
      _frontCamera!,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.nv21,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (!mounted) return;
    setState(() {});

    await _cameraController!.startImageStream((image) async {
      if (_streaming || _navigated || !_cameraController!.value.isInitialized) {
        return;
      }

      _streaming = true;
      try {
        final input = cameraImageToInputImage(image, _frontCamera!);
        if (input == null) return;

        await _livenessController.processImage(
          input,
          previewSize:
              _cameraController!.value.previewSize ?? const Size(720, 1280),
        );

        if (!mounted || _navigated || !_livenessController.isDone) return;

        _navigated = true;
        await _cameraController?.stopImageStream();

        if (_livenessController.step == LivenessStep.success) {
          try {
            final pic = await _cameraController?.takePicture();
            _capturedPath = pic?.path;
          } catch (_) {
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
                  _livenessController.result?.message ??
                  _livenessController.hint,
            ),
          ),
        );
      } finally {
        _streaming = false;
      }
    });
  }

  @override
  void dispose() {
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
