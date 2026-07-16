import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'permissions_service.dart';

class SpeechListener {
  static final SpeechListener _instance = SpeechListener._internal();
  factory SpeechListener() => _instance;
  SpeechListener._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  Function(String)? onStatusCallback;

  Future<bool> init() async {
    final hasPermission = await PermissionsService.requestMicPermission();
    if (!hasPermission) return false;

    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          if (onStatusCallback != null) {
            onStatusCallback!(status);
          }
        },
        onError: (error) {
          debugPrint("Speech Listener STT Error: $error");
          if (onStatusCallback != null) {
            onStatusCallback!("error");
          }
        },
        debugLogging: true,
      );
    } catch (e) {
      debugPrint("Speech initialization exception: $e");
      _isInitialized = false;
    }
    return _isInitialized;
  }

  Future<bool> listen(
    Function(String) onResult, {
    bool triggerOnPartial = false,
    ListenMode listenMode = ListenMode.search,
    Duration pauseFor = const Duration(seconds: 2),
    Duration listenFor = const Duration(seconds: 15),
  }) async {
    if (!_isInitialized) {
      final ok = await init();
      if (!ok) return false;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (triggerOnPartial || result.finalResult) {
            onResult(result.recognizedWords);
          }
        },
        listenMode: listenMode,
        pauseFor: pauseFor,
        listenFor: listenFor,
        partialResults: triggerOnPartial,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> stop() async {
    await _speech.stop();
  }
}
