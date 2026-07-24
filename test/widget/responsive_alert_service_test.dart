import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_defender/services/alert_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in <Size>[
    const Size(320, 568),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('alert fits ${size.width.toInt()}px viewport', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: const SizedBox(height: 90),
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => AlertService.showAlert(
                    context,
                    type: AlertType.warning,
                    title: 'Suspicious URL flagged',
                    description:
                        'Review this scan before opening the destination.',
                  ),
                  child: const Text('Show alert'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show alert'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Suspicious URL flagged'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    });
  }
}
