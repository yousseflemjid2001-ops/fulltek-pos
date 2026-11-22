import 'package:flutter/material.dart';
import '../theme/commercial_theme.dart';

/// Official Full·Tek Modèle 11 « 3 Pilules » emblem in Royal Violet (#7C3AED).
class FullTekCommercialMark extends StatelessWidget {
  final double size;
  final bool darkBg;

  const FullTekCommercialMark({
    super.key,
    this.size = 42,
    this.darkBg = true,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = darkBg ? Colors.white : CommercialColors.sidebarBg;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.2),
      decoration: BoxDecoration(
        color: darkBg ? CommercialColors.sidebarBg : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: CommercialColors.brandViolet.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FractionallySizedBox(
            widthFactor: 1.0,
            child: Container(
              height: size * 0.145,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          FractionallySizedBox(
            widthFactor: 0.68,
            child: Container(
              height: size * 0.145,
              decoration: BoxDecoration(
                color: CommercialColors.brandViolet,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          FractionallySizedBox(
            widthFactor: 0.40,
            child: Container(
              height: size * 0.145,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
