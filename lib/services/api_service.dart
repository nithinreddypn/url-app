import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  Future<dynamic> getRequest(String url,
      {Map<String, String>? headers}) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('GET Request Failed: $e');
    }
  }

  Future<dynamic> postRequest(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('POST Request Failed: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        return jsonDecode(response.body);

      case 400:
        throw Exception('Bad Request');

      case 401:
        throw Exception('Unauthorized');

      case 404:
        throw Exception('Resource Not Found');

      case 500:
        throw Exception('Server Error');

      default:
        throw Exception(
          'Unexpected Error: ${response.statusCode}',
        );
    }
  }
}