import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';

/// A tiny sparkline for the KPI cards. Renders either a smoothed line with a
/// soft fill, or a bar series.
class MiniSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final bool isBar;
  const MiniSparkline({
    super.key,
    required this.values,
    required this.color,
    this.isBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(values, color, isBar)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool isBar;
  _SparkPainter(this.values, this.color, this.isBar);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    double y(double v) => size.height - ((v - minV) / range) * size.height;

    if (isBar) {
      final n = values.length;
      final gap = 2.0;
      final bw = (size.width - gap * (n - 1)) / n;
      final paint = Paint()..color = color.withValues(alpha: 0.85);
      for (var i = 0; i < n; i++) {
        final h = size.height - y(values[i]);
        final x = i * (bw + gap);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - h, bw, h),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      return;
    }

    final path = Path();
    final n = values.length;
    for (var i = 0; i < n; i++) {
      final x = n <= 1 ? 0.0 : i / (n - 1) * size.width;
      final py = y(values[i]);
      if (i == 0) {
        path.moveTo(x, py);
      } else {
        path.lineTo(x, py);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.14));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values || old.color != color;
}

/// The dashboard's CPU history chart: a curved usage area + line with a dashed
/// temperature overlay, on a 0–100 scale. Built with fl_chart, matching the
/// design's LineChart styling.
class CpuHistoryChart extends StatelessWidget {
  final Palette p;
  final List<HistPoint> history;
  const CpuHistoryChart({super.key, required this.p, required this.history});

  @override
  Widget build(BuildContext context) {
    final usage = <FlSpot>[];
    final temp = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      usage.add(FlSpot(i.toDouble(), history[i].u.toDouble()));
      temp.add(FlSpot(i.toDouble(), history[i].t.toDouble()));
    }
    final maxX = (history.length - 1).toDouble().clamp(1.0, double.infinity);
    final gridColor = p.border;
    final axisColor = p.textFaint;

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: 100,
          clipData: const FlClipData.all(),
          lineTouchData: const LineTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: gridColor, strokeWidth: 1, dashArray: [3, 4]),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25,
                reservedSize: 30,
                getTitlesWidget: (v, meta) => Text(
                  v.toInt().toString(),
                  style: AppFonts.mono(size: 9, color: axisColor),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // temperature (dashed overlay, drawn first / behind)
            LineChartBarData(
              spots: temp,
              isCurved: true,
              curveSmoothness: 0.25,
              color: p.warning.withValues(alpha: 0.85),
              barWidth: 1.6,
              dashArray: [4, 3],
              dotData: const FlDotData(show: false),
            ),
            // usage (solid line + gradient area)
            LineChartBarData(
              spots: usage,
              isCurved: true,
              curveSmoothness: 0.25,
              color: p.accent,
              barWidth: 2.2,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, bar) => spot.x == maxX,
                getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                  radius: 3.5,
                  color: p.accent,
                  strokeColor: p.surface,
                  strokeWidth: 2,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.accent.withValues(alpha: 0.30), p.accent.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
