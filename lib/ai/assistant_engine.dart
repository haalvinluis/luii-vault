import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'intent_classifier.dart';
import 'command_dispatcher.dart';
import 'context_manager.dart';
import 'text_to_speech_engine.dart';
import 'wake_word_detector.dart';
import 'speech_recognition_engine.dart';
import 'analytics_logging.dart';
import '../audio/binaural_engine.dart';

enum AssistantState {
  idle,
  wakeWordListening,
  wakeWordDetected,
  commandListening,
  processing,
  speaking,
  returningToWakeMode
}

class AssistantEngine extends ChangeNotifier {
  static final AssistantEngine _instance = AssistantEngine._internal();
  factory AssistantEngine() => _instance;

  AssistantEngine._internal() {
    _dispatcher = CommandDispatcher(contextManager: _context);
    
    // Low-power background microphone suspension logic
    BinauralEngine().addListener(() {
      final isPlaying = BinauralEngine().isPlaying;
      if (isPlaying) {
        if (_state == AssistantState.wakeWordListening || _state == AssistantState.idle) {
          _wakeWordDetector.stop();
        }
      } else {
        if ((_state == AssistantState.idle || _state == AssistantState.returningToWakeMode) && _isVoiceWakeEnabled && _isActive) {
          _listenForWakeWord();
        }
      }
    });
  }

  final ContextManager _context = ContextManager();
  final TextToSpeechEngine _tts = TextToSpeechEngine();
  final WakeWordDetector _wakeWordDetector = WakeWordDetector();
  final SpeechRecognitionEngine _speechEngine = SpeechRecognitionEngine();
  late final CommandDispatcher _dispatcher;

  AssistantState _state = AssistantState.idle;
  String _lastRecognizedWords = "";
  String _assistantReply = "";
  bool _isActive = false;
  bool _isVoiceWakeEnabled = true;
  int _consecutiveFailures = 0;
  bool _isWakeWordDegraded = false;
  
  // Safe music duck/pause tracking states
  bool _wasMusicPlaying = false;
  bool _isProcessing = false;
  Function(String page)? onNavigateCallback;

  AssistantState get state => _state;
  String get lastRecognizedWords => _lastRecognizedWords;
  String get assistantReply => _assistantReply;
  bool get isActive => _isActive;
  bool get isVoiceWakeEnabled => _isVoiceWakeEnabled;
  bool get isWakeWordDegraded => _isWakeWordDegraded;
  ContextManager get context => _context;

  set isVoiceWakeEnabled(bool value) {
    _isVoiceWakeEnabled = value;
    if (value) {
      startWakeWordScan();
    } else {
      _wakeWordDetector.stop();
      _state = AssistantState.idle;
    }
    notifyListeners();
  }

  Future<void> startWakeWordScan() async {
    _isActive = true;
    _isProcessing = false;
    _consecutiveFailures = 0;
    _transitionToIdle();
  }

  Future<void> stopWakeWordScan() async {
    _isActive = false;
    await _wakeWordDetector.stop();
    await _speechEngine.stop();
    await _tts.stop();
    _state = AssistantState.idle;
    notifyListeners();
  }

  void _transitionToIdle() {
    _state = AssistantState.returningToWakeMode;
    _isProcessing = false;
    notifyListeners();

    // Restore music playback if we ducked it during the command cycle
    if (_wasMusicPlaying) {
      _wasMusicPlaying = false;
      Timer(const Duration(milliseconds: 1500), () {
        BinauralEngine().fadeIn();
      });
    }

    // Only start wake scanning if music is NOT playing
    if (_isVoiceWakeEnabled && _isActive && !BinauralEngine().isPlaying) {
      _listenForWakeWord();
    } else {
      _wakeWordDetector.stop();
      _state = AssistantState.idle;
      notifyListeners();
    }
  }

