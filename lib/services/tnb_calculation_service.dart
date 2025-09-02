import '../models/tenant.dart';
import '../models/expense.dart';
import '../models/tnb_electricity_bill.dart';
import '../models/calculation_result.dart';
import '../models/tenant_calculation.dart';
import '../models/malaysian_currency.dart';
import '../models/property.dart';
import '../models/rental_unit.dart';

/// TNB Calculation Service for Malaysian Electricity Billing
///
/// Implements the official TNB tariff structure effective July 2024:
/// - Energy Charge: RM 0.2703/kWh (≤1500kWh), RM 0.3703/kWh (>1500kWh)
/// - Capacity Charge: RM 0.0455/kWh
/// - Network Charge: RM 0.1285/kWh
/// - Retail Charge: RM 10/month (waived if ≤600kWh)
/// - KWTBB Tax: 1.6% (exempted if ≤300kWh)
/// - SST Tax: 8% (only on usage >600kWh)
class TNBCalculationService {
  // TNB Tariff Rates (Domestic Tariff A - effective July 2024)
  static const double energyRateTier1 = 0.2703; // RM/kWh for ≤1500kWh
  static const double energyRateTier2 = 0.3703; // RM/kWh for >1500kWh
  static const double energyTier1Threshold = 1500.0; // kWh

  static const double capacityRate = 0.0455; // RM/kWh
  static const double networkRate = 0.1285; // RM/kWh
  static const double retailChargeAmount = 10.0; // RM/month
  static const double retailChargeWaiverThreshold = 600.0; // kWh

  // Tax Rates
  static const double kwtbbTaxRate = 0.016; // 1.6%
  static const double kwtbbExemptionThreshold = 300.0; // kWh
  static const double sstTaxRate = 0.08; // 8%
  static const double sstThreshold = 600.0; // kWh

  // Energy Efficiency Incentive Rate (≤1000 kWh eligible)
  // Based on real TNB bills: fixed rate of -RM 0.060/kWh
  static const double eeIncentiveRate = -0.060; // RM/kWh

  /// Calculate complete TNB electricity bill breakdown
  static TNBElectricityBill calculateTNBBill({
    required String expenseId,
    required double totalKWhUsage,
    double? providedTotalAmount,
  }) {
    // Calculate individual components
    final energyCharge = _calculateEnergyCharge(totalKWhUsage);
    final capacityCharge = _calculateCapacityCharge(totalKWhUsage);
    final networkCharge = _calculateNetworkCharge(totalKWhUsage);
    final retailCharge = _calculateRetailCharge(totalKWhUsage);
    final eeIncentive = _calculateEEIncentive(totalKWhUsage);

    // Calculate subtotal before taxes
    final subtotal = energyCharge + capacityCharge + networkCharge + retailCharge + eeIncentive;

    // Calculate taxes
    final kwtbbTax = _calculateKWTBBTax(subtotal, totalKWhUsage);
    final sstTax = _calculateSSTTax(subtotal, totalKWhUsage);

    // Calculate final total
    final calculatedTotal = subtotal + kwtbbTax + sstTax;

    // Use provided total if available, otherwise use calculated
    final finalTotal = providedTotalAmount ?? calculatedTotal;

    return TNBElectricityBill(
      expenseId: expenseId,
      totalKWhUsage: totalKWhUsage,
      energyCharge: energyCharge,
      capacityCharge: capacityCharge,
      networkCharge: networkCharge,
      retailCharge: retailCharge,
      eeIncentive: eeIncentive,
      kwtbbTax: kwtbbTax,
      sstTax: sstTax,
      totalAmount: finalTotal,
    );
  }

  /// Calculate Energy Charge with tiered pricing
  static double _calculateEnergyCharge(double kWhUsage) {
    if (kWhUsage <= energyTier1Threshold) {
      return kWhUsage * energyRateTier1;
    } else {
      const tier1Amount = energyTier1Threshold * energyRateTier1;
      final tier2Usage = kWhUsage - energyTier1Threshold;
      final tier2Amount = tier2Usage * energyRateTier2;
      return tier1Amount + tier2Amount;
    }
  }

  /// Calculate Capacity Charge (infrastructure maintenance)
  static double _calculateCapacityCharge(double kWhUsage) {
    return kWhUsage * capacityRate;
  }

