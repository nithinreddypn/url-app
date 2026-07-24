import '../models/plan_model.dart';
import '../models/api_value_parser.dart';
import 'api_client.dart';

class PlanRepository {
  PlanRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<PlanModel>> getActivePlans() async {
    final payload = await _client.get('plans');
    final items = payload['items'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((item) {
      final json = Map<String, dynamic>.from(item);
      final id = apiString(json['id']);
      final isEnterprise = id == 'enterprise';
      return PlanModel(
        planId: id,
        name: isEnterprise ? 'Enterprise' : 'Team',
        description: isEnterprise
            ? 'Organisation-wide link protection'
            : 'Enhanced protection for your team',
        durationMonths: 1,
        price: apiInt(json['amount_paise']) / 100,
        currency: apiString(json['currency'], fallback: 'INR'),
        features: isEnterprise
            ? const [
                'Unlimited URL scans',
                'Priority support',
                'Advanced reporting',
              ]
            : const [
                'Unlimited URL scans',
                'Real-time alerts',
                'Advanced heuristics',
              ],
      );
    }).toList();
  }
}
