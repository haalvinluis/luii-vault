import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class ImmersivePlayer extends StatefulWidget {
  final double leftFreq;
  final double rightFreq;
  final bool isPlaying;

  const ImmersivePlayer({
    super.key,
    required this.leftFreq,
    required this.rightFreq,
    required this.isPlaying,
  });

  @override
  State<ImmersivePlayer> createState() => _ImmersivePlayerState();
}

class _ImmersivePlayerState extends State<ImmersivePlayer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    if (widget.isPlaying) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ImmersivePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_animationController.isAnimating) {
      _animationController.repeat();
    } else if (!widget.isPlaying && _animationController.isAnimating) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: _BinauralWavePainter(
              leftFreq: widget.leftFreq,
              rightFreq: widget.rightFreq,
              isPlaying: widget.isPlaying,
              phase: _animationController.value * 2 * pi,
            ),
            child: Container(),
          ),
        );
      },
    );
  }
}

class _BinauralWavePainter extends CustomPainter {
  final double leftFreq;
  final double rightFreq;
  final bool isPlaying;
  final double phase;

  _BinauralWavePainter({
    required this.leftFreq,
    required this.rightFreq,
    required this.isPlaying,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;
    final int pointsCount = size.width.toInt();

    final leftPath = Path();
    final rightPath = Path();
    final interferencePath = Path();

    // Frequency factors scaled for display (e.g. 100Hz-500Hz fits nicely if scaled down)
    final double leftScale = (leftFreq / 150.0).clamp(1.0, 3.5);
    final double rightScale = (rightFreq / 150.0).clamp(1.0, 3.5);
    final double beatIntensity = (rightFreq - leftFreq).abs(); // Beat frequency

    for (int x = 0; x < pointsCount; x++) {
      final double normalizedX = (x / pointsCount) * 4 * pi;
      
      // Left channel sine wave
      final double yLeft = sin(normalizedX * leftScale + (isPlaying ? phase * 4 : 0)) * 25;
      
      // Right channel sine wave
      final double yRight = sin(normalizedX * rightScale + (isPlaying ? phase * 4.1 : 0)) * 25;

      // Combined binaural wave showing beats
      // Amplitude envelopes show maximum construction/destruction nodes
      final double envelope = cos(normalizedX * (rightScale - leftScale) * 0.5 + (isPlaying ? phase * 0.5 : 0));
      final double yInterference = sin(normalizedX * ((leftScale + rightScale) * 0.5) + (isPlaying ? phase * 4.05 : 0)) * 35 * envelope;

      if (x == 0) {
        leftPath.moveTo(x.toDouble(), cy + yLeft);
        rightPath.moveTo(x.toDouble(), cy + yRight);
        interferencePath.moveTo(x.toDouble(), cy + yInterference);
      } else {
        leftPath.lineTo(x.toDouble(), cy + yLeft);
        rightPath.lineTo(x.toDouble(), cy + yRight);
        interferencePath.lineTo(x.toDouble(), cy + yInterference);
      }
    }

    // Paint Left Channel (Cyan)
    final leftPaint = Paint()
      ..color = VaultTheme.neonCyan.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(leftPath, leftPaint);

    // Paint Right Channel (Violet)
    final rightPaint = Paint()
      ..color = VaultTheme.electricViolet.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(rightPath, rightPaint);

    // Paint Superposition Interference Wave (Hot Pink/White)
    final interferencePaint = Paint()
      ..color = VaultTheme.hotPink
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1);
    canvas.drawPath(interferencePath, interferencePaint);

    // Render beat nodes text overlay
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: "BEAT DRIFT: ${beatIntensity.toStringAsFixed(1)} Hz",
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(16, 16));
  }

  @override
  bool shouldRepaint(covariant _BinauralWavePainter oldDelegate) {
    return oldDelegate.leftFreq != leftFreq ||
        oldDelegate.rightFreq != rightFreq ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.phase != phase;
  }
}