  /// Calculate Network Charge (grid maintenance and transmission)
  static double _calculateNetworkCharge(double kWhUsage) {
    return kWhUsage * networkRate;
  }

  /// Calculate Retail Charge (waived if ≤600kWh)
  static double _calculateRetailCharge(double kWhUsage) {
    return kWhUsage <= retailChargeWaiverThreshold ? 0.0 : retailChargeAmount;
  }

  /// Calculate Energy Efficiency Incentive (discounts for low usage ≤1000kWh)
  static double _calculateEEIncentive(double kWhUsage) {
    // No incentive if usage exceeds 1000 kWh
    if (kWhUsage > 1000.0) {
      return 0.0;
    }

    // Based on real TNB bills, EE Incentive is a fixed rate of -RM 0.055/kWh
    // for usage ≤1000 kWh (as seen in actual TNB bills)
    return kWhUsage * eeIncentiveRate;
  }

  /// Calculate KWTBB Tax (1.6%, exempted if ≤300kWh)
  static double _calculateKWTBBTax(double subtotal, double kWhUsage) {
    if (kWhUsage <= kwtbbExemptionThreshold) {
      return 0.0;
    }
    return subtotal * kwtbbTaxRate;
  }

  /// Calculate SST Tax (8%, only on usage >600kWh portion)
  static double _calculateSSTTax(double subtotal, double kWhUsage) {
    if (kWhUsage <= sstThreshold) {
      return 0.0;
    }

    // SST only applies to the electricity charges for usage above 600kWh
    double sstTaxableUsage = kWhUsage - sstThreshold;

    // Calculate the electricity charges for the taxable portion
    double sstTaxableAmount = sstTaxableUsage * (energyRateTier1 + capacityRate + networkRate);

    return sstTaxableAmount * sstTaxRate;
  }
  // Calculate rent split using specified method
  static CalculationResult calculateRentSplit({
    required Expense expense,
    required TNBElectricityBill tnbBill,
    required List<Tenant> activeTenants,
    required CalculationMethod method,
    Property? property,
    Map<String, RentalUnit>? tenantRentalUnits,
  }) {
    switch (method) {
      case CalculationMethod.simpleAverage:
        return _calculateSimpleAverage(expense, tnbBill, activeTenants, property, tenantRentalUnits);
      case CalculationMethod.layeredPrecise:
        return _calculateLayeredPrecise(expense, tnbBill, activeTenants, property, tenantRentalUnits);
    }
  }

