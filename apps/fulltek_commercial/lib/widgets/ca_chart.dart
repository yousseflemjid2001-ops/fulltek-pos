import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/commercial_models.dart';
import '../theme/commercial_theme.dart';

class CaComparisonChart extends StatelessWidget {
  final List<DashboardSeriesPoint> series;
  const CaComparisonChart({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Aucune donnée sur la période sélectionnée',
            style: TextStyle(color: CommercialColors.textMuted),
          ),
        ),
      );
    }
    return SizedBox(
      height: 230,
      child: CustomPaint(
        painter: _CaChartPainter(series),
        size: const Size(double.infinity, 230),
      ),
    );
  }
}

class _CaChartPainter extends CustomPainter {
  final List<DashboardSeriesPoint> series;
  _CaChartPainter(this.series);

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 52.0;
    const bottomPad = 26.0;
    const topPad = 12.0;
    const rightPad = 12.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    if (chartW <= 0 || chartH <= 0) return;

    double maxVal = 1000;
    for (final s in series) {
      maxVal = math.max(maxVal, s.periodCaHtMru);
      maxVal = math.max(maxVal, s.prevCaHtMru);
      maxVal = math.max(maxVal, s.targetCaHtMru);
    }
    maxVal *= 1.12;

    final gridPaint = Paint()
      ..color = CommercialColors.border
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 4 horizontal gridlines + Y labels
    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartH - (chartH * i / 4);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
      final val = (maxVal * i / 4);
      final label = val >= 1000
          ? '${(val / 1000).toStringAsFixed(0)}k'
          : val.toStringAsFixed(0);
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(fontSize: 10, color: CommercialColors.textMuted),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPad - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    final slotW = chartW / series.length;
    final barW = math.min(18.0, slotW * 0.30);
    final curPaint = Paint()..color = CommercialColors.primaryBlue;
    final prevPaint = Paint()..color = const Color(0xFFCBD5E1);
    final objPoints = <Offset>[];

    for (int i = 0; i < series.length; i++) {
      final s = series[i];
      final cx = leftPad + slotW * i + slotW / 2;

      final curH = (s.periodCaHtMru / maxVal) * chartH;
      final prevH = (s.prevCaHtMru / maxVal) * chartH;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW - 2, topPad + chartH - curH, barW, curH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        curPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(cx + 2, topPad + chartH - prevH, barW, prevH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        prevPaint,
      );

      final objY = topPad + chartH - (s.targetCaHtMru / maxVal) * chartH;
      objPoints.add(Offset(cx, objY));

      if (series.length <= 12 || i % 2 == 0) {
        textPainter.text = TextSpan(
          text: s.label,
          style: const TextStyle(fontSize: 9.5, color: CommercialColors.textMuted),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(cx - textPainter.width / 2, topPad + chartH + 6),
        );
      }
    }

    // Dashed Objective line + dots
    final objPaint = Paint()
      ..color = CommercialColors.dangerRed
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < objPoints.length - 1; i++) {
      final p1 = objPoints[i];
      final p2 = objPoints[i + 1];
      const dash = 5.0;
      const gap = 4.0;
      final dist = (p2 - p1).distance;
      final dir = (p2 - p1) / (dist == 0 ? 1 : dist);
      double d = 0;
      while (d < dist) {
        final end = math.min(d + dash, dist);
        canvas.drawLine(p1 + dir * d, p1 + dir * end, objPaint);
        d += dash + gap;
      }
    }
    final dotFill = Paint()..color = CommercialColors.dangerRed;
    for (final pt in objPoints) {
      canvas.drawCircle(pt, 3.2, dotFill);
    }
  }

  @override
  bool shouldRepaint(covariant _CaChartPainter oldDelegate) =>
      oldDelegate.series != series;
}
