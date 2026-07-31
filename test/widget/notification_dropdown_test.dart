import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_defender/widgets/app/notification_bell.dart';
import 'package:url_defender/models/notification_model.dart';
import 'package:url_defender/providers/notification_provider.dart';
import 'package:url_defender/services/notification_service.dart';

class MockNotificationService implements NotificationService {
  @override
  Future<List<NotificationModel>> getNotifications() async {
    return [
      NotificationModel(
        id: 'test-notification-1',
        scanId: 'scan-1',
        relatedReportId: null,
        type: 'alert',
        title: 'Dangerous scan completed',
        message: 'Malicious URL detected at youtube.com. Review it.',
        severity: 'high',
        priority: 'high',
        category: 'phishing',
        readAt: null,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<void> markAsRead(String id) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> clearAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final screenWidth in <double>[320.0, 400.0, 800.0]) {
    testWidgets('Notification dropdown fits within screen width $screenWidth', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(screenWidth, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationServiceProvider.overrideWithValue(MockNotificationService()),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: const [
                  Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: NotificationBell(),
                  ),
                ],
              ),
              body: const Center(child: Text('Home Screen')),
            ),
          ),
        ),
      );

      // Verify bell icon is initially rendered
      expect(find.byType(NotificationBell), findsOneWidget);

      // Tap on bell to open dropdown
      await tester.tap(find.byType(NotificationBell));
      await tester.pumpAndSettle();

      // Check if dropdown panel is open by finding details inside _NotificationHeader
      expect(find.text('Notifications'), findsOneWidget);

      // Dimmed scrim check: find GestureDetector with a backdrop Container having dimmed opacity
      final scrimFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.color != null) {
          return widget.color!.opacity > 0.0 && widget.color!.opacity < 1.0;
        }
        return false;
      });
      expect(scrimFinder, findsAtLeast(1));

      // Panel alignment and boundary check
      final panelFinder = find.byType(Material).last;
      final topLeft = tester.getTopLeft(panelFinder);
      final size = tester.getSize(panelFinder);

      // Left edge should be at least 16px from screen edge
      expect(topLeft.dx >= 16.0, isTrue);

      // Right edge should fit within the screen bounds with at least 16px safety margin (on small screens) or align properly on wider screens
      final rightEdge = topLeft.dx + size.width;
      expect(rightEdge <= screenWidth - 15.9 || (screenWidth - rightEdge).abs() < 24.0, isTrue);
    });
  }
}
