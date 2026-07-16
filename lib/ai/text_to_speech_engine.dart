import 'package:flutter_tts/flutter_tts.dart';
import 'analytics_logging.dart';

class TextToSpeechEngine {
  final FlutterTts _tts = FlutterTts();

  TextToSpeechEngine() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.55);
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      AnalyticsLogging.log("TTS", "Failed to initialize TTS", error: e);
    }
  }

  Future<void> speak(String text) async {
    AnalyticsLogging.log("TTS", "Speaking: $text");
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
