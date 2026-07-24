import 'api_client.dart';
import '../models/api_value_parser.dart';

class ScanLimitService {
  ScanLimitService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<int> getWeeklyScansCount(String userId) async {
    final usage = await _client.get('usage');
    return apiInt(usage['scans_used']);
  }

  Future<bool> canUserScan(String userId) async {
    final usage = await _client.get('usage');
    final remaining = usage['scans_remaining'];
    return remaining == null || apiInt(remaining) > 0;
  }

  Future<int> getRemainingScans(String userId) async {
    final usage = await _client.get('usage');
    final remaining = usage['scans_remaining'];
    return apiInt(remaining);
  }
}
