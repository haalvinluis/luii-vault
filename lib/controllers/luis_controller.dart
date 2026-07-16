import '../models/luis_ai_response.dart';
import '../services/claude_ai_service.dart';
import '../services/voice_service.dart';

/// A handler your app registers for a given action name, e.g. "open_screen"
/// -> navigate to the requested screen. Return true if the action actually
/// succeeded, false if it could not be completed (Luis will not claim success
/// it did not achieve).
typedef LuisActionHandler = Future<bool> Function(Map<String, dynamic> params);

/// The single entry point your existing app talks to. Wire this up once
/// (e.g. in a Provider/Riverpod/GetIt singleton), register your action
/// handlers, then call `startListeningForWakeWord()` when the app is ready.
class LuisController {
  final ClaudeAiService aiService;
  final VoiceService voiceService;

  final Map<String, LuisActionHandler> _handlers = {};

  LuisController({required this.aiService, required this.voiceService});

  /// Register how a specific action name maps to a real effect in your app.
  void registerHandler(String action, LuisActionHandler handler) {
    _handlers[action] = handler;
  }

  Future<void> startListeningForWakeWord() async {
    await voiceService.init();
    await voiceService.startWakeListening(onWake: _onWakeDetected);
  }

  Future<void> stop() async {
    await voiceService.stopWakeListening();
  }

  void _onWakeDetected() {
    _handleCommandTurn();
  }

  /// Call this directly (e.g. from a manual mic button tap) to skip the wake
  /// word and go straight to listening for one command.
  Future<void> manualActivate() async {
    await _handleCommandTurn();
  }

  Future<void> _handleCommandTurn() async {
    final transcript = await voiceService.listenForCommand();

    if (transcript == null) {
      await startListeningForWakeWord();
      return;
    }

    final lower = transcript.toLowerCase().trim();
    if (lower == 'stop listening' || lower == 'cancel') {
      await voiceService.speak('Okay, stopping.');
      return;
    }

    LuisAiResponse response;
    try {
      response = await aiService.send(transcript);
    } catch (e) {
      await voiceService.speak(
        "Sorry, I could not reach the AI service just now. Please try again.",
      );
      await startListeningForWakeWord();
      return;
    }

    if (response.isCommand) {
      final results = <bool>[];
      for (final intent in response.intents) {
        final handler = _handlers[intent.action];
        if (handler == null) {
          results.add(false);
          continue;
        }
        final ok = await handler({'value': intent.value});
        results.add(ok);
      }

      if (results.isNotEmpty && results.every((r) => r == true)) {
        await voiceService.speak(response.reply);
      } else if (results.contains(true)) {
        await voiceService.speak(response.reply);
      } else {
        await voiceService.speak(
          "I could not complete that -- that action is not set up yet.",
        );
      }
    } else {
      await voiceService.speak(response.reply);
    }

    await startListeningForWakeWord();
  }
}
