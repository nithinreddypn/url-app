import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_defender/services/api_client.dart';
import 'package:url_defender/services/auth_service.dart';

class _RecordingApiClient extends ApiClient {
  String? path;
  Map<String, dynamic>? body;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Map<String, String>? headers,
  }) async {
    this.path = path;
    this.body = body;
    return {'message': 'Password changed successfully.'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sends both current and new passwords to the protected endpoint',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = _RecordingApiClient();
      final service = AuthService(client: client);

      await service.changePassword(
        currentPassword: 'CurrentSecure2026!',
        newPassword: 'ChangedSecure2026!',
      );

      expect(client.path, 'auth/change-password');
      expect(client.body, {
        'current_password': 'CurrentSecure2026!',
        'new_password': 'ChangedSecure2026!',
      });
    },
  );
}
