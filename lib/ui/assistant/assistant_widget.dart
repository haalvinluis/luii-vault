import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../ai/assistant_engine.dart';
import '../../core/theme.dart';
import 'mic_listening_wave.dart';
import 'typewriter_text.dart';

class LuiiAssistantWidget extends StatefulWidget {
  const LuiiAssistantWidget({super.key});

  @override
  State<LuiiAssistantWidget> createState() => _LuiiAssistantWidgetState();
}

class _LuiiAssistantWidgetState extends State<LuiiAssistantWidget> with TickerProviderStateMixin {
  final AssistantEngine _engine = AssistantEngine();
  final TextEditingController _textController = TextEditingController();
  
  late AnimationController _rotationController;
  late AnimationController _breathingController;
  
  double? _x;
  double? _y;
  bool _isDragging = false;
  bool _isHovered = false;
  bool _showSettings = false;

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
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (_x == null || _y == null) {
      if (size.width > 0 && size.height > 0) {
        _x = size.width - 76;
        _y = size.height - 160;
      }
    }

    // Dynamic constraint bounds clamp
    if (_x != null && _y != null && size.width > 0 && size.height > 0) {
      _x = _x!.clamp(10.0, size.width - 76.0);
      _y = _y!.clamp(40.0, size.height - 120.0);
    }

    return AnimatedBuilder(
      animation: _engine,
      builder: (context, child) {
        if (!_engine.isActive || _x == null || _y == null) return const SizedBox.shrink();

        final state = _engine.state;
        
        final isListening = state == AssistantState.commandListening || state == AssistantState.wakeWordListening;
        final isProcessing = state == AssistantState.processing;
        final isSpeaking = state == AssistantState.speaking;
        final isIdle = state == AssistantState.idle || state == AssistantState.returningToWakeMode;

        final showBubble = isListening || isProcessing || isSpeaking;

        return Positioned(
          left: _x,
          top: _y,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Conversational overlay speech bubble
              if (showBubble) ...[
                Container(
                  width: 260,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: VaultTheme.bgDeep.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: VaultTheme.neonCyan.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: VaultTheme.neonCyan.withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [VaultTheme.neonCyan, VaultTheme.electricViolet],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: VaultTheme.neonCyan.withOpacity(0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    "L",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Luis",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    isListening
                                        ? "Listening..."
                                        : isProcessing
                                            ? "Thinking..."
                                            : "Speaking",
                                    style: TextStyle(
                                      color: VaultTheme.neonCyan.withOpacity(0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              _showSettings ? Icons.close_rounded : Icons.tune_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _showSettings = !_showSettings;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_showSettings) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Voice Wake Word (\"Hey Luis\")",
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            Switch(
                              value: _engine.isVoiceWakeEnabled,
                              activeColor: VaultTheme.neonCyan,
                              onChanged: (val) {
                                _engine.isVoiceWakeEnabled = val;
                              },
                            ),
                          ],
                        ),
                      ] else ...[
                        if (isListening) ...[
                          Text(
                            _engine.lastRecognizedWords,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          const MicListeningWave(isActive: true),
                          const SizedBox(height: 12),
                          // Keyboard Typing Input Bar Fallback
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: VaultTheme.neonCyan.withOpacity(0.3)),
                                  ),
                                  child: TextField(
                                    controller: _textController,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    cursorColor: VaultTheme.neonCyan,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: InputBorder.none,
                                      hintText: "Type a command...",
                                      hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                    onSubmitted: (value) {
                                      if (value.trim().isNotEmpty) {
                                        _engine.processWords(value.trim());
                                        _textController.clear();
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                height: 38,
                                width: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: VaultTheme.neonCyan.withOpacity(0.15),
                                  border: Border.all(color: VaultTheme.neonCyan.withOpacity(0.4)),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.send_rounded, color: VaultTheme.neonCyan, size: 16),
                                  onPressed: () {
                                    final text = _textController.text.trim();
                                    if (text.isNotEmpty) {
                                      _engine.processWords(text);
                                      _textController.clear();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ] else if (isProcessing) ...[
                          const Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor: AlwaysStoppedAnimation<Color>(VaultTheme.electricViolet),
                              ),
                            ),
                          ),
                        ] else if (isSpeaking) ...[
                          TypewriterText(
                            text: _engine.assistantReply,
                            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
              
              // Floating Orb
              GestureDetector(
                onPanStart: (details) {
                  _isDragging = true;
                },
                onPanUpdate: (details) {
                  setState(() {
                    _x = (_x! + details.delta.dx).clamp(10, size.width - 66);
                    _y = (_y! + details.delta.dy).clamp(40, size.height - 120);
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    _isDragging = false;
                    // Snap to nearest side edge
                    if (_x! < size.width / 2) {
                      _x = 20;
                    } else {
                      _x = size.width - 76;
                    }
                  });
                },
                onLongPressStart: (details) {
                  _engine.startPushToTalk();
                },
                onLongPressEnd: (details) {
                  _engine.stopPushToTalk();
                },
                onTap: () {
                  if (isListening) {
                    _engine.startWakeWordScan();
                  } else {
                    _engine.triggerListening();
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isIdle 
                        ? (_isHovered || _isDragging ? 1.0 : 0.4) 
                        : 1.0,
                    child: AnimatedBuilder(
                      animation: _breathingController,
                      builder: (context, child) {
                        final scale = 1.0 + (_breathingController.value * 0.06);
                        return Transform.scale(
                          scale: isIdle ? scale : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 56,
                            width: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  VaultTheme.neonCyan,
                                  VaultTheme.electricViolet,
                                  VaultTheme.hotPink,
                                  VaultTheme.neonCyan,
                                ],
                                transform: GradientRotation(_rotationController.value * 2 * pi),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isListening
                                      ? VaultTheme.hotPink
                                      : VaultTheme.neonCyan)
                                      .withOpacity(isIdle ? 0.3 + (_breathingController.value * 0.15) : 0.5),
                                  blurRadius: isIdle ? 12 + (_breathingController.value * 6) : 18,
                                  spreadRadius: isIdle ? 1 + (_breathingController.value * 2) : 3,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF0F0E1E),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  isListening
                                      ? Icons.mic_rounded
                                      : isProcessing
                                          ? Icons.hourglass_empty_rounded
                                          : Icons.mic_none_rounded,
                                  color: isListening
                                      ? VaultTheme.hotPink
                                      : VaultTheme.neonCyan,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
