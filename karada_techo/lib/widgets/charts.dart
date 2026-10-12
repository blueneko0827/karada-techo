import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/chart_math.dart';
import '../domain/format.dart';
import '../domain/records.dart';
import '../theme/palette.dart';
import 'common.dart';

class ChartSeries {
  const ChartSeries(this.color, this.points);

  final Color color;
  final List<ChartPoint> points;
}

class ChartRef {
  const ChartRef(this.value, this.label, [this.color]);

  final double value;
  final String label;
  final Color? color;
}

void drawChartText(Canvas canvas, String s, Offset at, TextStyle style, {TextAlign align = TextAlign.left}) {
  final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
  var dx = at.dx;
  if (align == TextAlign.right) {
    dx -= tp.width;
  } else if (align == TextAlign.center) {
    dx -= tp.width / 2;
  }
  tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
}

void drawDashed(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 4, double gap = 4}) {
  final total = (b - a).distance;
  if (total == 0) return;
  final dir = (b - a) / total;
  for (double d = 0; d < total; d += dash + gap) {
    canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, total), paint);
  }
}

/// Time-series line chart: grid, reference lines, area fill for a single
/// series, dots, an emphasized last point, and an optional highlight.
class LineChartPainter extends CustomPainter {
  LineChartPainter({
    required this.series,
    required this.refs,
    required this.x0,
    required this.x1,
    required this.pal,
    this.highlight,
  });

  final List<ChartSeries> series;
  final List<ChartRef> refs;
  final DateTime x0;
  final DateTime x1;
  final Palette pal;
  final int? highlight;

  static const double padL = 34, padR = 10, padT = 14, padB = 22;

