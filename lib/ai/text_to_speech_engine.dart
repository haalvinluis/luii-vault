import 'package:flutter_tts/flutter_tts.dart';
import 'analytics_logging.dart';

class TextToSpeechEngine {
  final FlutterTts _tts = FlutterTts();

  TextToSpeechEngine() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage("en-GB");
      await _tts.setPitch(0.88); // Deeper, professional Jarvis voice
      await _tts.setSpeechRate(0.48); // Calm and structured British pace
      await _tts.awaitSpeakCompletion(true);

      final List<dynamic>? voices = await _tts.getVoices;
      if (voices != null) {
        dynamic selectedVoice;
        for (var voice in voices) {
          final String name = (voice["name"] as String? ?? "").toLowerCase();
          final String locale = (voice["locale"] as String? ?? "").toLowerCase();
          
          if (locale.startsWith("en-gb")) {
            // Prefer a British male voice or standard British voice
            if (name.contains("male") || name.contains("gbd") || name.contains("gdb") || name.contains("rjs") || name.contains("guy")) {
              selectedVoice = voice;
              break;
            }
            selectedVoice ??= voice;
          }
        }
        if (selectedVoice != null) {
          final Map<String, String> voiceMap = {
            "name": (selectedVoice["name"] as String? ?? ""),
            "locale": (selectedVoice["locale"] as String? ?? ""),
          };
          await _tts.setVoice(voiceMap);
          AnalyticsLogging.log("TTS", "Selected Jarvis Voice: ${voiceMap['name']}");
        }
      }
    } catch (e) {
      AnalyticsLogging.log("TTS", "Failed to initialize Jarvis TTS", error: e);
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