  // Method A: Simple Average Method
  static CalculationResult _calculateSimpleAverage(
    Expense expense,
    TNBElectricityBill tnbBill,
    List<Tenant> activeTenants,
    Property? property,
    Map<String, RentalUnit>? tenantRentalUnits,
  ) {
    if (activeTenants.isEmpty) {
      return CalculationResult(
        expenseId: expense.id,
        calculationMethod: CalculationMethod.simpleAverage,
        totalAmount: 0.0,
        activeTenantsCount: 0,
      );
    }

    // Calculate total monthly expenses
    double totalExpenses = expense.totalNonElectricityExpenses + tnbBill.totalAmount;

    // Handle individual meters vs shared meters differently
    double commonElectricitySharePerTenant;
    Map<String, double> individualACCosts = {};

    // Simple Average Method: Always use average rate per kWh regardless of meter type
    double averageCostPerKWh = expense.totalKWhUsage > 0
        ? tnbBill.totalAmount / expense.totalKWhUsage
        : 0.0;

    if (property?.hasIndividualMeters == true) {
      // Individual meter logic: Use average rate for both common and individual usage
      double commonUsagePerPerson = expense.commonKWhUsage / activeTenants.length;
      commonElectricitySharePerTenant = MalaysianCurrency.multiply(commonUsagePerPerson, averageCostPerKWh);

      // Calculate individual AC costs using average rate
      for (Tenant tenant in activeTenants) {
        individualACCosts[tenant.id] = MalaysianCurrency.multiply(tenant.acUsageKWh, averageCostPerKWh);
      }
    } else {
      // Shared meter logic: Use average rate for all calculations
      double commonUsagePerPerson = expense.commonKWhUsage / activeTenants.length;
      commonElectricitySharePerTenant = MalaysianCurrency.multiply(commonUsagePerPerson, averageCostPerKWh);

      // Calculate individual AC costs using average rate
      for (Tenant tenant in activeTenants) {
        individualACCosts[tenant.id] = MalaysianCurrency.multiply(tenant.acUsageKWh, averageCostPerKWh);
      }
    }

    List<TenantCalculation> tenantCalculations = [];

    for (Tenant tenant in activeTenants) {
      // Calculate shares for non-electricity expenses using property data if available
      double rentShare = _calculateTenantRentShare(tenant, activeTenants, property, tenantRentalUnits, expense.baseRent);
      double internetShare = MalaysianCurrency.divide(property?.internetFixedFee ?? expense.internetFee, activeTenants.length.toDouble());
      double waterShare = MalaysianCurrency.divide(expense.waterBill, activeTenants.length.toDouble());
      double miscellaneousShare = expense.splitMiscellaneous
          ? MalaysianCurrency.divide(expense.miscellaneousExpenses, activeTenants.length.toDouble())
          : 0.0;

      // Get electricity costs from pre-calculated values
      double commonElectricityShare = commonElectricitySharePerTenant;
      double individualACCost = individualACCosts[tenant.id] ?? 0.0;
      double totalElectricityCost = MalaysianCurrency.add(commonElectricityShare, individualACCost);

      // Calculate total for tenant
      double totalAmount = MalaysianCurrency.add(
        MalaysianCurrency.add(
          MalaysianCurrency.add(rentShare, internetShare),
          MalaysianCurrency.add(waterShare, miscellaneousShare)
        ),
        totalElectricityCost
      );

      tenantCalculations.add(TenantCalculation(
        calculationResultId: '', // Will be set when result is created
        tenantId: tenant.id,
        tenantName: tenant.name,
        rentShare: rentShare,
        internetShare: internetShare,
        waterShare: waterShare,
        commonElectricityShare: commonElectricityShare,
        individualACCost: individualACCost,
        miscellaneousShare: miscellaneousShare,
        totalAmount: totalAmount,
        acUsageKWh: tenant.acUsageKWh,
      ));
    }

    return CalculationResult(
      expenseId: expense.id,
      calculationMethod: CalculationMethod.simpleAverage,
      totalAmount: totalExpenses,
      activeTenantsCount: activeTenants.length,
      tenantCalculations: tenantCalculations,
    );
  }

