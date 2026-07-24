import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_defender/models/user_model.dart';
import 'package:url_defender/providers/app_providers.dart';
import 'package:url_defender/services/auth_service.dart';

class _DelayedAuthService extends AuthService {
  final currentUserCompleter = Completer<UserModel>();
  bool signOutCalled = false;

  @override
  Future<UserModel> currentUser() => currentUserCompleter.future;

  @override
  Future<bool> hasStoredSession() async => true;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

class _ProfileAuthService extends AuthService {
  final Queue<Completer<UserModel>> currentUserResponses = Queue();
  UserModel? profileUpdateResponse;
  UserModel? avatarUpdateResponse;
  int currentUserCalls = 0;

  Completer<UserModel> queueCurrentUser() {
    final completer = Completer<UserModel>();
    currentUserResponses.add(completer);
    return completer;
  }

  @override
  Future<UserModel> currentUser() {
    currentUserCalls++;
    return currentUserResponses.removeFirst().future;
  }

  @override
  Future<bool> hasStoredSession() async => true;

  @override
  Future<UserModel> updateProfile({required String fullName}) async =>
      profileUpdateResponse!;

  @override
  Future<UserModel> uploadAvatar(XFile image) async => avatarUpdateResponse!;
}

UserModel _user({
  String username = 'User',
  String? avatarUrl,
  int lifetimeScanCount = 0,
}) => UserModel(
  userId: 'user-1',
  username: username,
  email: 'user@example.com',
  avatarUrl: avatarUrl,
  lifetimeScanCount: lifetimeScanCount,
);

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'logout clears local state and ignores a late profile response',
    () async {
      SharedPreferences.setMockInitialValues({'active_user': 'stale-profile'});
      final authService = _DelayedAuthService();
      final notifier = UserNotifier(authService);

      await notifier.logout();

      expect(notifier.state, isNull);
      expect(authService.signOutCalled, isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('active_user'), isNull);

      authService.currentUserCompleter.complete(
        UserModel(
          userId: 'late-user',
          username: 'Late User',
          email: 'late@example.com',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, isNull);
      expect(preferences.getString('active_user'), isNull);
      notifier.dispose();
    },
  );

  test('profile update is shown immediately and reconciled with /me', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = _ProfileAuthService();
    final initial = authService.queueCurrentUser();
    final canonical = authService.queueCurrentUser();
    final notifier = UserNotifier(authService);

    initial.complete(_user(username: 'Before'));
    await _flushAsyncWork();
    expect(notifier.state?.username, 'Before');

    authService.profileUpdateResponse = _user(username: 'Mutation response');
    final update = notifier.updateProfile(fullName: 'Mutation response');
    await _flushAsyncWork();

    expect(notifier.state?.username, 'Mutation response');
    expect(authService.currentUserCalls, 2);

    canonical.complete(
      _user(username: 'Canonical profile', lifetimeScanCount: 12),
    );
    await update;

    expect(notifier.state?.username, 'Canonical profile');
    expect(notifier.state?.lifetimeScanCount, 12);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('active_user'), contains('Canonical profile'));
    notifier.dispose();
  });

  test('a late refresh cannot overwrite a newer profile update', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = _ProfileAuthService();
    final initial = authService.queueCurrentUser();
    final staleRefresh = authService.queueCurrentUser();
    final canonical = authService.queueCurrentUser();
    final notifier = UserNotifier(authService);

    initial.complete(_user(username: 'Before'));
    await _flushAsyncWork();

    final refresh = notifier.refreshUser();
    authService.profileUpdateResponse = _user(username: 'New profile');
    final update = notifier.updateProfile(fullName: 'New profile');
    await _flushAsyncWork();
    canonical.complete(_user(username: 'Canonical profile'));
    await update;

    staleRefresh.complete(_user(username: 'Stale profile'));
    await refresh;

    expect(notifier.state?.username, 'Canonical profile');
    notifier.dispose();
  });

  test('avatar upload updates and reconciles the avatar URL', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = _ProfileAuthService();
    final initial = authService.queueCurrentUser();
    final canonical = authService.queueCurrentUser();
    final notifier = UserNotifier(authService);

    initial.complete(_user(avatarUrl: 'https://example.com/avatar-old.png'));
    await _flushAsyncWork();
    authService.avatarUpdateResponse = _user(
      avatarUrl: 'https://example.com/avatar-new.png',
    );

    final upload = notifier.uploadAvatar(
      XFile.fromData(Uint8List.fromList(<int>[1, 2, 3]), name: 'avatar.png'),
    );
    await _flushAsyncWork();
    expect(notifier.state?.avatarUrl, endsWith('avatar-new.png'));

    canonical.complete(
      _user(avatarUrl: 'https://example.com/avatar-canonical.png'),
    );
    await upload;
    expect(notifier.state?.avatarUrl, endsWith('avatar-canonical.png'));
    notifier.dispose();
  });
}
