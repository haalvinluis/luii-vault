import 'dart:math';
import 'package:flutter/material.dart';
import '../../ai/assistant_engine.dart';
import '../../core/theme.dart';
import 'mic_listening_wave.dart';
import 'typewriter_text.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> with TickerProviderStateMixin {
  final AssistantEngine _engine = AssistantEngine();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _rotationController;
  late AnimationController _breathingController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _breathingController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaultTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "LUIS ASSISTANT",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          AnimatedBuilder(
            animation: _engine,
            builder: (context, child) {
              return IconButton(
                icon: Icon(
                  _engine.isActive ? Icons.mic_rounded : Icons.mic_off_rounded,
                  color: _engine.isActive ? VaultTheme.neonCyan : VaultTheme.textMuted,
                ),
                onPressed: () {
                  if (_engine.isActive) {
                    _engine.stopWakeWordScan();
                  } else {
                    _engine.startWakeWordScan();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _engine,
        builder: (context, child) {
          final state = _engine.state;
          final history = _engine.context.conversationHistory;

          // Scroll to bottom when history changes
          _scrollToBottom();

          final isListening = state == AssistantState.commandListening;
          final isWakeListening = state == AssistantState.wakeWordListening;
          final isProcessing = state == AssistantState.processing;
          final isSpeaking = state == AssistantState.speaking;

          String stateText;
          if (!_engine.isActive) {
            stateText = "Tap Avatar to Enable Microphone";
          } else if (isListening) {
            stateText = "Listening for Command...";
          } else if (isProcessing) {
            stateText = "Thinking...";
          } else if (isSpeaking) {
            stateText = "Speaking...";
          } else {
            stateText = "Listening for \"Luis\" or \"Luii\"...";
          }

          return Column(
            children: [
              const SizedBox(height: 16),
              // AI Avatar Visualizer Section
              GestureDetector(
                onTap: () {
                  if (_engine.isActive) {
                    _engine.stopWakeWordScan();
                  } else {
                    _engine.startWakeWordScan();
                  }
                },
                child: Center(
                  child: _buildAvatarVisualizer(state),
                ),
              ),
              
              const SizedBox(height: 12),
              // Dedicated Premium Microphone Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: !_engine.isActive
                      ? Colors.redAccent.withValues(alpha: 0.1)
                      : state == AssistantState.commandListening
                          ? VaultTheme.hotPink.withValues(alpha: 0.15)
                          : state == AssistantState.processing
                              ? VaultTheme.electricViolet.withValues(alpha: 0.15)
                              : VaultTheme.neonCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: !_engine.isActive
                        ? Colors.redAccent.withValues(alpha: 0.3)
                        : state == AssistantState.commandListening
                            ? VaultTheme.hotPink.withValues(alpha: 0.4)
                            : state == AssistantState.processing
                                ? VaultTheme.electricViolet.withValues(alpha: 0.4)
                                : VaultTheme.neonCyan.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !_engine.isActive
                            ? Colors.redAccent
                            : state == AssistantState.commandListening
                                ? VaultTheme.hotPink
                                : state == AssistantState.processing
                                    ? VaultTheme.electricViolet
                                    : VaultTheme.neonCyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (!_engine.isActive
                              ? "OFF"
                              : state == AssistantState.commandListening
                                  ? "Listening for Command"
                                  : state == AssistantState.processing
                                      ? "Processing"
                                      : "Listening for Wake Word")
                          .toUpperCase(),
                      style: TextStyle(
                        color: !_engine.isActive
                            ? Colors.redAccent
                            : state == AssistantState.commandListening
                                ? VaultTheme.hotPink
                                : state == AssistantState.processing
                                    ? VaultTheme.electricViolet
                                    : VaultTheme.neonCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              // State Text Info
              Text(
                stateText,
                style: TextStyle(
                  color: !_engine.isActive
                      ? VaultTheme.textMuted
                      : isListening || isWakeListening
                          ? VaultTheme.neonCyan
                          : isProcessing
                              ? VaultTheme.electricViolet
                              : isSpeaking
                                  ? VaultTheme.hotPink
                                  : VaultTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),

              const SizedBox(height: 16),
              // Active Waveform when listening
              if (isListening) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: MicListeningWave(isActive: true),
                ),
                const SizedBox(height: 12),
              ],

              // Conversation History Section
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: history.isEmpty
                      ? Center(
                          child: Text(
                            "No conversation history yet.\nSay \"Hey Luis\" or type below to start.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: VaultTheme.textMuted, fontSize: 13, height: 1.5),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final text = history[index];
                            final isLuis = text.startsWith("Luis: ");
                            final cleanText = isLuis ? text.substring(6) : text;

                            return Align(
                              alignment: isLuis ? Alignment.centerLeft : Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isLuis
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : VaultTheme.neonCyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16).copyWith(
                                    bottomLeft: isLuis ? const Radius.circular(0) : const Radius.circular(16),
                                    bottomRight: isLuis ? const Radius.circular(16) : const Radius.circular(0),
                                  ),
                                  border: Border.all(
                                    color: isLuis
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : VaultTheme.neonCyan.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: isLuis && index == history.length - 1
                                    ? TypewriterText(
                                        text: cleanText,
                                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                      )
                                    : Text(
                                        cleanText,
                                        style: TextStyle(
                                          color: isLuis ? Colors.white : Colors.white.withValues(alpha: 0.95),
                                          fontSize: 13.5,
                                        ),
                                      ),
                               ),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(height: 12),
              // Typing / Keyboard Text Input Bar at bottom of screen
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 96), // Clears bottom nav margin
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: VaultTheme.neonCyan.withValues(alpha: 0.2)),
                        ),
                        child: TextField(
                          controller: _chatController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          cursorColor: VaultTheme.neonCyan,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: InputBorder.none,
                            hintText: "Type a command...",
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              _engine.processWords(value.trim());
                              _chatController.clear();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: VaultTheme.neonCyan.withValues(alpha: 0.15),
                        border: Border.all(color: VaultTheme.neonCyan.withValues(alpha: 0.4)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: VaultTheme.neonCyan, size: 18),
                        onPressed: () {
                          final text = _chatController.text.trim();
                          if (text.isNotEmpty) {
                            _engine.processWords(text);
                            _chatController.clear();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatarVisualizer(AssistantState state) {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        final bool isActive = _engine.isActive;
        final double scale = isActive ? 1.0 + (_breathingController.value * 0.08) : 1.0;
        
        final isProcessing = state == AssistantState.processing;
        final isSpeaking = state == AssistantState.speaking;
        final isIdle = state == AssistantState.idle || state == AssistantState.returningToWakeMode;

        Color glowColor = isActive 
            ? (state == AssistantState.commandListening
                ? VaultTheme.hotPink
                : isProcessing
                    ? VaultTheme.electricViolet
                    : isSpeaking
                        ? VaultTheme.hotPink
                        : VaultTheme.neonCyan)
            : Colors.redAccent.withValues(alpha: 0.5);

        return Transform.scale(
          scale: (isActive && isIdle) ? scale : 1.0,
          child: Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isActive 
                  ? SweepGradient(
                      colors: [
                        VaultTheme.neonCyan,
                        VaultTheme.electricViolet,
                        VaultTheme.hotPink,
                        VaultTheme.neonCyan,
                      ],
                      transform: GradientRotation(_rotationController.value * 2 * pi),
                    )
                  : const LinearGradient(
                      colors: [Colors.black54, Color(0xFF1E1E2E)],
                    ),
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? glowColor.withValues(alpha: isIdle ? 0.3 + (_breathingController.value * 0.15) : 0.5)
                      : Colors.redAccent.withValues(alpha: 0.1),
                  blurRadius: isActive ? (isIdle ? 20 + (_breathingController.value * 10) : 30) : 10,
                  spreadRadius: isActive ? (isIdle ? 2 + (_breathingController.value * 3) : 5) : 1,
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0A0915),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: !isActive
                    ? const Icon(
                        Icons.mic_off_rounded,
                        color: Colors.redAccent,
                        size: 40,
                      )
                    : isProcessing
                        ? const SizedBox(
                            height: 36,
                            width: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.0,
                              valueColor: AlwaysStoppedAnimation<Color>(VaultTheme.electricViolet),
                            ),
                          )
                        : Icon(
                            state == AssistantState.commandListening
                                ? Icons.mic_rounded
                                : isSpeaking
                                    ? Icons.volume_up_rounded
                                    : Icons.psychology,
                            color: glowColor,
                            size: 40,
                          ),
              ),
            ),
          ),
        );
      },
    );
  }
}
