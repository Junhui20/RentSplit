import 'package:uuid/uuid.dart';

class TenantCalculation {
  final String id;
  final String calculationResultId;
  final String tenantId;
  final String tenantName;
  final double rentShare;
  final double internetShare;
  final double waterShare;
  final double commonElectricityShare;
  final double individualACCost;
  final double miscellaneousShare;
  final double totalAmount;
  final double acUsageKWh;
  final DateTime createdAt;

  TenantCalculation({
    String? id,
    required this.calculationResultId,
    required this.tenantId,
    required this.tenantName,
    this.rentShare = 0.0,
    this.internetShare = 0.0,
    this.waterShare = 0.0,
    this.commonElectricityShare = 0.0,
    this.individualACCost = 0.0,
    this.miscellaneousShare = 0.0,
    this.totalAmount = 0.0,
    this.acUsageKWh = 0.0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // Get total electricity cost (common + individual AC)
  double get totalElectricityCost {
    return commonElectricityShare + individualACCost;
  }

  // Get total shared expenses (excluding individual AC)
  double get totalSharedExpenses {
    return rentShare + internetShare + waterShare + commonElectricityShare + miscellaneousShare;
  }

  // Get breakdown for display
  Map<String, double> get expenseBreakdown {
    final breakdown = <String, double>{};
    
    if (rentShare > 0) breakdown['Rent Share'] = rentShare;
    if (internetShare > 0) breakdown['Internet Share'] = internetShare;
    if (waterShare > 0) breakdown['Water Share'] = waterShare;
    if (commonElectricityShare > 0) breakdown['Common Electricity'] = commonElectricityShare;
    if (individualACCost > 0) breakdown['AC Usage (${acUsageKWh.toStringAsFixed(1)}kWh)'] = individualACCost;
    if (miscellaneousShare > 0) breakdown['Miscellaneous Share'] = miscellaneousShare;
    
    return breakdown;
  }

  // Check if calculation is valid
  bool get isValid {
    const double tolerance = 0.01; // 1 sen tolerance
    double calculatedTotal = rentShare + internetShare + waterShare + 
                           commonElectricityShare + individualACCost + miscellaneousShare;
    return (totalAmount - calculatedTotal).abs() < tolerance;
  }

  // Create a copy with updated values
  TenantCalculation copyWith({
    String? calculationResultId,
    String? tenantId,
    String? tenantName,
    double? rentShare,
    double? internetShare,
    double? waterShare,
    double? commonElectricityShare,
    double? individualACCost,
    double? miscellaneousShare,
    double? totalAmount,
    double? acUsageKWh,
  }) {
    return TenantCalculation(
      id: id,
      calculationResultId: calculationResultId ?? this.calculationResultId,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      rentShare: rentShare ?? this.rentShare,
      internetShare: internetShare ?? this.internetShare,
      waterShare: waterShare ?? this.waterShare,
      commonElectricityShare: commonElectricityShare ?? this.commonElectricityShare,
      individualACCost: individualACCost ?? this.individualACCost,
      miscellaneousShare: miscellaneousShare ?? this.miscellaneousShare,
      totalAmount: totalAmount ?? this.totalAmount,
      acUsageKWh: acUsageKWh ?? this.acUsageKWh,
      createdAt: createdAt,
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'calculation_result_id': calculationResultId,
      'tenant_id': tenantId,
      'tenant_name': tenantName,
      'rent_share': rentShare,
      'internet_share': internetShare,
      'water_share': waterShare,
      'common_electricity_share': commonElectricityShare,
      'individual_ac_cost': individualACCost,
      'miscellaneous_share': miscellaneousShare,
      'total_amount': totalAmount,
      'ac_usage_kwh': acUsageKWh,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create from Map (database)
  factory TenantCalculation.fromMap(Map<String, dynamic> map) {
    return TenantCalculation(
      id: map['id'] as String,
      calculationResultId: map['calculation_result_id'] as String,
      tenantId: map['tenant_id'] as String,
      tenantName: map['tenant_name'] as String,
      rentShare: (map['rent_share'] as num?)?.toDouble() ?? 0.0,
      internetShare: (map['internet_share'] as num?)?.toDouble() ?? 0.0,
      waterShare: (map['water_share'] as num?)?.toDouble() ?? 0.0,
      commonElectricityShare: (map['common_electricity_share'] as num?)?.toDouble() ?? 0.0,
      individualACCost: (map['individual_ac_cost'] as num?)?.toDouble() ?? 0.0,
      miscellaneousShare: (map['miscellaneous_share'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      acUsageKWh: (map['ac_usage_kwh'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Convert to JSON for API or export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'calculationResultId': calculationResultId,
      'tenantId': tenantId,
      'tenantName': tenantName,
      'rentShare': rentShare,
      'internetShare': internetShare,
      'waterShare': waterShare,
      'commonElectricityShare': commonElectricityShare,
      'individualACCost': individualACCost,
      'miscellaneousShare': miscellaneousShare,
      'totalAmount': totalAmount,
      'acUsageKWh': acUsageKWh,
      'totalElectricityCost': totalElectricityCost,
      'totalSharedExpenses': totalSharedExpenses,
      'expenseBreakdown': expenseBreakdown,
      'isValid': isValid,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'TenantCalculation{tenant: $tenantName, totalAmount: ${totalAmount.toStringAsFixed(2)}RM, acUsage: ${acUsageKWh}kWh}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TenantCalculation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}