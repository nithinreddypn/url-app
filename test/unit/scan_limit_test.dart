import 'package:flutter_test/flutter_test.dart';
import 'package:url_defender/models/user_model.dart';
import 'package:url_defender/services/user_service.dart';
import 'package:url_defender/services/scan_limit_service.dart';

class MockUserService implements UserService {
  UserModel? mockUser;

  @override
  Future<UserModel?> getUser(String userId) async {
    return mockUser;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestableScanLimitService extends ScanLimitService {
  int mockWeeklyScans = 0;

  TestableScanLimitService({super.userService});

  @override
  Future<int> getWeeklyScansCount(String userId) async {
    return mockWeeklyScans;
  }
}

void main() {
  group('ScanLimitService Tests (15 Initial + 1 Weekly Limit)', () {
    late MockUserService mockUserService;
    late TestableScanLimitService scanLimitService;

    setUp(() {
      mockUserService = MockUserService();
      scanLimitService = TestableScanLimitService(
        userService: mockUserService,
      );
    });

    test('Free user with 5 lifetime scans gets remaining initial scans', () async {
      mockUserService.mockUser = UserModel(
        userId: 'user1',
        username: 'Alice',
        email: 'alice@example.com',
        isPremium: false,
        lifetimeScanCount: 5,
      );
      scanLimitService.mockWeeklyScans = 0;

      final canScan = await scanLimitService.canUserScan('user1');
      expect(canScan, true);

      final remaining = await scanLimitService.getRemainingScans('user1');
      expect(remaining, 10); // 15 - 5
    });

    test('Free user with 14 lifetime scans has 1 remaining initial scan', () async {
      mockUserService.mockUser = UserModel(
        userId: 'user2',
        username: 'Bob',
        email: 'bob@example.com',
        isPremium: false,
        lifetimeScanCount: 14,
      );
      scanLimitService.mockWeeklyScans = 0;

      final canScan = await scanLimitService.canUserScan('user2');
      expect(canScan, true);

      final remaining = await scanLimitService.getRemainingScans('user2');
      expect(remaining, 1); // 15 - 14
    });

    test('Free user with 15 lifetime scans transitions to weekly limit and has 1 scan if 0 done this week', () async {
      mockUserService.mockUser = UserModel(
        userId: 'user3',
        username: 'Charlie',
        email: 'charlie@example.com',
        isPremium: false,
        lifetimeScanCount: 15,
      );
      scanLimitService.mockWeeklyScans = 0;

      final canScan = await scanLimitService.canUserScan('user3');
      expect(canScan, true);

      final remaining = await scanLimitService.getRemainingScans('user3');
      expect(remaining, 1); // 1 weekly scan remaining
    });

    test('Free user with 15 lifetime scans who scanned this week is blocked', () async {
      mockUserService.mockUser = UserModel(
        userId: 'user4',
        username: 'David',
        email: 'david@example.com',
        isPremium: false,
        lifetimeScanCount: 15,
      );
      scanLimitService.mockWeeklyScans = 1;

      final canScan = await scanLimitService.canUserScan('user4');
      expect(canScan, false);

      final remaining = await scanLimitService.getRemainingScans('user4');
      expect(remaining, 0); // 0 weekly scans remaining
    });

    test('Premium user is never blocked', () async {
      mockUserService.mockUser = UserModel(
        userId: 'user5',
        username: 'Eve',
        email: 'eve@example.com',
        isPremium: true,
        lifetimeScanCount: 50,
      );
      scanLimitService.mockWeeklyScans = 10;

      final canScan = await scanLimitService.canUserScan('user5');
      expect(canScan, true);

      final remaining = await scanLimitService.getRemainingScans('user5');
      expect(remaining, -1); // Unlimited
    });
  });
}
