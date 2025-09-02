import 'package:uuid/uuid.dart';
import 'tenant_calculation.dart';

enum CalculationMethod {
  simpleAverage,
  layeredPrecise,
}

extension CalculationMethodExtension on CalculationMethod {
  String get displayName {
    switch (this) {
      case CalculationMethod.simpleAverage:
        return 'Simple Average Method';
      case CalculationMethod.layeredPrecise:
        return 'Layered Precise Method';
    }
  }

  String get description {
    switch (this) {
      case CalculationMethod.simpleAverage:
        return 'Easy understanding and similar usage patterns';
      case CalculationMethod.layeredPrecise:
        return 'Maximum fairness and TNB-compliant calculations';
    }
  }

  String get value {
    switch (this) {
      case CalculationMethod.simpleAverage:
        return 'simple_average';
      case CalculationMethod.layeredPrecise:
        return 'layered_precise';
    }
  }

  static CalculationMethod fromValue(String value) {
    switch (value) {
      case 'simple_average':
        return CalculationMethod.simpleAverage;
      case 'layered_precise':
        return CalculationMethod.layeredPrecise;
      default:
        return CalculationMethod.simpleAverage;
    }
  }
}

class CalculationResult {
  final String id;
  final String expenseId;
  final CalculationMethod calculationMethod;
  final double totalAmount;
  final int activeTenantsCount;
  final DateTime createdAt;
  final List<TenantCalculation> tenantCalculations;

  CalculationResult({
    String? id,
    required this.expenseId,
    required this.calculationMethod,
    required this.totalAmount,
    required this.activeTenantsCount,
    DateTime? createdAt,
    this.tenantCalculations = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // Get total amount for verification
  double get calculatedTotal {
    return tenantCalculations.fold(0.0, (sum, calc) => sum + calc.totalAmount);
  }

  // Get average amount per tenant
  double get averageAmountPerTenant {
    return activeTenantsCount > 0 ? totalAmount / activeTenantsCount : 0.0;
  }

  // Check if calculations are balanced
  bool get isBalanced {
    const double tolerance = 0.01; // 1 sen tolerance
    return (totalAmount - calculatedTotal).abs() < tolerance;
  }

  // Get tenant calculation by tenant ID
  TenantCalculation? getTenantCalculation(String tenantId) {
    try {
      return tenantCalculations.firstWhere((calc) => calc.tenantId == tenantId);
    } catch (e) {
      return null;
    }
  }

  // Create a copy with updated values
  CalculationResult copyWith({
    String? expenseId,
    CalculationMethod? calculationMethod,
    double? totalAmount,
    int? activeTenantsCount,
    List<TenantCalculation>? tenantCalculations,
  }) {
    return CalculationResult(
      id: id,
      expenseId: expenseId ?? this.expenseId,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      totalAmount: totalAmount ?? this.totalAmount,
      activeTenantsCount: activeTenantsCount ?? this.activeTenantsCount,
      createdAt: createdAt,
      tenantCalculations: tenantCalculations ?? this.tenantCalculations,
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_id': expenseId,
      'calculation_method': calculationMethod.value,
      'total_amount': totalAmount,
      'active_tenants_count': activeTenantsCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create from Map (database)
  factory CalculationResult.fromMap(Map<String, dynamic> map) {
    return CalculationResult(
      id: map['id'] as String,
      expenseId: map['expense_id'] as String,
      calculationMethod: CalculationMethodExtension.fromValue(map['calculation_method'] as String),
      totalAmount: (map['total_amount'] as num).toDouble(),
      activeTenantsCount: map['active_tenants_count'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Convert to JSON for API or export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expenseId': expenseId,
      'calculationMethod': calculationMethod.value,
      'calculationMethodDisplayName': calculationMethod.displayName,
      'totalAmount': totalAmount,
      'activeTenantsCount': activeTenantsCount,
      'averageAmountPerTenant': averageAmountPerTenant,
      'isBalanced': isBalanced,
      'createdAt': createdAt.toIso8601String(),
      'tenantCalculations': tenantCalculations.map((calc) => calc.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'CalculationResult{id: $id, method: ${calculationMethod.displayName}, '
           'totalAmount: ${totalAmount.toStringAsFixed(2)}RM, tenants: $activeTenantsCount}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalculationResult && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}