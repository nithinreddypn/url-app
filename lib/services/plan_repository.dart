import '../models/plan_model.dart';

class PlanRepository {
  Future<List<PlanModel>> getActivePlans() async {
    return [
      PlanModel(
        planId: 'monthly_plan_id',
        name: 'Premium Monthly',
        price: 9.99,
        durationMonths: 1,
        features: ['Unlimited URL Scans', 'Real-time Alerts', 'Advanced Heuristics', 'Premium Support'],
        isActive: true,
      ),
      PlanModel(
        planId: 'yearly_plan_id',
        name: 'Premium Yearly',
        price: 79.99,
        durationMonths: 12,
        features: ['Unlimited URL Scans', 'Real-time Alerts', 'Advanced Heuristics', '2 Months Free', 'Priority Support'],
        isActive: true,
      ),
    ];
  }
}
