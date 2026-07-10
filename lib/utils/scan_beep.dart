import 'package:flutter/services.dart';

class ScanBeep {
  static void play() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }
}
