import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/speech_listener.dart';
import 'analytics_logging.dart';

class WakeWordDetector {
  final SpeechListener _speech = SpeechListener();
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<void> start({
    required VoidCallback onWakeWordTriggered,
    required VoidCallback onDone,
  }) async {
    if (_isListening) return;
    _isListening = true;
    AnalyticsLogging.log("WakeWord", "Initializing wake word scanner...");

    try {
      final ok = await _speech.listen(
        (recognizedWords) {
          if (!_isListening) return;
          final clean = recognizedWords.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
          AnalyticsLogging.log("WakeWord", "Partial word check: '$recognizedWords'");
          
          final words = clean.split(RegExp(r'\s+'));
          bool matched = false;
          for (var word in words) {
            if (word == "jarvis" || word == "jarves" || word == "jarvs" || word == "jarvises" || word == "jarb") {
              matched = true;
              break;
            }
          }

          if (matched) {
            _isListening = false;
            _speech.onStatusCallback = null; // Prevent double status callbacks
            _speech.stop().then((_) {
              onWakeWordTriggered();
            });
          }
        },
        triggerOnPartial: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(hours: 24),
        listenFor: const Duration(hours: 24),
      );

      _speech.onStatusCallback = (status) {
        AnalyticsLogging.log("WakeWord", "Status change: $status");
        if (status == "done" || status == "notListening" || status == "error") {
          if (_isListening) {
            _isListening = false;
            _speech.onStatusCallback = null;
            onDone();
          }
        }
      };

      if (!ok) {
        _isListening = false;
        _speech.onStatusCallback = null;
        onDone();
      }
    } catch (e) {
      AnalyticsLogging.log("WakeWord", "Exception in wake word listener", error: e);
      _isListening = false;
      _speech.onStatusCallback = null;
      onDone();
    }
  }

  Future<void> stop() async {
    _isListening = false;
    await _speech.stop();
  }
}