  double xFor(DateTime t, double w) {
    final span = x1.difference(x0).inMilliseconds;
    if (span <= 0) return padL;
    return padL + t.difference(x0).inMilliseconds / span * (w - padL - padR);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final vals = <double>[
      for (final s in series) for (final p in s.points) p.y,
      for (final r in refs) r.value,
    ];
    if (vals.isEmpty) return;
    var mn = vals.reduce(math.min);
    var mx = vals.reduce(math.max);
    final spread = (mx - mn) * 0.08;
    final pad = spread == 0 ? 1.0 : spread;
    mn -= pad;
    mx += pad;
    final ticks = niceTicks(mn, mx, 4);
    double y(double v) => padT + (ticks.hi - v) / (ticks.hi - ticks.lo) * (h - padT - padB);

    final label = TextStyle(fontSize: 10.5, color: pal.ink3, fontFeatures: const [FontFeature.tabularFigures()]);
    final grid = Paint()
      ..color = pal.line
      ..strokeWidth = 1;
    for (final v in ticks.values) {
      final yy = y(v);
      canvas.drawLine(Offset(padL, yy), Offset(w - padR, yy), grid);
      drawChartText(canvas, ticks.step < 1 ? v.toStringAsFixed(1) : v.round().toString(),
          Offset(padL - 6, yy), label, align: TextAlign.right);
    }

    final nx = w < 360 ? 3 : 4;
    final spanMs = x1.difference(x0).inMilliseconds;
    for (var i = 0; i <= nx; i++) {
      final t = x0.add(Duration(milliseconds: (spanMs * i / nx).round()));
      drawChartText(canvas, fmtMD(t), Offset(xFor(t, w), h - 8), label,
          align: i == 0 ? TextAlign.left : (i == nx ? TextAlign.right : TextAlign.center));
    }

    for (final r in refs) {
      final yy = y(r.value);
      drawDashed(
        canvas,
        Offset(padL, yy),
        Offset(w - padR, yy),
        Paint()
          ..color = (r.color ?? pal.ink3)
          ..strokeWidth = 1.3,
      );
      drawChartText(canvas, r.label, Offset(padL + 4, yy - 9), label.copyWith(color: pal.ink2));
    }

    for (final s in series) {
      if (s.points.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < s.points.length; i++) {
        final p = s.points[i];
        final o = Offset(xFor(p.at, w), y(p.y));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      if (series.length == 1 && s.points.length > 1) {
        final base = y(ticks.lo);
        final area = Path.from(path)
          ..lineTo(xFor(s.points.last.at, w), base)
          ..lineTo(xFor(s.points.first.at, w), base)
          ..close();
        canvas.drawPath(area, Paint()..color = s.color.withAlpha(26));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      if (s.points.length <= 45) {
        final dot = Paint()..color = s.color;
        for (final p in s.points) {
          canvas.drawCircle(Offset(xFor(p.at, w), y(p.y)), 2.2, dot);
        }
      }
      final last = s.points.last;
      final lo = Offset(xFor(last.at, w), y(last.y));
      canvas.drawCircle(lo, 4.5, Paint()..color = pal.surface);
      canvas.drawCircle(
        lo,
        4.5,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    final hi = highlight;
    if (hi != null && series.isNotEmpty && hi < series.first.points.length) {
      final x = xFor(series.first.points[hi].at, w);
      drawDashed(
        canvas,
        Offset(x, padT),
        Offset(x, h - padB),
        Paint()
          ..color = pal.ink3
          ..strokeWidth = 1,
        dash: 3,
        gap: 3,
      );
      for (final s in series) {
        if (hi < s.points.length) {
          final q = s.points[hi];
          canvas.drawCircle(Offset(xFor(q.at, w), y(q.y)), 5, Paint()..color = s.color);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter old) => true;
}

/// Line chart with tap/drag to read individual points.
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.series,
    required this.x0,
    required this.x1,
    this.refs = const [],
    this.height = 210,
    this.readout,
    this.readoutDefault,
  });

  final List<ChartSeries> series;
  final List<ChartRef> refs;
  final DateTime x0;
  final DateTime x1;
  final double height;
  final Widget Function(int index)? readout;
  final Widget? readoutDefault;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _hi;

  @override
  void didUpdateWidget(covariant TrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.series, widget.series)) _hi = null;
  }

  void _pick(double dx, double width) {
    if (widget.series.isEmpty) return;
    final pts = widget.series.first.points;
    if (pts.isEmpty) return;
    final usable = width - LineChartPainter.padL - LineChartPainter.padR;
    final frac = usable <= 0 ? 0.0 : ((dx - LineChartPainter.padL) / usable).clamp(0.0, 1.0);
    final span = widget.x1.difference(widget.x0).inMilliseconds;
    final target = widget.x0.add(Duration(milliseconds: (span * frac).round()));
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final d = (pts[i].at.difference(target).inMilliseconds).abs().toDouble();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    setState(() => _hi = best);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final hasData = widget.series.any((s) => s.points.isNotEmpty);
    final hi = _hi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.readout != null)
          SizedBox(
            height: 30,
            child: hi != null && hasData && hi < widget.series.first.points.length
                ? widget.readout!(hi)
                : (widget.readoutDefault ?? const SizedBox.shrink()),
          ),
        SizedBox(
          height: widget.height,
          child: !hasData
              ? Center(child: Text('この期間の記録はまだありません', style: TextStyle(color: pal.ink3, fontSize: 13.5)))
              : LayoutBuilder(
                  builder: (context, c) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _pick(d.localPosition.dx, c.maxWidth),
                    onHorizontalDragUpdate: (d) => _pick(d.localPosition.dx, c.maxWidth),
                    onHorizontalDragEnd: (_) => setState(() => _hi = null),
                    child: CustomPaint(
                      size: Size(c.maxWidth, widget.height),
                      painter: LineChartPainter(
                        series: widget.series,
                        refs: widget.refs,
                        x0: widget.x0,
                        x1: widget.x1,
                        pal: pal,
                        highlight: _hi,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Small 14-day sparkline for the home cards (fixed height, no LayoutBuilder,
/// so it works inside IntrinsicHeight).
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.points, required this.color, this.height = 34});

  final List<ChartPoint> points;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SparkPainter(points, color)),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.points, this.color);

  final List<ChartPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final vs = points.map((p) => p.y);
    var mn = vs.reduce(math.min);
    var mx = vs.reduce(math.max);
    if (mx - mn < 1e-9) {
      mn -= 1;
      mx += 1;
    }
    final t0 = points.first.at;
    final span = points.last.at.difference(t0).inMilliseconds;
    double x(DateTime t) => 3 + (span <= 0 ? 0 : t.difference(t0).inMilliseconds / span) * (size.width - 9);
    double y(double v) => 4 + (mx - v) / (mx - mn) * (size.height - 8);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (i == 0) {
        path.moveTo(x(p.at), y(p.y));
      } else {
        path.lineTo(x(p.at), y(p.y));
      }
    }
    final area = Path.from(path)
      ..lineTo(x(points.last.at), size.height)
      ..lineTo(x(points.first.at), size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withAlpha(23));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(x(points.last.at), y(points.last.y)), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.points != points || old.color != color;
}

/// Pie of readings per reference category, with a 2px surface gap between slices.
class _PiePainter extends CustomPainter {
  _PiePainter(this.groups, this.pal);

  final List<PieGroup> groups;
  final Palette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final total = groups.fold<int>(0, (s, g) => s + g.n);
    if (total == 0) return;
    final rect = (Offset.zero & size).deflate(2);
    final center = rect.center;
    final nonZero = groups.where((g) => g.n > 0).toList();
    if (nonZero.length == 1) {
      canvas.drawOval(rect, Paint()..color = pal.pie(nonZero.first.level));
      return;
    }
    var start = -math.pi / 2;
    for (final g in nonZero) {
      final sweep = g.n / total * 2 * math.pi;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, start, sweep, false)
        ..close();
      canvas.drawPath(path, Paint()..color = pal.pie(g.level));
      canvas.drawPath(
        path,
        Paint()
          ..color = pal.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => true;
}

/// Pie chart plus a legend with counts and percentages, so identity never
/// depends on colour alone.
class PieBlock extends StatelessWidget {
  const PieBlock({super.key, required this.groups, required this.semanticLabel, this.size = 132});

  final List<PieGroup> groups;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final total = groups.fold<int>(0, (s, g) => s + g.n);
    if (total == 0) return const SizedBox.shrink();
    int pct(PieGroup g) => (g.n / total * 100).round();

    final pie = Semantics(
      label: '$semanticLabel：${groups.where((g) => g.n > 0).map((g) => '${g.label} ${pct(g)}%').join('、')}',
      child: SizedBox(width: size, height: size, child: CustomPaint(painter: _PiePainter(groups, pal))),
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: pal.pie(g.level), borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(g.label, style: TextStyle(fontSize: 13, color: g.n > 0 ? pal.ink : pal.ink3)),
                ),
                Text('${g.n}回', style: numStyle(13, pal.ink3, weight: FontWeight.w400)),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${pct(g)}%',
                    textAlign: TextAlign.right,
                    style: numStyle(16.5, g.n > 0 ? pal.ink : pal.ink3, weight: g.n > 0 ? FontWeight.w700 : FontWeight.w400),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < size + 190) {
          return Column(children: [pie, const SizedBox(height: 12), legend]);
        }
        return Row(children: [pie, const SizedBox(width: 18), Expanded(child: legend)]);
      },
    );
  }
}
