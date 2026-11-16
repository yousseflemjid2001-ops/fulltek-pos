import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class FTColors {
  static const Color bg = Color(0xFF081115);
  static const Color night = Color(0xFF0F1B20);
  static const Color night2 = Color(0xFF14252C);
  static const Color night3 = Color(0xFF1B323C);
  static const Color petrol = Color(0xFF264653);
  static const Color ochre = Color(0xFFE9A23B);
  static const Color boss = Color(0xFFC99A2E);
  static const Color resto = Color(0xFFE4572E);
  static const Color market = Color(0xFF2E9E5B);
  static const Color pharma = Color(0xFF1B8FD9);
  static const Color greenOk = Color(0xFF4ADE80);
  static const Color warn = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color ink = Color(0xFFF4F7F8);
  static const Color ink2 = Color(0xFFCFE0E6);
  static const Color muted = Color(0xFF93ABB5);
}

class AppTheme {
  static ThemeData darkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: FTColors.petrol,
      brightness: Brightness.dark,
      primary: FTColors.ochre,
      onPrimary: const Color(0xFF101916),
      secondary: FTColors.market,
      tertiary: FTColors.pharma,
      surface: FTColors.night,
      onSurface: FTColors.ink,
      error: FTColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: FTColors.bg,
      cardColor: FTColors.night2,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF17342D),
        contentTextStyle: const TextStyle(
          color: Color(0xFFECFDF5),
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: FTColors.greenOk, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xEA0C171C),
        indicatorColor: FTColors.ochre.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? FTColors.ochre : FTColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? FTColors.ochre : FTColors.muted,
          );
        }),
      ),
    );
  }
}

/// Official Modèle 11 « Pilules » Logo Widget with animated slide-in pills.
class FullTekPillsLogo extends StatelessWidget {
  final double size;
  final Color accent;
  final double progress;

  const FullTekPillsLogo({
    super.key,
    this.size = 40,
    this.accent = FTColors.ochre,
    this.progress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PillsPainter(accent: accent, progress: progress),
      ),
    );
  }
}

class _PillsPainter extends CustomPainter {
  final Color accent;
  final double progress;

  _PillsPainter({required this.accent, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Curves.easeOutCubic.transform((progress * 1.4).clamp(0.0, 1.0));
    final p2 = Curves.easeOutCubic.transform(((progress - 0.15) * 1.4).clamp(0.0, 1.0));
    final p3 = Curves.easeOutCubic.transform(((progress - 0.30) * 1.4).clamp(0.0, 1.0));

    final h = size.height * 0.15;
    final r = Radius.circular(h / 2);
    final x0 = size.width * 0.14;

    final whitePaint = Paint()..color = Colors.white;
    final accentPaint = Paint()
      ..color = accent
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);

    if (p1 > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x0, size.height * 0.20, size.width * 0.72 * p1, h),
          r,
        ),
        whitePaint,
      );
    }
    if (p2 > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x0, size.height * 0.43, size.width * 0.48 * p2, h),
          r,
        ),
        accentPaint,
      );
    }
    if (p3 > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x0, size.height * 0.66, size.width * 0.28 * p3, h),
          r,
        ),
        whitePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PillsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

/// Circular Gauge Ring Painter for VPS / Cloud Telemetry.
class GaugeRing extends StatelessWidget {
  final double percent;
  final Color color;
  final String valueText;
  final String label;

  const GaugeRing({
    super.key,
    required this.percent,
    required this.color,
    required this.valueText,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) => SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(
                painter: _RingPainter(percent: val, color: color),
                child: Center(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      valueText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: FTColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final Color color;

  _RingPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 7) / 2;
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5;
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.5;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percent.clamp(0.0, 1.0),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.color != color;
}

/// Frosted Glass Card Container.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.09),
            ),
            gradient: gradient ??
                const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xCC1A3039), Color(0xEB0F1B20)],
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}
