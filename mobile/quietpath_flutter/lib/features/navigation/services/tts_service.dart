import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  TtsService._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _tts.setLanguage('en-US');
      // Gentle, calm cadence to prevent sensory startling
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(0.85);
      _isInitialized = true;
    } catch (_) {
      // Graceful fallback if emulator lacks TTS engine
    }
  }

  Future<void> speakCalm(String message) async {
    try {
      await init();
      await _tts.stop();
      await _tts.speak(message);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
