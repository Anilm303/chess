class LivenessResult {
  final bool isLive;
  final String message;
  final double score;
  final bool blinkDetected;
  final bool turnDetected;
  final bool smileDetected;
  final bool singleFace;

  const LivenessResult({
    required this.isLive,
    required this.message,
    required this.score,
    required this.blinkDetected,
    required this.turnDetected,
    required this.smileDetected,
    required this.singleFace,
  });
}