  // Method B: Layered Precise Method
  static CalculationResult _calculateLayeredPrecise(
    Expense expense,
    TNBElectricityBill tnbBill,
    List<Tenant> activeTenants,
    Property? property,
    Map<String, RentalUnit>? tenantRentalUnits,
  ) {
    if (activeTenants.isEmpty) {
      return CalculationResult(
        expenseId: expense.id,
        calculationMethod: CalculationMethod.layeredPrecise,
        totalAmount: 0.0,
        activeTenantsCount: 0,
      );
    }

    // Handle individual meters vs shared meters differently
    double commonElectricitySharePerTenant;
    Map<String, double> individualACCosts = {};

    if (property?.hasIndividualMeters == true) {
      // Individual meter logic: Total bill - individual usage, then divide remainder
      double totalIndividualACCost = 0.0;
      for (Tenant tenant in activeTenants) {
        double individualCost = calculateCostForUsage(tenant.acUsageKWh);
        individualACCosts[tenant.id] = individualCost;
        totalIndividualACCost += individualCost;
      }

      // Remaining cost after individual AC usage
      double remainingCost = MalaysianCurrency.subtract(tnbBill.totalAmount, totalIndividualACCost);
      commonElectricitySharePerTenant = MalaysianCurrency.divide(remainingCost, activeTenants.length.toDouble());
    } else {
      // Traditional layered precise logic: Calculate common area cost using TNB rates
      TNBElectricityBill commonBill = calculateTNBBill(
        expenseId: '${expense.id}_common',
        totalKWhUsage: expense.commonKWhUsage,
      );

      commonElectricitySharePerTenant = MalaysianCurrency.divide(
        commonBill.totalAmount,
        activeTenants.length.toDouble()
      );

      // Calculate remaining cost for AC usage
      double remainingElectricityCost = MalaysianCurrency.subtract(
        tnbBill.totalAmount,
        commonBill.totalAmount
      );

      double acRatePerKWh = expense.totalACKWhUsage > 0
          ? remainingElectricityCost / expense.totalACKWhUsage
          : 0.0;

      // Calculate individual AC costs using remaining rate
      for (Tenant tenant in activeTenants) {
        individualACCosts[tenant.id] = MalaysianCurrency.multiply(tenant.acUsageKWh, acRatePerKWh);
      }
    }

    // Step 4: Calculate total monthly expenses
    double totalExpenses = expense.totalNonElectricityExpenses + tnbBill.totalAmount;

    List<TenantCalculation> tenantCalculations = [];

    for (Tenant tenant in activeTenants) {
      // Calculate shares for non-electricity expenses using property data if available
      double rentShare = _calculateTenantRentShare(tenant, activeTenants, property, tenantRentalUnits, expense.baseRent);
      double internetShare = MalaysianCurrency.divide(property?.internetFixedFee ?? expense.internetFee, activeTenants.length.toDouble());
      double waterShare = MalaysianCurrency.divide(expense.waterBill, activeTenants.length.toDouble());
      double miscellaneousShare = expense.splitMiscellaneous
          ? MalaysianCurrency.divide(expense.miscellaneousExpenses, activeTenants.length.toDouble())
          : 0.0;

      // Get electricity costs from pre-calculated values
      double commonElectricityShare = commonElectricitySharePerTenant;
      double individualACCost = individualACCosts[tenant.id] ?? 0.0;

      // Calculate total for tenant
      double totalAmount = MalaysianCurrency.add(
        MalaysianCurrency.add(
          MalaysianCurrency.add(rentShare, internetShare),
          MalaysianCurrency.add(waterShare, miscellaneousShare)
        ),
        MalaysianCurrency.add(commonElectricityShare, individualACCost)
      );

      tenantCalculations.add(TenantCalculation(
        calculationResultId: '', // Will be set when result is created
        tenantId: tenant.id,
        tenantName: tenant.name,
        rentShare: rentShare,
        internetShare: internetShare,
        waterShare: waterShare,
        commonElectricityShare: commonElectricityShare,
        individualACCost: individualACCost,
        miscellaneousShare: miscellaneousShare,
        totalAmount: totalAmount,
        acUsageKWh: tenant.acUsageKWh,
      ));
    }

    return CalculationResult(
      expenseId: expense.id,
      calculationMethod: CalculationMethod.layeredPrecise,
      totalAmount: totalExpenses,
      activeTenantsCount: activeTenants.length,
      tenantCalculations: tenantCalculations,
    );
  }

  // Validate calculation inputs
  static List<String> validateInputs({
    required Expense expense,
    required List<Tenant> tenants,
  }) {
    List<String> errors = [];

    // Check if there are active tenants
    List<Tenant> activeTenants = tenants.where((t) => t.isActive).toList();
    if (activeTenants.isEmpty) {
      errors.add('At least one active tenant is required');
    }

    // Validate expense data
    if (expense.month < 1 || expense.month > 12) {
      errors.add('Invalid month: ${expense.month}');
    }
    
    if (expense.year < 2020 || expense.year > DateTime.now().year + 1) {
      errors.add('Invalid year: ${expense.year}');
    }

    if (expense.totalKWhUsage < 0) {
      errors.add('Total electricity usage cannot be negative');
    }

    if (expense.totalACKWhUsage < 0) {
      errors.add('Total AC usage cannot be negative');
    }

    if (expense.totalACKWhUsage > expense.totalKWhUsage) {
      errors.add('AC usage cannot exceed total electricity usage');
    }

    // Validate tenant AC readings
    double calculatedACTotal = activeTenants.fold(0.0, (sum, tenant) => sum + tenant.acUsageKWh);
    if ((calculatedACTotal - expense.totalACKWhUsage).abs() > 1.0) {
      errors.add('Tenant AC usage total (${calculatedACTotal.toStringAsFixed(1)}kWh) '
                'does not match expense AC total (${expense.totalACKWhUsage.toStringAsFixed(1)}kWh)');
    }

    // Check for negative AC readings
    for (Tenant tenant in activeTenants) {
      if (!tenant.hasValidACReadings) {
        errors.add('${tenant.name} has invalid AC readings: '
                  'current (${tenant.currentACReading}) must be >= previous (${tenant.previousACReading})');
      }
    }

    return errors;
  }

