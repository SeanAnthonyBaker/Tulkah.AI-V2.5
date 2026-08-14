import 'dart:math';
import 'package:flutter/material.dart';

class AudioWaveformWidget extends StatefulWidget {
  final bool isPlaying;
  final double audioLevel; // Live audio amplitude from microphone (0.0 to 1.0)
  final Color activeColor;
  final Color inactiveColor;
  final double height;

  const AudioWaveformWidget({
    Key? key,
    required this.isPlaying,
    this.audioLevel = 0.5,
    this.activeColor = const Color(0xFF6366F1),
    this.inactiveColor = const Color(0xFF334155),
    this.height = 36.0,
  }) : super(key: key);

  @override
  State<AudioWaveformWidget> createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
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
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: WaveformPainter(
            progress: _animationController.value,
            isPlaying: widget.isPlaying,
            audioLevel: widget.audioLevel,
            activeColor: widget.activeColor,
            inactiveColor: widget.inactiveColor,
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final double audioLevel;
  final Color activeColor;
  final Color inactiveColor;

  WaveformPainter({
    required this.progress,
    required this.isPlaying,
    required this.audioLevel,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    const int barCount = 42;
    final double barWidth = (size.width - (barCount * 2.5)) / barCount;
    final double centerY = size.height / 2;

    // Smooth sinusoidal height envelope across bars
    final List<double> baseHeights = [
      0.15, 0.25, 0.45, 0.65, 0.85, 0.95, 0.75, 0.6, 0.8, 1.0, 0.9,
      0.7, 0.5, 0.75, 0.95, 0.85, 0.6, 0.45, 0.65, 0.85, 0.95, 0.8,
      0.65, 0.5, 0.75, 0.9, 0.6, 0.4, 0.65, 0.8, 0.55, 0.35, 0.25,
      0.45, 0.6, 0.35, 0.2, 0.15, 0.1, 0.08, 0.05, 0.05
    ];

    for (int i = 0; i < barCount; i++) {
      double baseH = baseHeights[i % baseHeights.length];

      if (isPlaying) {
        // Factor in live voice audio level from microphone
        double phase = (i * 0.4) + (progress * 2 * pi);
        double animFactor = 0.3 + (0.7 * sin(phase).abs());
        
        // Scale height according to real microphone amplitude input (audioLevel)
        double realVolume = max(0.25, audioLevel * 1.6);
        baseH = baseH * animFactor * realVolume;
      }

      final double currentBarHeight = max(4.0, baseH * size.height * 0.95);
      final double x = i * (barWidth + 2.5);
      final double top = centerY - (currentBarHeight / 2);
      final double bottom = centerY + (currentBarHeight / 2);

      if (isPlaying) {
        paint.shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF38BDF8), // Cyan glow top
            Color(0xFF818CF8), // Indigo core
            Color(0xFFC084FC), // Violet accent bottom
          ],
        ).createShader(Rect.fromLTRB(x, top, x + barWidth, bottom));
      } else {
        paint.shader = null;
        paint.color = inactiveColor;
      }

      final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x, top, x + barWidth, bottom),
        const Radius.circular(4),
      );

      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.audioLevel != audioLevel;
  }
}
