import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Simple UI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('URL Defender'),
        ),
      ),
    );

    expect(find.text('URL Defender'), findsOneWidget);
  });
}

