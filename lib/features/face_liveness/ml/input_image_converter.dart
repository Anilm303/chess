import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart' show Size;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

InputImage? cameraImageToInputImage(
  CameraImage image,
  CameraDescription camera,
) {
  if (image.planes.isEmpty) return null;

  final allBytes = <int>[];
  for (final Plane plane in image.planes) {
    allBytes.addAll(plane.bytes);
  }
  final bytes = Uint8List.fromList(allBytes);

  final imageSize = Size(image.width.toDouble(), image.height.toDouble());

  final imageRotation =
      InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
      InputImageRotation.rotation0deg;

  final inputImageFormat =
      InputImageFormatValue.fromRawValue(image.format.raw) ??
      InputImageFormat.nv21;

  final metadata = InputImageMetadata(
    size: imageSize,
    rotation: imageRotation,
    format: inputImageFormat,
    bytesPerRow: image.planes.isNotEmpty
        ? image.planes.first.bytesPerRow
        : image.width,
  );

  return InputImage.fromBytes(bytes: bytes, metadata: metadata);
}
