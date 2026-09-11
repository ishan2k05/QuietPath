import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service providing calm, low-stimulus speech guidance for sensory navigation.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  TtsService._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // Discover available engines without forcing an unavailable package
      try {
        final defaultEngine = await _tts.getDefaultEngine;
        debugPrint('[TtsService] Android default TTS engine: $defaultEngine');
      } catch (e) {
        debugPrint('[TtsService] Engine check: $e');
      }

      await _tts.setLanguage('en-US');
      // Gentle, calm cadence with full audible clarity
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.setQueueMode(0); // 0 = flush previous speech immediately
      await _tts.awaitSpeakCompletion(false); // Non-blocking to prevent UI lockup

      _tts.setStartHandler(() {
        _isSpeaking = true;
        debugPrint('[TtsService] Audio playback started');
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        debugPrint('[TtsService] Audio playback completed');
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('[TtsService] TTS platform error: $msg');
      });

      _isInitialized = true;
      debugPrint('[TtsService] TTS initialized successfully');
    } catch (e) {
      debugPrint('[TtsService] Init exception: $e');
    }
  }

  Future<void> speakCalm(String message) async {
    try {
      debugPrint('[TtsService] speakCalm: "$message"');
      await init();
      if (_isSpeaking) {
        await _tts.stop();
      }
      final result = await _tts.speak(message);
      debugPrint('[TtsService] speak returned code: $result');
    } catch (e) {
      debugPrint('[TtsService] speakCalm exception: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (_) {}
  }
}
