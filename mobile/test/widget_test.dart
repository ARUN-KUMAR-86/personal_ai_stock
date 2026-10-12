import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:personal_ai_stock/main.dart';
import 'package:personal_ai_stock/state/app_state.dart';
import 'package:personal_ai_stock/widgets/signal_pill.dart';

void main() {
  testWidgets('PersonalStockApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
        ],
        child: const PersonalStockApp(),
      ),
    );

    expect(find.byType(PersonalStockApp), findsOneWidget);
  });

  testWidgets('SignalPill renders with valid border without assertion error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SignalPill(
            signalType: 'BUY WATCH',
            strength: 85.0,
          ),
        ),
      ),
    );

    expect(find.text('BUY WATCH'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
  });
}
