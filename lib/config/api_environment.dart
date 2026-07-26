import 'package:flutter/foundation.dart';

/// Resolves the API origin without treating Android's loopback interface as
/// the development computer.
///
/// An explicit `API_BASE_URL` always wins. This is required for physical
/// devices and production builds, where the backend address cannot be inferred
/// safely from inside the application.
abstract final class ApiEnvironment {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _localApiPort = 8123;
  static const _apiPath = '/api/v1';

  static String get baseUrl => resolve(
    configuredUrl: _configuredBaseUrl,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    webOrigin: Uri.base,
    isRelease: kReleaseMode,
  );

  @visibleForTesting
  static String resolve({
    required String configuredUrl,
    required bool isWeb,
    required TargetPlatform platform,
    required Uri webOrigin,
    required bool isRelease,
  }) {
    final configured = configuredUrl.trim();
    if (configured.isNotEmpty) return _normalize(configured);

    if (isWeb) {
      final host = webOrigin.host;
      final isLocalHost =
          host == 'localhost' || host == '127.0.0.1' || host == '::1';
      if (isLocalHost) {
        return Uri(
          scheme: 'http',
          host: host == '::1' ? '127.0.0.1' : host,
          port: _localApiPort,
          path: _apiPath,
        ).toString();
      }

      // A deployed web frontend defaults to a same-origin API. Deployments
      // using a separate API host must supply API_BASE_URL at build time.
      return webOrigin
          .replace(path: _apiPath, query: null, fragment: null)
          .toString();
    }

    if (platform == TargetPlatform.android) {
      if (isRelease) {
        return 'https://moccasin-chicken-542251.hostingersite.com/backend/public/api/v1';
      }
      // Android Studio's standard emulator maps this address to the host.
      // Physical-device development uses tool/run_android.ps1, which supplies
      // the computer's current LAN address through API_BASE_URL.
      return 'http://10.0.2.2:$_localApiPort$_apiPath';
    }

    if (isRelease) {
      return 'https://moccasin-chicken-542251.hostingersite.com/backend/public/api/v1';
    }

    return 'http://127.0.0.1:$_localApiPort$_apiPath';
  }

  static String _normalize(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw StateError('API_BASE_URL is not a valid HTTP or HTTPS URL.');
    }
    return value.replaceFirst(RegExp(r'/+$'), '');
  }
}