  Future<void> _listenForWakeWord() async {
    if (!_isVoiceWakeEnabled || !_isActive || BinauralEngine().isPlaying) {
      _state = AssistantState.idle;
      notifyListeners();
      return;
    }

    // Prevent duplicate listening scanners from initializing
    if (_wakeWordDetector.isListening) {
      _state = AssistantState.wakeWordListening;
      return;
    }

    _state = AssistantState.wakeWordListening;
    notifyListeners();

    try {
      await _wakeWordDetector.start(
        onWakeWordTriggered: () async {
          if (_state == AssistantState.wakeWordListening) {
            AnalyticsLogging.log("Engine", "Wake word triggered successfully.");
            _state = AssistantState.wakeWordDetected;
            notifyListeners();
            triggerListening();
          }
        },
        onDone: () {
          // Restart background listener after timeout unless state has transitioned
          if (_isActive && _state == AssistantState.wakeWordListening && _isVoiceWakeEnabled && !BinauralEngine().isPlaying) {
            _listenForWakeWord();
          }
        },
      );
    } catch (e) {
      _consecutiveFailures++;
      AnalyticsLogging.log("Engine", "Wake word background check failure $_consecutiveFailures", error: e);
      if (_consecutiveFailures >= 3) {
        _isWakeWordDegraded = true;
        _isVoiceWakeEnabled = false;
        _assistantReply = "Voice wake word isn't available right now — type your command.";
        _state = AssistantState.speaking;
        notifyListeners();
        _tts.speak(_assistantReply);
      } else {
        Timer(const Duration(seconds: 5), () {
          if (_isActive && (_state == AssistantState.wakeWordListening || _state == AssistantState.idle) && !BinauralEngine().isPlaying) {
            _listenForWakeWord();
          }
        });
      }
    }
  }

  Future<void> triggerListening() async {
    await _tts.stop();
    await _wakeWordDetector.stop();
    await Future.delayed(const Duration(milliseconds: 300));
    
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.click);

    // Automatically navigate to Assistant screen
    if (onNavigateCallback != null) {
      onNavigateCallback!("assistant");
    }
    
    // Record music playing state and intentionally pause it during voice entry
    if (BinauralEngine().isPlaying) {
      _wasMusicPlaying = true;
      BinauralEngine().pause();
    }

    // Custom premium wake confirmation: Say "Hi! I'm listening" first
    _state = AssistantState.speaking;
    _lastRecognizedWords = "";
    _assistantReply = "Hi! I'm listening.";
    notifyListeners();

    await _tts.speak("Hi! I'm listening.");

    // Enter command listening state once speak completes
    _state = AssistantState.commandListening;
    _lastRecognizedWords = "Listening...";
    notifyListeners();

    await _speechEngine.listen(
      onResult: (text, isFinal) {
        _lastRecognizedWords = text;
        notifyListeners();
      },
      onDone: () {
        final cleanWords = _lastRecognizedWords.trim();
        if (cleanWords.isNotEmpty && 
            cleanWords != "Listening..." && 
            cleanWords != "Listening") {
          processWords(_lastRecognizedWords);
        } else {
          _transitionToIdle();
        }
      },
    );
  }

  Future<void> startPushToTalk() async {
    await _tts.stop();
    await _wakeWordDetector.stop();
    await Future.delayed(const Duration(milliseconds: 300));
    
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.click);

    if (BinauralEngine().isPlaying) {
      _wasMusicPlaying = true;
      BinauralEngine().pause();
    }

    _state = AssistantState.commandListening;
    _lastRecognizedWords = "Listening (Hold)...";
    _assistantReply = "";
    notifyListeners();

    await _speechEngine.listen(
      onResult: (text, isFinal) {
        _lastRecognizedWords = text;
        notifyListeners();
      },
      onDone: () {},
    );
  }

  Future<void> stopPushToTalk() async {
    await _speechEngine.stop();
    final cleanWords = _lastRecognizedWords.trim();
    if (cleanWords.isNotEmpty && 
        cleanWords != "Listening (Hold)..." && 
        cleanWords != "Listening...") {
      processWords(_lastRecognizedWords);
    } else {
      _transitionToIdle();
    }
  }

  Future<void> processWords(String text) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final cleanText = text.toLowerCase().trim();
    if (cleanText == "stop listening" || 
        cleanText == "cancel" || 
        cleanText == "stop" || 
        cleanText == "never mind") {
      _transitionToIdle();
      return;
    }

    _state = AssistantState.processing;
    notifyListeners();

    final reply = await _dispatcher.dispatch(text, onNavigateCallback);
    
    await _tts.stop();

    _assistantReply = reply;
    _state = AssistantState.speaking;
    notifyListeners();

    // Await speech completion before sequentially starting continuous listening
    await _tts.speak(reply);

    _isProcessing = false;
    if (_isActive && _state == AssistantState.speaking) {
      _transitionToIdle();
    }
  }
}
