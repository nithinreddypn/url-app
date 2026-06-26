import '../models/plan_model.dart';
import 'supabase_config.dart';

class PlanRepository {
  final _client = SupabaseConfig.client;

  Future<List<PlanModel>> getActivePlans() async {
    final response = await _client
        .from('plans')
        .select()
        .eq('is_active', true)
        .order('price', ascending: true);

    return (response as List)
        .map((json) => PlanModel.fromJson(json))
        .toList();
  }
}
