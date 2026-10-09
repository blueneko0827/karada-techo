/// Date and number formatting in the Japanese conventions the app uses.
library;

const List<String> _weekday = ['月', '火', '水', '木', '金', '土', '日'];

String pad2(int n) => n.toString().padLeft(2, '0');
String weekdayJp(DateTime d) => _weekday[d.weekday - 1];
String fmtMD(DateTime d) => '${d.month}/${d.day}';
String fmtJP(DateTime d) => '${d.month}月${d.day}日（${weekdayJp(d)}）';
String fmtYMD(DateTime d) => '${d.year}/${d.month}/${d.day}';
String fmtTime(DateTime d) => '${pad2(d.hour)}:${pad2(d.minute)}';
String dayKey(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Midnight [n] days before today (0 = today).
DateTime daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - n);
}

String fmtNum(double v, int decimals) =>
    decimals == 0 ? v.round().toString() : v.toStringAsFixed(decimals);

String fmtDelta(double x, int decimals, [String unit = '']) {
  final sign = x > 0 ? '+' : (x < 0 ? '−' : '±');
  return '$sign${x.abs().toStringAsFixed(decimals)}$unit';
}

double? mean(Iterable<num> xs) {
  if (xs.isEmpty) return null;
  var sum = 0.0;
  var n = 0;
  for (final x in xs) {
    sum += x;
    n++;
  }
  return sum / n;
}

T? firstWhereOr<T>(Iterable<T> xs, bool Function(T) test) {
  for (final x in xs) {
    if (test(x)) return x;
  }
  return null;
}

/// Converts full-width digits and punctuation from Japanese keyboards to ASCII.
String normalizeNum(String s) {
  final b = StringBuffer();
  for (final c in s.runes) {
    if (c >= 0xFF10 && c <= 0xFF19) {
      b.writeCharCode(c - 0xFF10 + 0x30);
    } else if (c == 0xFF0E || c == 0x3002) {
      b.write('.');
    } else if (c == 0xFF0C || c == 0x002C) {
      b.write('.');
    } else {
      b.writeCharCode(c);
    }
  }
  return b.toString().trim();
}
