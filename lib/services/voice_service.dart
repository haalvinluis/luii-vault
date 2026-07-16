import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

enum LuisVoiceState { idle, wakeListening, commandListening, speaking }

/// Wraps speech-to-text (listening) and text-to-speech (speaking).
///
/// Wake-word note: this uses continuous speech_to_text listening and checks
/// transcripts for "hey luis" -- simple and works out of the box, but it
/// keeps the mic active and uses more battery than a dedicated wake-word
/// engine. For a production always-on wake word with much lower power draw,
/// swap wakeListening's implementation for a package like `porcupine_flutter`
/// (Picovoice) and keep everything else in this file unchanged.
class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  final _stateController = StreamController<LuisVoiceState>.broadcast();
  Stream<LuisVoiceState> get stateStream => _stateController.stream;

  LuisVoiceState _state = LuisVoiceState.idle;
  LuisVoiceState get state => _state;

  bool _initialized = false;
  static const String wakePhrase = 'hey jarvis';

  Future<bool> init() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: (_) {},
      onError: (e) {
        _setState(LuisVoiceState.idle);
      },
    );
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    return _initialized;
  }

  void _setState(LuisVoiceState s) {
    _state = s;
    _stateController.add(s);
  }

  /// Starts continuous background listening for "Hey Luis". Calls
  /// [onWake] once the phrase is detected and stops wake-listening
  /// (call startWakeListening again afterward if you want it to resume).
  Future<void> startWakeListening({required VoidCallback onWake}) async {
    if (!_initialized) await init();
    _setState(LuisVoiceState.wakeListening);

    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.toLowerCase();
        if (text.contains(wakePhrase)) {
          _speech.stop();
          onWake();
        }
      },
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 8),
      partialResults: true,
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: false,
      ),
    );
  }

  Future<void> stopWakeListening() async {
    await _speech.stop();
    _setState(LuisVoiceState.idle);
  }

  /// Listens for a single command/utterance after the wake word (or after
  /// a manual mic-tap). Returns the final transcript, or null on timeout.
  Future<String?> listenForCommand({
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 2),
  }) async {
    if (!_initialized) await init();
    _setState(LuisVoiceState.commandListening);

    final completer = Completer<String?>();

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          if (!completer.isCompleted) {
            completer.complete(result.recognizedWords);
          }
        }
      },
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: true,
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: false,
      ),
    );

    // Fallback timeout in case no final result ever arrives.
    Future.delayed(listenFor + const Duration(seconds: 1), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    final result = await completer.future;
    await _speech.stop();
    _setState(LuisVoiceState.idle);
    return (result == null || result.trim().isEmpty) ? null : result;
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _setState(LuisVoiceState.speaking);
    await _tts.speak(text);
    _tts.setCompletionHandler(() => _setState(LuisVoiceState.idle));
  }

  Future<void> stopSpeaking() async => _tts.stop();

  Future<void> dispose() async {
    await _speech.stop();
    await _tts.stop();
    await _stateController.close();
  }
}

typedef VoidCallback = void Function();
