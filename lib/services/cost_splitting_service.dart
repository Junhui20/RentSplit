import '../models/tenant.dart';
import '../models/expense.dart';
import '../models/calculation_result.dart';
import '../models/tenant_calculation.dart';
import '../models/tnb_electricity_bill.dart';
import 'tnb_calculation_service.dart';

/// Cost Splitting Service for Fair Distribution of Expenses
/// 
/// Implements two main calculation methods:
/// 1. Simple Average Method - Equal distribution among all tenants
/// 2. Layered Precise Method - TNB-compliant individual AC cost calculation
class CostSplittingService {
  
  /// Calculate expenses using Simple Average Method
  /// All costs are divided equally among active tenants
  static CalculationResult calculateSimpleAverage({
    required Expense expense,
    required List<Tenant> activeTenants,
    TNBElectricityBill? tnbBill,
  }) {
    if (activeTenants.isEmpty) {
      throw ArgumentError('No active tenants provided for calculation');
    }

    final tenantCount = activeTenants.length;
    final List<TenantCalculation> tenantCalculations = [];

    // Calculate total electricity cost using expense electric price
    final totalElectricityCost = expense.totalKWhUsage * expense.electricPricePerKWh;

    // Calculate per-tenant costs
    final rentPerTenant = expense.baseRent / tenantCount;
    final internetPerTenant = expense.internetFee / tenantCount;
    final waterPerTenant = expense.waterBill / tenantCount;
    final electricityPerTenant = totalElectricityCost / tenantCount;
    final miscPerTenant = expense.splitMiscellaneous 
        ? expense.miscellaneousExpenses / tenantCount 
        : 0.0;

    // Create tenant calculations
    for (final tenant in activeTenants) {
      final tenantCalc = TenantCalculation(
        calculationResultId: 'temp', // Will be updated when CalculationResult is saved
        tenantId: tenant.id,
        tenantName: tenant.name,
        rentShare: rentPerTenant,
        internetShare: internetPerTenant,
        waterShare: waterPerTenant,
        commonElectricityShare: electricityPerTenant,
        individualACCost: 0.0, // In simple average, AC cost is included in common electricity
        miscellaneousShare: miscPerTenant,
        acUsageKWh: tenant.acUsageKWh,
        totalAmount: rentPerTenant + internetPerTenant + waterPerTenant +
                    electricityPerTenant + miscPerTenant,
      );
      tenantCalculations.add(tenantCalc);
    }

    return CalculationResult(
      expenseId: expense.id,
      calculationMethod: CalculationMethod.simpleAverage,
      totalAmount: tenantCalculations.fold(0.0, (sum, calc) => sum + calc.totalAmount),
      activeTenantsCount: tenantCount,
      tenantCalculations: tenantCalculations,
    );
  }

  /// Calculate expenses using Layered Precise Method
  /// Individual AC costs calculated using TNB rates, common area costs shared equally
  static CalculationResult calculateLayeredPrecise({
    required Expense expense,
    required List<Tenant> activeTenants,
    TNBElectricityBill? tnbBill,
  }) {
    if (activeTenants.isEmpty) {
      throw ArgumentError('No active tenants provided for calculation');
    }

    final tenantCount = activeTenants.length;
    final List<TenantCalculation> tenantCalculations = [];

    // Calculate common area electricity cost using expense electric price
    final commonAreaUsage = expense.commonKWhUsage;
    final commonAreaCost = commonAreaUsage * expense.electricPricePerKWh;
    final commonAreaCostPerTenant = commonAreaCost / tenantCount;

    // Calculate shared costs (non-electricity)
    final rentPerTenant = expense.baseRent / tenantCount;
    final internetPerTenant = expense.internetFee / tenantCount;
    final waterPerTenant = expense.waterBill / tenantCount;
    final miscPerTenant = expense.splitMiscellaneous 
        ? expense.miscellaneousExpenses / tenantCount 
        : 0.0;

    // Calculate individual tenant costs
    for (final tenant in activeTenants) {
      // Calculate individual AC electricity cost using expense electric price
      final acElectricityCost = tenant.acUsageKWh * expense.electricPricePerKWh;

      final tenantCalc = TenantCalculation(
        calculationResultId: 'temp', // Will be updated when CalculationResult is saved
        tenantId: tenant.id,
        tenantName: tenant.name,
        rentShare: rentPerTenant,
        internetShare: internetPerTenant,
        waterShare: waterPerTenant,
        commonElectricityShare: commonAreaCostPerTenant,
        individualACCost: acElectricityCost,
        miscellaneousShare: miscPerTenant,
        acUsageKWh: tenant.acUsageKWh,
        totalAmount: rentPerTenant + internetPerTenant + waterPerTenant +
                    acElectricityCost + commonAreaCostPerTenant + miscPerTenant,
      );
      tenantCalculations.add(tenantCalc);
    }

    return CalculationResult(
      expenseId: expense.id,
      calculationMethod: CalculationMethod.layeredPrecise,
      totalAmount: tenantCalculations.fold(0.0, (sum, calc) => sum + calc.totalAmount),
      activeTenantsCount: tenantCount,
      tenantCalculations: tenantCalculations,
    );
  }

