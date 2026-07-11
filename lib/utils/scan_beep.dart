import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';

class ScanBeep {
  ScanBeep._();

  static bool _enabled = true;
  static bool _initialized = false;
  static AudioPlayer? _player;
  static late Uint8List _beepBytes;

  static Future<void> init() async {
    final val = await DatabaseHelper.instance.getSetting('scan_beep_enabled');
    _enabled = val != 'false';
    _beepBytes = _generateBeep();
    _initialized = true;
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    await DatabaseHelper.instance.setSetting('scan_beep_enabled', value ? 'true' : 'false');
  }

  static bool get isEnabled => _enabled;

  static Future<void> play() async {
    HapticFeedback.lightImpact();
    if (!_enabled) return;
    if (!_initialized) await init();
    try {
      _player ??= AudioPlayer();
      await _player!.stop();
      await _player!.play(BytesSource(_beepBytes));
    } catch (_) {}
  }

  static Uint8List _generateBeep() {
    const sampleRate = 44100;
    const durationMs = 80;
    const freq = 1200.0;
    const amplitude = 0.7;
    final sampleCount = (sampleRate * durationMs / 1000).round();
    const fadeLen = 200;

    final pcm = Int16List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      var envelope = 1.0;
      if (i < fadeLen) {
        envelope = i / fadeLen;
      } else if (i > sampleCount - fadeLen) {
        envelope = (sampleCount - i) / fadeLen;
      }
      pcm[i] = (amplitude * envelope * 32767 * sin(2 * pi * freq * t)).round().clamp(-32768, 32767);
    }

    final dataBytes = pcm.buffer.asUint8List();
    final fileSize = 36 + dataBytes.length;

    final header = ByteData(44);
    void writeString(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    header.setUint32(4, fileSize, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    writeString(36, 'data');
    header.setUint32(40, dataBytes.length, Endian.little);

    final wav = Uint8List(44 + dataBytes.length);
    wav.setAll(0, header.buffer.asUint8List());
    wav.setAll(44, dataBytes);
    return wav;
  }

  static void dispose() {
    _player?.dispose();
    _player = null;
  }
}
