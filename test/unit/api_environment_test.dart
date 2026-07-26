import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_defender/config/api_environment.dart';

void main() {
  group('ApiEnvironment', () {
    test('uses production API for local web development', () {
      expect(
        ApiEnvironment.resolve(
          configuredUrl: '',
          isWeb: true,
          platform: TargetPlatform.windows,
          webOrigin: Uri.parse('http://localhost:8080/#/auth_gate'),
          isRelease: false,
        ),
        'https://moccasin-chicken-542251.hostingersite.com/backend/public/api/v1',
      );
    });

    test('uses Android emulator host alias in debug mode', () {
      expect(
        ApiEnvironment.resolve(
          configuredUrl: '',
          isWeb: false,
          platform: TargetPlatform.android,
          webOrigin: Uri(),
          isRelease: false,
        ),
        'http://10.0.2.2:8123/api/v1',
      );
    });

    test('physical-device LAN override wins and is normalized', () {
      expect(
        ApiEnvironment.resolve(
          configuredUrl: 'http://192.168.1.20:8123/api/v1/',
          isWeb: false,
          platform: TargetPlatform.android,
          webOrigin: Uri(),
          isRelease: false,
        ),
        'http://192.168.1.20:8123/api/v1',
      );
    });

    test('production HTTPS override wins', () {
      expect(
        ApiEnvironment.resolve(
          configuredUrl: 'https://api.example.com/api/v1',
          isWeb: false,
          platform: TargetPlatform.android,
          webOrigin: Uri(),
          isRelease: true,
        ),
        'https://api.example.com/api/v1',
      );
    });

    test('Android release defaults to production endpoint', () {
      expect(
        ApiEnvironment.resolve(
          configuredUrl: '',
          isWeb: false,
          platform: TargetPlatform.android,
          webOrigin: Uri(),
          isRelease: true,
        ),
        'https://moccasin-chicken-542251.hostingersite.com/backend/public/api/v1',
      );
    });
  });
}
