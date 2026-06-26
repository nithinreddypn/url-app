import 'supabase_config.dart';

class SettingsRepository {
  final _client = SupabaseConfig.client;

  Future<int> getFreeScanLimit() async {
    try {
      final response = await _client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'free_scan_limit')
          .maybeSingle();

      if (response != null && response['setting_value'] != null) {
        return int.parse(response['setting_value'] as String);
      }
    } catch (_) {}
    return 10; // Default fallback
  }
}
