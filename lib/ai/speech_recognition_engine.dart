import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/speech_listener.dart';
import 'analytics_logging.dart';

class SpeechRecognitionEngine {
  final SpeechListener _speech = SpeechListener();
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<void> listen({
    required Function(String text, bool isFinal) onResult,
    required VoidCallback onDone,
  }) async {
    if (_isListening) return;
    _isListening = true;
    AnalyticsLogging.log("SpeechEngine", "Starting active speech listener...");

    bool doneCalled = false;
    void triggerDone() {
      if (!doneCalled) {
        doneCalled = true;
        _isListening = false;
        _speech.onStatusCallback = null; // Clear callback first to prevent overlaps
        onDone();
      }
    }

    try {
      final ok = await _speech.listen(
        (recognizedWords) {
          if (!_isListening) return;
          onResult(recognizedWords, false);
        },
        triggerOnPartial: true,
        listenMode: ListenMode.confirmation,
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(seconds: 15),
      );

      _speech.onStatusCallback = (status) {
        AnalyticsLogging.log("SpeechEngine", "Status change: $status");
        if (status == "done" || status == "notListening" || status == "error") {
          triggerDone();
        }
      };

      if (!ok) {
        triggerDone();
      }
    } catch (e) {
      AnalyticsLogging.log("SpeechEngine", "Exception in speech listener", error: e);
      triggerDone();
    }
  }

  Future<void> stop() async {
    _isListening = false;
    await _speech.stop();
  }
}
