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
    var rawFeatures = json['features'];
    List<String> featuresList = [];
    if (rawFeatures is List) {
      featuresList = List<String>.from(rawFeatures);
    }

    return PlanModel(
      planId: json['plan_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      durationMonths: json['duration_months'] as int? ?? 0,
      price: (json['price'] as num? ?? 0).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      features: featuresList,
      isActive: json['is_active'] as bool? ?? true,
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
