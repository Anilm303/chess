enum LivenessStep {
  alignFace,
  blink,
  turnHead,
  smile,
  verifying,
  success,
  failed,
}

extension LivenessStepLabel on LivenessStep {
  String get instruction {
    switch (this) {
      case LivenessStep.alignFace:
        return 'Align your face inside the scanner';
      case LivenessStep.blink:
        return 'Please blink once';
      case LivenessStep.turnHead:
        return 'Turn your head slightly to the right';
      case LivenessStep.smile:
        return 'Smile naturally';
      case LivenessStep.verifying:
        return 'Verifying liveness...';
      case LivenessStep.success:
        return 'Verification complete';
      case LivenessStep.failed:
        return 'Verification failed';
    }
  }
}