  /// Calculate cost difference between methods for comparison
  static Map<String, dynamic> compareCalculationMethods({
    required Expense expense,
    required List<Tenant> activeTenants,
    TNBElectricityBill? tnbBill,
  }) {
    final simpleResult = calculateSimpleAverage(
      expense: expense,
      activeTenants: activeTenants,
      tnbBill: tnbBill,
    );

    final preciseResult = calculateLayeredPrecise(
      expense: expense,
      activeTenants: activeTenants,
      tnbBill: tnbBill,
    );

    final Map<String, Map<String, double>> tenantComparison = {};
    
    for (int i = 0; i < activeTenants.length; i++) {
      final tenant = activeTenants[i];
      final simpleCalc = simpleResult.tenantCalculations[i];
      final preciseCalc = preciseResult.tenantCalculations[i];
      final difference = preciseCalc.totalAmount - simpleCalc.totalAmount;
      
      tenantComparison[tenant.id] = {
        'simple_total': simpleCalc.totalAmount,
        'precise_total': preciseCalc.totalAmount,
        'difference': difference,
        'percentage_change': simpleCalc.totalAmount > 0 
            ? (difference / simpleCalc.totalAmount) * 100 
            : 0.0,
      };
    }

    return {
      'simple_method': {
        'total_amount': simpleResult.totalAmount,
        'method': simpleResult.calculationMethod,
      },
      'precise_method': {
        'total_amount': preciseResult.totalAmount,
        'method': preciseResult.calculationMethod,
      },
      'tenant_comparison': tenantComparison,
      'total_difference': preciseResult.totalAmount - simpleResult.totalAmount,
      'recommendation': _getMethodRecommendation(tenantComparison),
    };
  }

  /// Get recommendation on which method to use based on cost differences
  static String _getMethodRecommendation(Map<String, Map<String, double>> comparison) {
    final differences = comparison.values.map((data) => data['difference']!.abs()).toList();
    final maxDifference = differences.isNotEmpty ? differences.reduce((a, b) => a > b ? a : b) : 0.0;
    final avgDifference = differences.isNotEmpty 
        ? differences.reduce((a, b) => a + b) / differences.length 
        : 0.0;

    if (maxDifference < 5.0) {
      return 'Simple Average recommended - minimal cost differences (max RM ${maxDifference.toStringAsFixed(2)})';
    } else if (avgDifference > 20.0) {
      return 'Layered Precise strongly recommended - significant cost differences (avg RM ${avgDifference.toStringAsFixed(2)})';
    } else {
      return 'Layered Precise recommended for fairness - moderate cost differences (avg RM ${avgDifference.toStringAsFixed(2)})';
    }
  }

  /// Validate calculation results for accuracy
  static bool validateCalculationResult(CalculationResult result, Expense expense) {
    // Check if total matches expected expense total
    final expectedTotal = expense.baseRent + expense.internetFee + expense.waterBill + 
                         (expense.splitMiscellaneous ? expense.miscellaneousExpenses : 0.0);
    
    // Add electricity cost (use TNB calculation)
    final electricityBill = TNBCalculationService.calculateTNBBill(
      expenseId: expense.id,
      totalKWhUsage: expense.totalKWhUsage,
    );
    final expectedTotalWithElectricity = expectedTotal + electricityBill.totalAmount;
    
    // Allow 1% tolerance for rounding differences
    final tolerance = expectedTotalWithElectricity * 0.01;
    final difference = (result.totalAmount - expectedTotalWithElectricity).abs();
    
    return difference <= tolerance;
  }

  /// Get detailed cost breakdown for a specific tenant
  static Map<String, dynamic> getTenantCostBreakdown(TenantCalculation tenantCalc) {
    return {
      'tenant_name': tenantCalc.tenantName,
      'cost_breakdown': {
        'rent': tenantCalc.rentShare,
        'internet': tenantCalc.internetShare,
        'water': tenantCalc.waterShare,
        'common_electricity': tenantCalc.commonElectricityShare,
        'individual_ac_cost': tenantCalc.individualACCost,
        'miscellaneous': tenantCalc.miscellaneousShare,
      },
      'usage_details': {
        'ac_usage_kwh': tenantCalc.acUsageKWh,
        'ac_cost_per_kwh': tenantCalc.acUsageKWh > 0
            ? tenantCalc.individualACCost / tenantCalc.acUsageKWh
            : 0.0,
      },
      'total_amount': tenantCalc.totalAmount,
      'total_electricity_cost': tenantCalc.totalElectricityCost,
    };
  }
}
