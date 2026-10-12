import 'package:flutter/material.dart';

import '../domain/classify.dart';
import '../models/metric.dart';

/// Four-hue system: blue = the app itself, green = in range,
/// gold = goals & mild caution, red = blood pressure & alerts.
class Brand {
  static const blue = Color(0xFF1F4E8C);
  static const green = Color(0xFF2E8A5C);
  static const red = Color(0xFFC8373F);
  static const gold = Color(0xFFD9AA3E);
  static const paper = Color(0xFFFFFDF6);
}

@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.paper,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.gold,
    required this.goldInk,
    required this.goldSoft,
    required this.ok,
    required this.okSoft,
    required this.note,
    required this.noteSoft,
    required this.warn,
    required this.warnSoft,
    required this.alert,
    required this.alertSoft,
    required this.pieOk,
    required this.pieNote,
    required this.pieWarn,
    required this.pieAlert,
    required this.mBp,
    required this.mWeight,
    required this.mHr,
    required this.mTemp,
    required this.mGlucose,
    required this.mFat,
  });

  final Color paper, surface, surface2, ink, ink2, ink3, line;
  final Color accent, accentInk, accentSoft;
  final Color gold, goldInk, goldSoft;
  final Color ok, okSoft, note, noteSoft, warn, warnSoft, alert, alertSoft;
  final Color pieOk, pieNote, pieWarn, pieAlert;
  final Color mBp, mWeight, mHr, mTemp, mGlucose, mFat;

  static const light = Palette(
    paper: Color(0xFFF1F5F2),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE6EDE8),
    ink: Color(0xFF13201A),
    ink2: Color(0xFF43554B),
    ink3: Color(0xFF6A7C72),
    line: Color(0xFFD1DCD5),
    accent: Color(0xFF1F4E8C),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFDFE8F4),
    gold: Color(0xFFC49A32),
    goldInk: Color(0xFF8A6417),
    goldSoft: Color(0xFFF6EDD6),
    ok: Color(0xFF1E7A4D),
    okSoft: Color(0xFFDCEFE3),
    note: Color(0xFF2F5E9E),
    noteSoft: Color(0xFFE0E8F4),
    warn: Color(0xFF8A6417),
    warnSoft: Color(0xFFF6EDD6),
    alert: Color(0xFFB8323F),
    alertSoft: Color(0xFFF8DFE0),
    pieOk: Color(0xFF1C8853),
    pieNote: Color(0xFF2F5E9E),
    pieWarn: Color(0xFFB3862A),
    pieAlert: Color(0xFFB8323F),
    mBp: Color(0xFFB8323F),
    mWeight: Color(0xFF1F4E8C),
    mHr: Color(0xFF8E2F52),
    mTemp: Color(0xFFB3862A),
    mGlucose: Color(0xFF1C8853),
    mFat: Color(0xFF4A86B8),
  );

  static const dark = Palette(
    paper: Color(0xFF0D1512),
    surface: Color(0xFF15201B),
    surface2: Color(0xFF1D2A24),
    ink: Color(0xFFE3ECE7),
    ink2: Color(0xFFA5B6AD),
    ink3: Color(0xFF7A8B82),
    line: Color(0xFF28362F),
    accent: Color(0xFF8DB0E3),
    accentInk: Color(0xFF0D1512),
    accentSoft: Color(0xFF1C2A3E),
    gold: Color(0xFFE0B656),
    goldInk: Color(0xFFE0B656),
    goldSoft: Color(0xFF352B14),
    ok: Color(0xFF6CC795),
    okSoft: Color(0xFF16301F),
    note: Color(0xFF8DB0E3),
    noteSoft: Color(0xFF1C2A3E),
    warn: Color(0xFFE0B656),
    warnSoft: Color(0xFF352B14),
    alert: Color(0xFFF08288),
    alertSoft: Color(0xFF3A1D20),
    pieOk: Color(0xFF3A9E6C),
    pieNote: Color(0xFF5E8BD6),
    pieWarn: Color(0xFFB98C2B),
    pieAlert: Color(0xFFDC5560),
    mBp: Color(0xFFF08288),
    mWeight: Color(0xFF8DB0E3),
    mHr: Color(0xFFE39AB6),
    mTemp: Color(0xFFE0B656),
    mGlucose: Color(0xFF6CC795),
    mFat: Color(0xFF86BFE6),
  );

  Color metric(MetricType t) => switch (t) {
        MetricType.bp => mBp,
        MetricType.weight => mWeight,
        MetricType.hr => mHr,
        MetricType.temp => mTemp,
        MetricType.glucose => mGlucose,
        MetricType.fat => mFat,
      };

  Color level(Level l) => switch (l) {
        Level.ok => ok,
        Level.note => note,
        Level.warn => warn,
        Level.alert => alert,
        Level.plain => ink2,
      };

  Color levelSoft(Level l) => switch (l) {
        Level.ok => okSoft,
        Level.note => noteSoft,
        Level.warn => warnSoft,
        Level.alert => alertSoft,
        Level.plain => surface2,
      };

  Color pie(Level l) => switch (l) {
        Level.ok => pieOk,
        Level.note => pieNote,
        Level.warn => pieWarn,
        Level.alert => pieAlert,
        Level.plain => ink3,
      };

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) =>
      (other is Palette && t >= 0.5) ? other : this;
}

extension PaletteContext on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.light ? Palette.light : Palette.dark;
  final scheme = ColorScheme.fromSeed(seedColor: Brand.blue, brightness: brightness).copyWith(
    primary: p.accent,
    onPrimary: p.accentInk,
    primaryContainer: p.accentSoft,
    secondary: p.ok,
    tertiary: p.gold,
    error: p.alert,
    surface: p.surface,
    onSurface: p.ink,
    onSurfaceVariant: p.ink2,
    outline: p.line,
    outlineVariant: p.line,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.paper,
    dividerColor: p.line,
    extensions: <ThemeExtension<dynamic>>[p],
  );
}
