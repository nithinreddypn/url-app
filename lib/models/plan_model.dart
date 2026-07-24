import 'api_value_parser.dart';

class PlanModel {
  final String planId;
  final String name;
  final String? description;
  final int durationMonths;
  final double price;
  final String currency;
  final List<String> features;
  final bool isActive;

  PlanModel({
    required this.planId,
    required this.name,
    this.description,
    required this.durationMonths,
    required this.price,
    this.currency = 'INR',
    this.features = const [],
    this.isActive = true,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      planId: apiString(json['plan_id'] ?? json['id']),
      name: apiString(json['name']),
      description: apiNullableString(json['description']),
      durationMonths: apiInt(json['duration_months']),
      price: apiDouble(json['price']),
      currency: apiString(json['currency'], fallback: 'INR'),
      features: apiStringList(json['features']),
      isActive: apiBool(json['is_active'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      'name': name,
      'description': description,
      'duration_months': durationMonths,
      'price': price,
      'currency': currency,
      'features': features,
      'is_active': isActive,
    };
  }
}
