import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class ApiService {
  Future<dynamic> getRequest(String url, {Map<String, String>? headers}) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));

      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(408, ApiFailureKind.timeout);
    } on ApiException {
      rethrow;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ApiService] $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      throw const ApiException(0, ApiFailureKind.connection);
    }
  }

  Future<dynamic> postRequest(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));

      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(408, ApiFailureKind.timeout);
    } on ApiException {
      rethrow;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ApiService] $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      throw const ApiException(0, ApiFailureKind.connection);
    }
  }

  dynamic _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        return jsonDecode(response.body);

      case 400:
        throw const ApiException(400, ApiFailureKind.validation);

      case 401:
        throw const ApiException(401, ApiFailureKind.unauthorized);

      case 404:
        throw const ApiException(404, ApiFailureKind.notFound);

      case 500:
        throw const ApiException(500, ApiFailureKind.serverUnavailable);

      default:
        throw ApiException(response.statusCode, ApiFailureKind.unknown);
    }
  }
}
