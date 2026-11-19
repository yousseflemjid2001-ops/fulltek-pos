import 'package:flutter/material.dart';
import '../theme/fulltek_themes.dart';

/// Official Full·Tek Logo — Modèle 11 ("Pilules") exact geometry from
/// Logos_Full-Tek/Modele_11_Pilules/Full-Tek_Resto.svg,
/// Logos_Full-Tek/Modele_11_Pilules/icone_application.svg & logo_anime.svg:
/// 3 decreasing horizontal rounded pills (78%, 52%, 30%) with staggered slide+fade.
class FullTekLogo extends StatefulWidget {
  final double size;
  final String variant;
  final bool showWordmark;
  final bool animate;
  final bool forceDarkBackground;
  final bool asAppIcon;

  const FullTekLogo({
    super.key,
    this.size = 38,
    this.variant = 'Resto',
    this.showWordmark = true,
    this.animate = true,
    this.forceDarkBackground = false,
    this.asAppIcon = false,
  });

  @override
  State<FullTekLogo> createState() => _FullTekLogoState();
}

class _FullTekLogoState extends State<FullTekLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _p1;
  late final Animation<double> _p2;
  late final Animation<double> _p3;
  late final Animation<double> _word;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _p1 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
    );
    _p2 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.68, curve: Curves.easeOutCubic),
    );
    _p3 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.85, curve: Curves.easeOutCubic),
    );
    _word = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    );
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

  (Color, IconData) _resolveVariant(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'resto' => (FullTekBrand.restoOrange, Icons.restaurant_rounded),
      'market' => (FullTekBrand.marketGreen, Icons.storefront_rounded),
      'pharma' => (FullTekBrand.pharmaBlue, Icons.local_pharmacy_rounded),
      'boss' => (FullTekBrand.bossGold, Icons.analytics_rounded),
      _ => (FullTekBrand.ochre, Icons.point_of_sale_rounded),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.forceDarkBackground ||
        Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? Colors.white : FullTekBrand.petrol;
    final (accentColor, variantIcon) = _resolveVariant(widget.variant);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _Modele11PillPainter(
                    ink: inkColor,
                    accent: accentColor,
                    p1: _p1.value,
                    p2: _p2.value,
                    p3: _p3.value,
                    asAppIcon: widget.asAppIcon,
                  ),
                ),
              );
            },
          ),
          if (widget.showWordmark) ...[
            const SizedBox(width: 10),
            FadeTransition(
              opacity: _word,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Full·Tek',
                    style: TextStyle(
                      fontSize: widget.size * 0.46,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: 0.2,
                      color: inkColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        variantIcon,
                        size: widget.size * 0.28,
                        color: accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.variant.toUpperCase(),
                        style: TextStyle(
                          fontSize: widget.size * 0.25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.6,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Modele11PillPainter extends CustomPainter {
  final Color ink;
  final Color accent;
  final double p1;
  final double p2;
  final double p3;
  final bool asAppIcon;

  _Modele11PillPainter({
    required this.ink,
    required this.accent,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.asAppIcon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final pillInk = asAppIcon ? Colors.white : ink;

    if (asAppIcon) {
      final bgPaint = Paint()..color = FullTekBrand.petrol;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(22 * s)),
        bgPaint,
      );
      canvas.save();
      canvas.translate(17 * s, 17 * s);
      canvas.scale(0.66);
    }

    // Exact SVG proportions: x=10, y=18/43/68, widths=78/52/30, height=16, rx=8
    void drawPill(double y, double w, Color color, double progress) {
      final alpha = progress.clamp(0.0, 1.0);
      final slideX = -26 * s * (1 - alpha);
      final paint = Paint()..color = color.withValues(alpha: alpha);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(10 * s + slideX, y * s, w * s, 16 * s),
          Radius.circular(8 * s),
        ),
        paint,
      );
    }

    drawPill(18, 78, pillInk, p1);
    drawPill(43, 52, accent, p2);
    drawPill(68, 30, pillInk, p3);

    if (asAppIcon) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _Modele11PillPainter oldDelegate) {
    return oldDelegate.ink != ink ||
        oldDelegate.accent != accent ||
        oldDelegate.p1 != p1 ||
        oldDelegate.p2 != p2 ||
        oldDelegate.p3 != p3 ||
        oldDelegate.asAppIcon != asAppIcon;
  }
}
