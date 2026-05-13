class FrameMetrics {
  final int faceCount;
  final double leftEyeOpenProbability;
  final double rightEyeOpenProbability;
  final double smileProbability;
  final double headYaw;
  final double spoofScore;
  final bool isInsideGuide;
  final bool hasEnoughMotion;

  const FrameMetrics({
    required this.faceCount,
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
    required this.smileProbability,
    required this.headYaw,
    required this.spoofScore,
    required this.isInsideGuide,
    required this.hasEnoughMotion,
  });
}
