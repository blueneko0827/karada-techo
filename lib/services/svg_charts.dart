/// SVG strings for the PDF report (rendered by pw.SvgImage).
/// Uses the light palette with literal colours, since PDFs are printed.
library;

import 'dart:math' as math;

import '../domain/chart_math.dart';
import '../domain/classify.dart';
import '../domain/format.dart';
import '../domain/records.dart';

const Map<Level, String> pdfPieColors = {
  Level.ok: '#1C8853',
  Level.note: '#2F5E9E',
  Level.warn: '#B3862A',
  Level.alert: '#B8323F',
  Level.plain: '#6A7C72',
};

String logoSvg() => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M15 4H34A8 8 0 0 1 42 12V36A8 8 0 0 1 34 44H15Z" fill="#1F4E8C"/>'
    '<path d="M15 4V44H14A8 8 0 0 1 6 36V12A8 8 0 0 1 14 4Z" fill="#2E8A5C"/>'
    '<path d="M32.5 2H38.5V18.5L35.5 15.8L32.5 18.5Z" fill="#D9AA3E"/>'
    '<rect x="18.5" y="21" width="19.5" height="14.5" rx="3.5" ry="3.5" fill="#FFFDF6"/>'
    '<polyline points="20.6,28.4 24,28.4 26,24 29,32.6 31.6,26.3 33.1,28.4 35.9,28.4" '
    'fill="none" stroke="#C8373F" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

String _f(double v) => v.toStringAsFixed(2);

String pieSvg(List<PieGroup> groups, double size) {
  final total = groups.fold<int>(0, (s, g) => s + g.n);
  final b = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_f(size)} ${_f(size)}">');
  if (total == 0) return '$b</svg>';
  final c = size / 2;
  final r = size / 2 - 2;
  final nonZero = groups.where((g) => g.n > 0).toList();
  if (nonZero.length == 1) {
    b.write('<circle cx="${_f(c)}" cy="${_f(c)}" r="${_f(r)}" fill="${pdfPieColors[nonZero.first.level]}"/>');
  } else {
    var a = -math.pi / 2;
    for (final g in nonZero) {
      final sweep = g.n / total * 2 * math.pi;
      final a2 = a + sweep;
      final x1 = c + r * math.cos(a), y1 = c + r * math.sin(a);
      final x2 = c + r * math.cos(a2), y2 = c + r * math.sin(a2);
      final large = sweep > math.pi ? 1 : 0;
      b.write('<path d="M${_f(c)} ${_f(c)} L${_f(x1)} ${_f(y1)} A${_f(r)} ${_f(r)} 0 $large 1 ${_f(x2)} ${_f(y2)} Z" '
          'fill="${pdfPieColors[g.level]}" stroke="#FFFFFF" stroke-width="2" stroke-linejoin="round"/>');
      a = a2;
    }
  }
  b.write('</svg>');
  return b.toString();
}

class SvgSeries {
  const SvgSeries(this.color, this.points);

  final String color;
  final List<ChartPoint> points;
}

class SvgRef {
  const SvgRef(this.value, this.label);

  final double value;
  final String label;
}

String lineSvg({
  required List<SvgSeries> series,
  List<SvgRef> refs = const [],
  required DateTime x0,
  required DateTime x1,
  double w = 515,
  double h = 170,
}) {
  const l = 34.0, r = 10.0, t = 12.0, bt = 20.0;
  final vals = <double>[
    for (final s in series) for (final p in s.points) p.y,
    for (final ref in refs) ref.value,
  ];
  final b = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_f(w)} ${_f(h)}">');
  if (vals.isEmpty) return '$b</svg>';
  var mn = vals.reduce((a, c) => a < c ? a : c);
  var mx = vals.reduce((a, c) => a > c ? a : c);
  final pad = (mx - mn) * 0.08 == 0 ? 1.0 : (mx - mn) * 0.08;
  mn -= pad;
  mx += pad;
  final ticks = niceTicks(mn, mx, 4);
  final span = x1.difference(x0).inMilliseconds.toDouble();
  double xf(DateTime d) => l + (span <= 0 ? 0 : d.difference(x0).inMilliseconds / span) * (w - l - r);
  double yf(double v) => t + (ticks.hi - v) / (ticks.hi - ticks.lo) * (h - t - bt);

  for (final v in ticks.values) {
    final y = yf(v);
    b.write('<line x1="${_f(l)}" x2="${_f(w - r)}" y1="${_f(y)}" y2="${_f(y)}" stroke="#D1DCD5" stroke-width="0.8"/>');
    b.write('<text x="${_f(l - 5)}" y="${_f(y + 3)}" font-size="8" fill="#6A7C72" text-anchor="end">'
        '${ticks.step < 1 ? v.toStringAsFixed(1) : v.round()}</text>');
  }
  for (var i = 0; i <= 4; i++) {
    final d = x0.add(Duration(milliseconds: (span * i / 4).round()));
    final anchor = i == 0 ? 'start' : (i == 4 ? 'end' : 'middle');
    b.write('<text x="${_f(xf(d))}" y="${_f(h - 4)}" font-size="8" fill="#6A7C72" text-anchor="$anchor">${fmtMD(d)}</text>');
  }
  for (final ref in refs) {
    final y = yf(ref.value);
    b.write('<line x1="${_f(l)}" x2="${_f(w - r)}" y1="${_f(y)}" y2="${_f(y)}" stroke="#6A7C72" stroke-width="1" stroke-dasharray="4 3"/>');
    b.write('<text x="${_f(l + 4)}" y="${_f(y - 3)}" font-size="8" fill="#43554B">${ref.label}</text>');
  }
  for (final s in series) {
    if (s.points.isEmpty) continue;
    final d = StringBuffer();
    for (var i = 0; i < s.points.length; i++) {
      final p = s.points[i];
      d.write('${i == 0 ? 'M' : 'L'}${_f(xf(p.at))} ${_f(yf(p.y))} ');
    }
    b.write('<path d="${d.toString().trim()}" fill="none" stroke="${s.color}" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"/>');
    final last = s.points.last;
    b.write('<circle cx="${_f(xf(last.at))}" cy="${_f(yf(last.y))}" r="3" fill="#FFFFFF" stroke="${s.color}" stroke-width="1.8"/>');
  }
  b.write('</svg>');
  return b.toString();
}
