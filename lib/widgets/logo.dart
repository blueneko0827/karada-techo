import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// からだ手帖 logo: a pocket notebook (手帖) — blue cover, green spine,
/// gold ribbon bookmark, and a white cover label carrying a red pulse line.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    const r8 = Radius.circular(8);

    final cover = Path()
      ..moveTo(15, 4)
      ..lineTo(34, 4)
      ..arcToPoint(const Offset(42, 12), radius: r8)
      ..lineTo(42, 36)
      ..arcToPoint(const Offset(34, 44), radius: r8)
      ..lineTo(15, 44)
      ..close();
    canvas.drawPath(cover, Paint()..color = Brand.blue);

    final spine = Path()
      ..moveTo(15, 4)
      ..lineTo(15, 44)
      ..lineTo(14, 44)
      ..arcToPoint(const Offset(6, 36), radius: r8)
      ..lineTo(6, 12)
      ..arcToPoint(const Offset(14, 4), radius: r8)
      ..close();
    canvas.drawPath(spine, Paint()..color = Brand.green);

    final stitch = Paint()
      ..color = Brand.paper.withAlpha(115)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (double y = 10; y < 38; y += 4.8) {
      canvas.drawLine(Offset(10.5, y), Offset(10.5, math.min(y + 2.2, 38)), stitch);
    }

    final ribbon = Path()
      ..moveTo(32.5, 2)
      ..lineTo(38.5, 2)
      ..lineTo(38.5, 18.5)
      ..lineTo(35.5, 15.8)
      ..lineTo(32.5, 18.5)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = Brand.gold);

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(18.5, 21, 19.5, 14.5), const Radius.circular(3.5)),
      Paint()..color = Brand.paper,
    );

    final pulse = Path()
      ..moveTo(20.6, 28.4)
      ..lineTo(24, 28.4)
      ..lineTo(26, 24)
      ..lineTo(29, 32.6)
      ..lineTo(31.6, 26.3)
      ..lineTo(33.1, 28.4)
      ..lineTo(35.9, 28.4);
    canvas.drawPath(
      pulse,
      Paint()
        ..color = Brand.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
