import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioEngine {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  Completer<void>? _speechCompleter;

  AudioEngine() {
    _tts.setCompletionHandler(() {
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
    });
    _tts.setErrorHandler((msg) {
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
    });
    _tts.setCancelHandler(() {
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
    });
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      await _tts.setLanguage("en-US");
      await _tts.setPitch(0.75); // Deeper pitch for male voice
      await _tts.setSpeechRate(0.48);
      
      // Attempt to load and set a system-specific male voice
      final List<dynamic>? voices = await _tts.getVoices;
      if (voices != null) {
        for (var voice in voices) {
          final Map<String, String> voiceMap = {
            "name": (voice["name"] as String? ?? ""),
            "locale": (voice["locale"] as String? ?? ""),
          };
          final String name = voiceMap["name"]!.toLowerCase();
          final String locale = voiceMap["locale"]!;
          if (locale.startsWith("en") && 
              (name.contains("male") || name.contains("iom") || name.contains("iol") || name.contains("guy") || name.contains("man"))) {
            await _tts.setVoice(voiceMap);
            break;
          }
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint("TTS initialization failed: $e");
    }
  }

  Future<void> speak(String text) async {
    try {
      await _init();
      await _tts.stop();
      
      _speechCompleter = Completer<void>();
      await _tts.speak(text);
      await _speechCompleter!.future; // Wait for speech completion!
    } catch (e) {
      debugPrint("TTS speak failed: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
    } catch (e) {
      debugPrint("TTS stop failed: $e");
    }
  }
}
