import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class MicListeningWave extends StatefulWidget {
  final bool isActive;
  const MicListeningWave({super.key, required this.isActive});

  @override
  State<MicListeningWave> createState() => _MicListeningWaveState();
}

class _MicListeningWaveState extends State<MicListeningWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MicListeningWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _WavePainter(_controller.value, widget.isActive),
          child: const SizedBox(height: 60, width: double.infinity),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final bool isActive;

  _WavePainter(this.animationValue, this.isActive);

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;
    final paint = Paint()
      ..color = VaultTheme.neonCyan.withValues(alpha: 0.5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double midY = size.height / 2;
    final double width = size.width;

    // Draw three sine waves out of phase
    for (int wave = 0; wave < 3; wave++) {
      final path = Path();
      final double phase = (wave * pi / 3) + (animationValue * 2 * pi);
      final double amp = 15.0 - (wave * 3);

      path.moveTo(0, midY);
      for (double x = 0; x <= width; x += 3) {
        final double relativeX = x / width;
        // Dampen at the start and end of the canvas
        final double dampening = sin(relativeX * pi);
        final double y = midY + sin(relativeX * 4 * pi + phase) * amp * dampening;
        path.lineTo(x, y);
      }
      
      paint.color = (wave == 0
          ? VaultTheme.neonCyan
          : wave == 1
              ? VaultTheme.electricViolet
              : VaultTheme.hotPink)
          .withValues(alpha: 0.6 - (wave * 0.15));
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isActive != isActive;
  }
}

