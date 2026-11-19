import 'package:flutter/material.dart';
import '../theme/fulltek_themes.dart';

/// Official Full-Tek Logo — Modèle 11 ("Pilules") with subtle Slide entrance
class FullTekLogo extends StatefulWidget {
  final double size;
  final String variant;
  final bool showWordmark;
  final bool animate;

  const FullTekLogo({
    super.key,
    this.size = 38,
    this.variant = 'Resto',
    this.showWordmark = true,
    this.animate = true,
  });

  @override
  State<FullTekLogo> createState() => _FullTekLogoState();
}

class _FullTekLogoState extends State<FullTekLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _slide = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = FullTekThemes.paletteOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _slide,
          builder: (context, _) {
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _PillLogoPainter(
                  primary: p.primary,
                  accent: p.accent,
                  progress: _slide.value,
                ),
              ),
            );
          },
        ),
        if (widget.showWordmark) ...[
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FULL-TEK',
                    style: TextStyle(
                      fontSize: widget.size * 0.42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: p.primary.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      widget.variant.toUpperCase(),
                      style: TextStyle(
                        fontSize: widget.size * 0.24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: p.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PillLogoPainter extends CustomPainter {
  final Color primary;
  final Color accent;
  final double progress;

  _PillLogoPainter({
    required this.primary,
    required this.accent,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height * 0.14;
    final h = size.height * 0.24;
    final dx = (1 - progress) * size.width * 0.25;

    final p1 = Paint()..color = primary;
    final p2 = Paint()..color = accent;
    final p3 = Paint()..color = primary.withValues(alpha: 0.72);

    // Top pill (full width)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, size.height * 0.08, size.width * 0.94, h),
        Radius.circular(r),
      ),
      p1,
    );
    // Middle pill (shifted)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.06 - dx * 0.6, size.height * 0.39, size.width * 0.74, h),
        Radius.circular(r),
      ),
      p2,
    );
    // Bottom short pill + status dot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(dx * 0.5, size.height * 0.70, size.width * 0.48, h),
        Radius.circular(r),
      ),
      p3,
    );
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.82),
      h * 0.46,
      p2,
    );
  }

  @override
  bool shouldRepaint(covariant _PillLogoPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.accent != accent ||
        oldDelegate.progress != progress;
  }
}
