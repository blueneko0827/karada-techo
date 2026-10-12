import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karada_techo/domain/classify.dart';
import 'package:karada_techo/domain/records.dart';
import 'package:karada_techo/theme/palette.dart';
import 'package:karada_techo/widgets/charts.dart';
import 'package:karada_techo/widgets/logo.dart';

void main() {
  testWidgets('logo and pie chart render', (tester) async {
    final groups = [PieGroup(Level.ok, '正常血圧')..n = 3, PieGroup(Level.warn, '高値血圧')..n = 5];
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: Column(
          children: [
            const AppLogo(size: 48),
            PieBlock(groups: groups, semanticLabel: 'テスト'),
          ],
        ),
      ),
    ));
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('63%'), findsOneWidget);
    expect(find.text('38%'), findsOneWidget);
  });
}