  // Get calculation summary
  static Map<String, dynamic> getCalculationSummary(
    CalculationResult result,
    TNBElectricityBill tnbBill,
  ) {
    double totalCalculatedAmount = result.tenantCalculations
        .fold(0.0, (sum, calc) => sum + calc.totalAmount);
    
    double totalACUsage = result.tenantCalculations
        .fold(0.0, (sum, calc) => sum + calc.acUsageKWh);

    return {
      'method': result.calculationMethod.displayName,
      'totalAmount': result.totalAmount,
      'totalCalculatedAmount': totalCalculatedAmount,
      'difference': result.totalAmount - totalCalculatedAmount,
      'isBalanced': result.isBalanced,
      'averagePerTenant': result.averageAmountPerTenant,
      'activeTenants': result.activeTenantsCount,
      'totalACUsage': totalACUsage,
      'tnbBillTotal': tnbBill.totalAmount,
      'tnbBreakdown': tnbBill.breakdown,
    };
  }

  // Compare calculation methods
  static Map<String, CalculationResult> compareCalculationMethods({
    required Expense expense,
    required TNBElectricityBill tnbBill,
    required List<Tenant> activeTenants,
  }) {
    return {
      'simpleAverage': calculateRentSplit(
        expense: expense,
        tnbBill: tnbBill,
        activeTenants: activeTenants,
        method: CalculationMethod.simpleAverage,
      ),
      'layeredPrecise': calculateRentSplit(
        expense: expense,
        tnbBill: tnbBill,
        activeTenants: activeTenants,
        method: CalculationMethod.layeredPrecise,
      ),
    };
  }

  // Calculate monthly savings with energy efficiency
  static Map<String, double> calculateSavingsOpportunities(TNBElectricityBill bill) {
    Map<String, double> savings = {};

    // Calculate potential savings if usage was reduced to different thresholds
    List<double> thresholds = [300, 600, 1000];
    
    for (double threshold in thresholds) {
      if (bill.totalKWhUsage > threshold) {
        TNBElectricityBill reducedBill = calculateTNBBill(
          expenseId: '${bill.expenseId}_reduced',
          totalKWhUsage: threshold,
        );
        
        double potentialSavings = bill.totalAmount - reducedBill.totalAmount;
        savings['savingsAt${threshold.toInt()}kWh'] = potentialSavings;
      }
    }

    return savings;
  }

