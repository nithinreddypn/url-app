import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/api_environment.dart';

enum ApiFailureKind {
  connection,
  timeout,
  invalidCredentials,
  accountNotFound,
  accountDisabled,
  emailVerificationRequired,
  verificationCodeInvalid,
  conflict,
  rateLimited,
  validation,
  unauthorized,
  serverUnavailable,
  notFound,
  invalidResponse,
  unknown,
}

class ApiException implements Exception {
  final int statusCode;
  final ApiFailureKind kind;
  final String? safeMessage;

  const ApiException(this.statusCode, this.kind, {this.safeMessage});

  @override
  String toString() => 'ApiException(status: $statusCode, kind: $kind)';
}

/// The API URL is supplied at build time; no provider secrets belong in Flutter.
class ApiClient {
  static String get baseUrl => ApiEnvironment.baseUrl;
  static const _tokenKey = 'api_session_token';
  static const _debugScansKey = 'debug_test_scans';
  static const _requestTimeout = Duration(seconds: 20);
  static const _maxAvatarBytes = 1024 * 1024;

  static String? userAgentOverride;

  static Future<void> initUserAgent() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;

      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer;
        final model = androidInfo.model;
        final release = androidInfo.version.release;
        userAgentOverride = 'URLDefender/$appVersion+$buildNumber (Mobile; $manufacturer $model; Android $release)';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final name = iosInfo.name;
        final systemVersion = iosInfo.systemVersion;
        userAgentOverride = 'URLDefender/$appVersion+$buildNumber (Mobile; $name; iOS $systemVersion)';
      }
    } catch (_) {
      userAgentOverride = 'URLDefender/Mobile';
    }
  }

  /// Converts managed avatar values from older deployments into the active
  /// backend origin. External/data/icon avatars are left unchanged.
  static String? resolveAssetUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final raw = value.trim();
    final parsed = Uri.tryParse(raw);
    final path = parsed?.path ?? raw;
    if (!RegExp(
      r'^/uploads/avatars/[a-zA-Z0-9-]+\.(?:jpe?g|png|webp)$',
      caseSensitive: false,
    ).hasMatch(path)) {
      return raw;
    }
    final apiUri = Uri.parse(baseUrl);
    return apiUri.replace(path: path, query: null, fragment: null).toString();
  }

  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) =>
      _request('GET', path, authenticated: authenticated);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool authenticated = true,
  }) => _request('POST', path, body: body, headers: headers, authenticated: authenticated);

  /// Uses a caller-owned client so an in-flight lookup can be cancelled by
  /// closing that client when the input changes.
  Future<Map<String, dynamic>> postWithClient(
    http.Client client,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _request(
    'POST',
    path,
    body: body,
    authenticated: authenticated,
    client: client,
  );

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _request('PATCH', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> delete(String path) =>
      _request('DELETE', path, authenticated: true);

  Future<Map<String, dynamic>> uploadAvatar(XFile image) async {
    final sessionToken = await token();
    if (sessionToken == null || sessionToken.isEmpty) {
      throw const ApiException(401, ApiFailureKind.unauthorized);
    }
    final imageBytes = await image.readAsBytes();
    if (imageBytes.isEmpty || imageBytes.lengthInBytes > _maxAvatarBytes) {
      throw const ApiException(
        422,
        ApiFailureKind.validation,
        safeMessage: 'Profile image must be 1 MB or smaller.',
      );
    }
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}/me/avatar'),
          )
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $sessionToken';
    if (userAgentOverride != null) {
      request.headers['User-Agent'] = userAgentOverride!;
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: image.name,
      ),
    );
    try {
      final streamed = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(_requestTimeout);
      return _parseResponse(response);
    } on TimeoutException {
      throw const ApiException(408, ApiFailureKind.timeout);
    } on http.ClientException catch (error) {
      _debugLog(error);
      throw const ApiException(0, ApiFailureKind.connection);
    } on FormatException catch (error, stackTrace) {
      _debugLog(error, stackTrace);
      throw const ApiException(502, ApiFailureKind.invalidResponse);
    }
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<String?> token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required bool authenticated,
    http.Client? client,
  }) async {
    final reqHeaders = <String, String>{'Accept': 'application/json'};
    if (userAgentOverride != null) {
      reqHeaders['User-Agent'] = userAgentOverride!;
    }
    if (body != null) reqHeaders['Content-Type'] = 'application/json';
    if (headers != null) reqHeaders.addAll(headers);
    if (authenticated) {
      final sessionToken = await token();
      if (sessionToken == null || sessionToken.isEmpty) {
        throw const ApiException(401, ApiFailureKind.unauthorized);
      }
      reqHeaders['Authorization'] = 'Bearer $sessionToken';
      if (kDebugMode && sessionToken.startsWith('debug-test-session-')) {
        return _debugTestRequest(method, path, body);
      }
    }

    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}/$path');
    final http.Response response;
    try {
      response = await (switch (method) {
        'GET' =>
          client?.get(uri, headers: reqHeaders) ?? http.get(uri, headers: reqHeaders),
        'POST' =>
          client?.post(
                uri,
                headers: reqHeaders,
                body: body == null ? null : jsonEncode(body),
              ) ??
              http.post(
                uri,
                headers: reqHeaders,
                body: body == null ? null : jsonEncode(body),
              ),
        'PATCH' =>
          client?.patch(
                uri,
                headers: reqHeaders,
                body: body == null ? null : jsonEncode(body),
              ) ??
              http.patch(
                uri,
                headers: reqHeaders,
                body: body == null ? null : jsonEncode(body),
              ),
        'DELETE' =>
          client?.delete(uri, headers: reqHeaders) ??
              http.delete(uri, headers: reqHeaders),
        _ => throw ArgumentError.value(method, 'method'),
      }).timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(408, ApiFailureKind.timeout);
    } on http.ClientException catch (error) {
      _debugLog(error);
      throw const ApiException(0, ApiFailureKind.connection);
    }
    try {
      return _parseResponse(response);
    } on FormatException catch (error, stackTrace) {
      _debugLog(error, stackTrace);
      throw const ApiException(502, ApiFailureKind.invalidResponse);
    }
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    Map<String, dynamic> payload = const {};
    if (response.body.trim().isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Expected a JSON object response.');
      }
      payload = Map<String, dynamic>.from(decoded);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (kDebugMode) {
        debugPrint(
          '[ApiClient] HTTP ${response.statusCode}; response body hidden from UI: ${response.body}',
        );
      }
      throw _safeApiException(response.statusCode, payload);
    }
    if (payload['success'] == false) {
      throw const ApiException(502, ApiFailureKind.invalidResponse);
    }
    final data = payload['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List) return {'items': data};
    return payload;
  }

  ApiException _safeApiException(int statusCode, Map<String, dynamic> payload) {
    final String rawMessage = (payload['message'] ?? payload['error'] ?? '').toString();
    final String serverMessage = rawMessage.toLowerCase();
    if (statusCode == 401) {
      return const ApiException(401, ApiFailureKind.invalidCredentials);
    }
    if (statusCode == 403 && serverMessage.contains('disabled')) {
      return ApiException(403, ApiFailureKind.accountDisabled, safeMessage: rawMessage);
    }
    if (statusCode == 403 && serverMessage.contains('verif')) {
      return ApiException(403, ApiFailureKind.emailVerificationRequired, safeMessage: rawMessage);
    }
    if (statusCode == 404 &&
        (serverMessage.contains('account') || serverMessage.contains('user'))) {
      return const ApiException(404, ApiFailureKind.accountNotFound);
    }
    if (statusCode == 404) {
      return const ApiException(404, ApiFailureKind.notFound);
    }
    if (statusCode == 408 || statusCode == 504) {
      return const ApiException(408, ApiFailureKind.timeout);
    }
    if (statusCode == 409) {
      return const ApiException(409, ApiFailureKind.conflict);
    }
    if (statusCode == 400 && serverMessage.contains('verification code')) {
      return const ApiException(400, ApiFailureKind.verificationCodeInvalid);
    }
    if (statusCode == 422) {
      return ApiException(
        422,
        ApiFailureKind.validation,
        safeMessage: _allowedValidationMessage(serverMessage),
      );
    }
    if (statusCode == 429) {
      return ApiException(429, ApiFailureKind.rateLimited, safeMessage: rawMessage);
    }
    if (statusCode >= 500) {
      return ApiException(statusCode, ApiFailureKind.serverUnavailable, safeMessage: rawMessage);
    }
    if (statusCode == 401 || statusCode == 403) {
      return ApiException(statusCode, ApiFailureKind.unauthorized, safeMessage: rawMessage);
    }
    return ApiException(statusCode, ApiFailureKind.unknown, safeMessage: rawMessage);
  }

  String? _allowedValidationMessage(String message) {
    if (message.contains('current password is incorrect')) {
      return 'Current password is incorrect.';
    }
    if (message.contains('current password is required')) {
      return 'Enter your current password.';
    }
    if (message.contains('different from the current password')) {
      return 'Choose a new password that is different from your current password.';
    }
    if (message.contains('valid email')) return 'Enter a valid email address.';
    if (message.contains('password')) {
      return 'Please check your password and try again.';
    }
    if (message.contains('full_name') || message.contains('display name')) {
      return 'Please enter a valid name.';
    }
    if (message.contains('valid url')) return 'Enter a valid URL.';
    if (message.contains('profile image') || message.contains('image')) {
      return 'Profile image must be 1 MB or smaller.';
    }
    return null;
  }

  void _debugLog(Object error, [StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint('[ApiClient] $error');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }

  Future<Map<String, dynamic>> _debugTestRequest(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final uri = Uri.parse('/$path');
    final route = uri.path.replaceFirst(RegExp(r'^/'), '');
    final scans = await _debugScans();

    if (method == 'GET' && route == 'usage') {
      return {
        'scans_used': scans.length,
        'scans_remaining': (50 - scans.length).clamp(0, 50),
        'scan_limit': 50,
      };
    }
    if (method == 'GET' && route == 'plans') {
      return {
        'items': [
          {'id': 'team', 'amount_paise': 49900, 'currency': 'INR'},
          {'id': 'enterprise', 'amount_paise': 149900, 'currency': 'INR'},
        ],
      };
    }
    if (method == 'GET' && route == 'payments') {
      return {'items': <Map<String, dynamic>>[]};
    }
    if (method == 'GET' && route == 'notifications') {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('debug_test_notifications');
      if (encoded == null) {
        final initial = [
          {
            'id': 'notif-1',
            'scan_id': null,
            'type': 'threat',
            'title': 'Phishing URL detected',
            'message': 'A malicious phishing link was scanned and blocked by URL Defender.',
            'severity': 'high',
            'read_at': null,
            'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toUtc().toIso8601String(),
          },
          {
            'id': 'notif-2',
            'scan_id': null,
            'type': 'system',
            'title': 'System upgrade completed',
            'message': 'URL Defender system databases have been updated to v2.4.0 successfully.',
            'severity': 'info',
            'read_at': null,
            'created_at': DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
          },
          {
            'id': 'notif-3',
            'scan_id': null,
            'type': 'digest',
            'title': 'Weekly security report',
            'message': 'Your weekly overview of scanned URLs and detected threats is ready.',
            'severity': 'info',
            'read_at': null,
            'created_at': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
          },
        ];
        await prefs.setString('debug_test_notifications', jsonEncode(initial));
        return {'items': initial};
      }
      return {'items': jsonDecode(encoded)};
    }
    if (method == 'GET' && route == 'me') {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('debug_test_session_user');
      final user = encoded == null ? null : jsonDecode(encoded);
      return {'user': user};
    }
    if (method == 'POST' && route == 'scans') {
      final value = (body?['url'] ?? '').toString();
      final now = DateTime.now().toUtc().toIso8601String();
      final scan = <String, dynamic>{
        'id': 'debug-scan-${DateTime.now().microsecondsSinceEpoch}',
        'url': value,
        'hostname': Uri.tryParse(value)?.host ?? value,
        'verdict': 'safe',
        'risk_score': 0,
        'threat_category': null,
        'created_at': now,
        'scanned_at': now,
        'result': {'blacklist_listed': 0, 'blacklist_total': 0},
      };
      scans.insert(0, scan);
      await _saveDebugScans(scans);
      return scan;
    }
    if (method == 'POST' && route == 'url/lookup') {
      final requested = (body?['url'] ?? '').toString().trim().toLowerCase();
      final key = requested
          .replaceFirst(RegExp(r'^https?://'), '')
          .replaceFirst(RegExp(r'/$'), '');
      Map<String, dynamic>? match;
      for (final scan in scans) {
        final scanKey = (scan['url'] ?? '')
            .toString()
            .trim()
            .toLowerCase()
            .replaceFirst(RegExp(r'^https?://'), '')
            .replaceFirst(RegExp(r'/$'), '');
        if (scanKey == key && scan['verdict'] != 'pending') {
          match = scan;
          break;
        }
      }
      if (match == null) return {'success': true, 'exists': false};
      return {
        'success': true,
        'exists': true,
        'source': 'database',
        'already_in_history': true,
        'last_scanned': match['scanned_at'] ?? match['created_at'],
        'scan_id': match['id'],
        'analysis': {
          'url': key,
          'status': match['verdict'],
          'risk_score': match['risk_score'] ?? 0,
          'category': match['threat_category'] ?? match['verdict'],
          'threat_type': match['threat_category'],
          'ssl_status': 'none',
          'redirect_count': 0,
          'source': 'URL Defender Threat Intelligence',
        },
      };
    }
    if (route.startsWith('notifications/')) {
      final id = route.split('/')[1];
      final action = route.split('/').length > 2 ? route.split('/')[2] : '';
      if (method == 'PATCH' && action == 'read') {
        final prefs = await SharedPreferences.getInstance();
        final encoded = prefs.getString('debug_test_notifications');
        if (encoded != null) {
          final items = List<Map<String, dynamic>>.from(jsonDecode(encoded));
          final idx = items.indexWhere((item) => item['id'] == id);
          if (idx >= 0) {
            items[idx] = {
              ...items[idx],
              'read_at': DateTime.now().toUtc().toIso8601String(),
            };
            await prefs.setString('debug_test_notifications', jsonEncode(items));
          }
        }
        return {'message': 'Notification marked as read.'};
      }
    }
    if (method == 'POST' && route == 'notifications/read-all') {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('debug_test_notifications');
      if (encoded != null) {
        final items = List<Map<String, dynamic>>.from(jsonDecode(encoded));
        for (var i = 0; i < items.length; i++) {
          if (items[i]['read_at'] == null) {
            items[i] = {
              ...items[i],
              'read_at': DateTime.now().toUtc().toIso8601String(),
            };
          }
        }
        await prefs.setString('debug_test_notifications', jsonEncode(items));
      }
      return {'message': 'All notifications marked as read.'};
    }
    if (method == 'DELETE' && route == 'notifications') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('debug_test_notifications', jsonEncode([]));
      return {'message': 'All notifications cleared.'};
    }
    if (route.startsWith('scans/')) {
      final id = route.substring('scans/'.length);
      final index = scans.indexWhere((scan) => scan['id'] == id);
      if (method == 'GET') {
        if (index < 0) {
          throw const ApiException(404, ApiFailureKind.notFound);
        }
        return {'scan': scans[index]};
      }
      if (method == 'DELETE') {
        if (index >= 0) scans.removeAt(index);
        await _saveDebugScans(scans);
        return {'message': 'Scan removed.'};
      }
    }
    if (method == 'GET' && route == 'scans') {
      var items = List<Map<String, dynamic>>.from(scans);
      final verdict = uri.queryParameters['verdict'];
      if (verdict != null && verdict.isNotEmpty) {
        items = items.where((scan) => scan['verdict'] == verdict).toList();
      }
      final limit = int.tryParse(uri.queryParameters['limit'] ?? '') ?? 100;
      return {'items': items.take(limit.clamp(1, 100).toInt()).toList()};
    }
    if (route.startsWith('payments/')) {
      throw const ApiException(503, ApiFailureKind.serverUnavailable);
    }
    throw const ApiException(404, ApiFailureKind.notFound);
  }

  Future<List<Map<String, dynamic>>> _debugScans() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_debugScansKey);
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on FormatException {
      await prefs.remove(_debugScansKey);
      return [];
    }
  }

  Future<void> _saveDebugScans(List<Map<String, dynamic>> scans) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_debugScansKey, jsonEncode(scans));
  }
}
