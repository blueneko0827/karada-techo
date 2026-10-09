import 'dart:math' as math;

class ChartPoint {
  const ChartPoint(this.at, this.y);

  final DateTime at;
  final double y;
}

class Ticks {
  const Ticks(this.lo, this.hi, this.step, this.values);

  final double lo;
  final double hi;
  final double step;
  final List<double> values;
}

/// "Nice" axis ticks (steps of 1, 2, 5 × 10ⁿ) covering [mn, mx].
Ticks niceTicks(double mn, double mx, int count) {
  if (mx - mn < 1e-9) {
    mn -= 1;
    mx += 1;
  }
  final raw = (mx - mn) / count;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final nm = raw / mag;
  final double step = (nm < 1.5 ? 1.0 : nm < 3 ? 2.0 : nm < 7 ? 5.0 : 10.0) * mag;
  final lo = (mn / step).floorToDouble() * step;
  final hi = (mx / step).ceilToDouble() * step;
  final values = <double>[];
  for (var x = lo; x <= hi + step * 1e-6; x += step) {
    values.add(double.parse(x.toStringAsFixed(6)));
  }
  return Ticks(lo, hi, step, values);
}