  /// Get detailed breakdown explanation for a given usage
  static Map<String, dynamic> getCalculationBreakdown(double kWhUsage) {
    final energyCharge = _calculateEnergyCharge(kWhUsage);
    final capacityCharge = _calculateCapacityCharge(kWhUsage);
    final networkCharge = _calculateNetworkCharge(kWhUsage);
    final retailCharge = _calculateRetailCharge(kWhUsage);
    final eeIncentive = _calculateEEIncentive(kWhUsage);
    final subtotal = energyCharge + capacityCharge + networkCharge + retailCharge + eeIncentive;
    final kwtbbTax = _calculateKWTBBTax(subtotal, kWhUsage);
    final sstTax = _calculateSSTTax(subtotal, kWhUsage);
    final total = subtotal + kwtbbTax + sstTax;

    return {
      'usage_kWh': kWhUsage,
      'energy_charge': {
        'amount': energyCharge,
        'calculation': kWhUsage <= energyTier1Threshold
          ? '${kWhUsage.toStringAsFixed(1)} kWh × RM $energyRateTier1'
          : '${energyTier1Threshold.toStringAsFixed(0)} kWh × RM $energyRateTier1 + ${(kWhUsage - energyTier1Threshold).toStringAsFixed(1)} kWh × RM $energyRateTier2',
      },
      'capacity_charge': {
        'amount': capacityCharge,
        'calculation': '${kWhUsage.toStringAsFixed(1)} kWh × RM $capacityRate',
      },
      'network_charge': {
        'amount': networkCharge,
        'calculation': '${kWhUsage.toStringAsFixed(1)} kWh × RM $networkRate',
      },
      'retail_charge': {
        'amount': retailCharge,
        'calculation': kWhUsage <= retailChargeWaiverThreshold
          ? 'Waived (≤${retailChargeWaiverThreshold.toStringAsFixed(0)} kWh)'
          : 'RM $retailChargeAmount (>${retailChargeWaiverThreshold.toStringAsFixed(0)} kWh)',
      },
      'ee_incentive': {
        'amount': eeIncentive,
        'calculation': eeIncentive == 0.0 ? 'No incentive applicable' : 'Energy efficiency discount applied',
      },
      'subtotal': subtotal,
      'kwtbb_tax': {
        'amount': kwtbbTax,
        'calculation': kWhUsage <= kwtbbExemptionThreshold
          ? 'Exempted (≤${kwtbbExemptionThreshold.toStringAsFixed(0)} kWh)'
          : 'RM ${subtotal.toStringAsFixed(2)} × ${(kwtbbTaxRate * 100).toStringAsFixed(1)}%',
      },
      'sst_tax': {
        'amount': sstTax,
        'calculation': kWhUsage <= sstThreshold
          ? 'Not applicable (≤${sstThreshold.toStringAsFixed(0)} kWh)'
          : 'RM ${subtotal.toStringAsFixed(2)} × ${(sstTaxRate * 100).toStringAsFixed(1)}%',
      },
      'total_amount': total,
    };
  }

  /// Validate if calculated total matches provided bill amount (within tolerance)
  static bool validateBillAmount(double calculatedTotal, double providedTotal, {double tolerance = 0.50}) {
    return (calculatedTotal - providedTotal).abs() <= tolerance;
  }

  /// Get average cost per kWh for a given total bill and usage
  static double getAverageCostPerKWh(double totalAmount, double kWhUsage) {
    if (kWhUsage == 0) return 0.0;
    return totalAmount / kWhUsage;
  }

  /// Calculate cost for specific kWh amount using TNB rates
  /// For individual AC usage, this should use marginal rates, not full bill structure
  static double calculateCostForUsage(double kWhUsage) {
    // For individual AC usage, calculate using marginal energy rates only
    // This avoids applying fixed charges and taxes multiple times
    return calculateMarginalCostForUsage(kWhUsage);
  }

  /// Calculate marginal cost for individual AC usage (energy rates only)
  static double calculateMarginalCostForUsage(double kWhUsage) {
    if (kWhUsage <= 0) return 0.0;

    // Use only the variable energy components for individual AC usage
    // For individual AC usage, use tier 1 rate (most common scenario)
    double energyCharge = kWhUsage * energyRateTier1;
    double capacityCharge = kWhUsage * capacityRate;
    double networkCharge = kWhUsage * networkRate;

    // Apply EE incentive if applicable (only for usage ≤1000 kWh)
    double eeIncentive = kWhUsage <= 1000 ? kWhUsage * eeIncentiveRate : 0.0;

    return energyCharge + capacityCharge + networkCharge + eeIncentive;
  }

  /// Calculate tenant rent share based on property and rental unit data
  static double _calculateTenantRentShare(
    Tenant tenant,
    List<Tenant> activeTenants,
    Property? property,
    Map<String, RentalUnit>? tenantRentalUnits,
    double fallbackBaseRent,
  ) {
    // If tenant has a specific rental unit, use its monthly rent (individual unit rent)
    if (tenant.rentalUnitId != null && tenantRentalUnits != null) {
      final rentalUnit = tenantRentalUnits[tenant.rentalUnitId];
      if (rentalUnit != null) {
        return rentalUnit.monthlyRent; // Individual unit rent, not divided
      }
    }

    // If no specific unit but property has base rental price, divide among tenants
    // (This applies when it's a whole house rental with no individual units)
    if (property != null && property.baseRentalPrice > 0) {
      return MalaysianCurrency.divide(property.baseRentalPrice, activeTenants.length.toDouble());
    }

    // Fallback to expense base rent divided by tenants
    return MalaysianCurrency.divide(fallbackBaseRent, activeTenants.length.toDouble());
  }
}