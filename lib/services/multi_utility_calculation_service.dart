import '../models/tenant.dart';
import '../models/expense.dart';
import '../models/utility_provider.dart';
import '../models/utility_bill.dart';
import '../models/calculation_result.dart';
import '../models/tenant_calculation.dart';
import '../models/malaysian_currency.dart';

class MultiUtilityCalculationService {
  // Calculate rent split with multiple utility providers
  static CalculationResult calculateRentSplit({
    required Expense expense,
    required List<UtilityBill> utilityBills,
    required List<Tenant> activeTenants,
    required CalculationMethod method,
    required MalaysianState userState,
  }) {
    switch (method) {
      case CalculationMethod.simpleAverage:
        return _calculateSimpleAverage(expense, utilityBills, activeTenants);
      case CalculationMethod.layeredPrecise:
        return _calculateLayeredPrecise(expense, utilityBills, activeTenants, userState);
    }
  }

  // Method A: Simple Average Method
  static CalculationResult _calculateSimpleAverage(
    Expense expense,
    List<UtilityBill> utilityBills,
    List<Tenant> activeTenants,
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
    double totalUtilityAmount = utilityBills.fold(0.0, (sum, bill) => sum + bill.totalAmount);
    double totalExpenses = expense.totalNonElectricityExpenses + totalUtilityAmount;
    
    // Note: Electricity calculations now use expense.electricPricePerKWh directly

    List<TenantCalculation> tenantCalculations = [];

    for (Tenant tenant in activeTenants) {
      // Calculate shares for non-utility expenses
      double rentShare = MalaysianCurrency.divide(expense.baseRent, activeTenants.length.toDouble());
      double internetShare = MalaysianCurrency.divide(expense.internetFee, activeTenants.length.toDouble());
      double miscellaneousShare = expense.splitMiscellaneous
          ? MalaysianCurrency.divide(expense.miscellaneousExpenses, activeTenants.length.toDouble())
          : 0.0;

      // Calculate utility shares
      double waterShare = 0.0;
      double commonElectricityShare = 0.0;
      double individualACCost = 0.0;

      // Water bill sharing (equal split)
      UtilityBill? waterBill = utilityBills
          .where((bill) => bill.utilityType == UtilityType.water)
          .firstOrNull;
      if (waterBill != null) {
        waterShare = MalaysianCurrency.divide(waterBill.totalAmount, activeTenants.length.toDouble());
      }

      // Electricity bill sharing using expense electric price
      if (expense.totalKWhUsage > 0) {
        double commonUsagePerPerson = expense.commonKWhUsage / activeTenants.length;

        commonElectricityShare = MalaysianCurrency.multiply(commonUsagePerPerson, expense.electricPricePerKWh);
        individualACCost = MalaysianCurrency.multiply(tenant.acUsageKWh, expense.electricPricePerKWh);
      }

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
      calculationMethod: CalculationMethod.simpleAverage,
      totalAmount: totalExpenses,
      activeTenantsCount: activeTenants.length,
      tenantCalculations: tenantCalculations,
    );
  }

  // Method B: Layered Precise Method
  static CalculationResult _calculateLayeredPrecise(
    Expense expense,
    List<UtilityBill> utilityBills,
    List<Tenant> activeTenants,
    MalaysianState userState,
  ) {
    if (activeTenants.isEmpty) {
      return CalculationResult(
        expenseId: expense.id,
        calculationMethod: CalculationMethod.layeredPrecise,
        totalAmount: 0.0,
        activeTenantsCount: 0,
      );
    }

    // Get electricity provider for the user's state
    UtilityProvider? electricityProvider = MalaysianUtilityProviders.getElectricityProvider(userState);
    if (electricityProvider == null) {
      throw Exception('No electricity provider found for state: ${userState.displayName}');
    }

    // Step 1: Calculate common area electricity cost using expense electric price
    double commonElectricityCost = expense.commonKWhUsage * expense.electricPricePerKWh;

    // Step 2: Calculate per-person common share
    double commonSharePerPerson = MalaysianCurrency.divide(
      commonElectricityCost,
      activeTenants.length.toDouble()
    );

    // Step 3: Use expense electric price for AC usage
    double acRatePerKWh = expense.electricPricePerKWh;

    // Step 4: Calculate total monthly expenses
    double totalUtilityAmount = utilityBills.fold(0.0, (sum, bill) => sum + bill.totalAmount);
    double totalExpenses = expense.totalNonElectricityExpenses + totalUtilityAmount;

    List<TenantCalculation> tenantCalculations = [];

    for (Tenant tenant in activeTenants) {
      // Calculate shares for non-utility expenses
      double rentShare = MalaysianCurrency.divide(expense.baseRent, activeTenants.length.toDouble());
      double internetShare = MalaysianCurrency.divide(expense.internetFee, activeTenants.length.toDouble());
      double miscellaneousShare = expense.splitMiscellaneous
          ? MalaysianCurrency.divide(expense.miscellaneousExpenses, activeTenants.length.toDouble())
          : 0.0;

      // Water share (equal split)
      double waterShare = 0.0;
      UtilityBill? waterBill = utilityBills
          .where((bill) => bill.utilityType == UtilityType.water)
          .firstOrNull;
      if (waterBill != null) {
        waterShare = MalaysianCurrency.divide(waterBill.totalAmount, activeTenants.length.toDouble());
      }

      // Electricity costs
      double commonElectricityShare = commonSharePerPerson;
      double individualACCost = MalaysianCurrency.multiply(tenant.acUsageKWh, acRatePerKWh);

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

  // Validate calculation inputs for multiple providers
  static List<String> validateInputs({
    required Expense expense,
    required List<Tenant> tenants,
    required List<UtilityBill> utilityBills,
    required MalaysianState userState,
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

    // Validate utility bills
    if (utilityBills.isEmpty) {
      errors.add('At least one utility bill is required');
    }

    // Check for electricity bill
    bool hasElectricityBill = utilityBills.any((bill) => bill.utilityType == UtilityType.electricity);
    if (!hasElectricityBill && expense.totalKWhUsage > 0) {
      errors.add('Electricity bill is required when electricity usage is specified');
    }

    // Validate providers serve the user's state
    for (UtilityBill bill in utilityBills) {
      UtilityProvider? provider = MalaysianUtilityProviders.allProviders
          .where((p) => p.id == bill.providerId)
          .firstOrNull;
      
      if (provider != null && !provider.servesState(userState)) {
        errors.add('${provider.name} does not serve ${userState.displayName}');
      }
    }

    // Validate tenant AC readings
    if (hasElectricityBill) {
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
    }

    return errors;
  }

  // Get available providers for a state
  static Map<String, List<UtilityProvider>> getAvailableProviders(MalaysianState state) {
    return {
      'electricity': MalaysianUtilityProviders.electricityProviders
          .where((p) => p.servesState(state))
          .toList(),
      'water': MalaysianUtilityProviders.waterProviders
          .where((p) => p.servesState(state))
          .toList(),
    };
  }

  // Get calculation summary with multiple utilities
  static Map<String, dynamic> getCalculationSummary(
    CalculationResult result,
    List<UtilityBill> utilityBills,
  ) {
    double totalCalculatedAmount = result.tenantCalculations
        .fold(0.0, (sum, calc) => sum + calc.totalAmount);
    
    double totalACUsage = result.tenantCalculations
        .fold(0.0, (sum, calc) => sum + calc.acUsageKWh);

    Map<String, double> utilityBreakdown = {};
    for (UtilityBill bill in utilityBills) {
      utilityBreakdown['${bill.utilityType.name}_total'] = bill.totalAmount;
    }

    return {
      'method': result.calculationMethod.displayName,
      'totalAmount': result.totalAmount,
      'totalCalculatedAmount': totalCalculatedAmount,
      'difference': result.totalAmount - totalCalculatedAmount,
      'isBalanced': result.isBalanced,
      'averagePerTenant': result.averageAmountPerTenant,
      'activeTenants': result.activeTenantsCount,
      'totalACUsage': totalACUsage,
      'utilityBreakdown': utilityBreakdown,
      'utilityBillsCount': utilityBills.length,
    };
  }

  // Compare different utility providers for a state
  static Map<String, UtilityBill> compareUtilityProviders({
    required MalaysianState state,
    required UtilityType utilityType,
    required double usage,
    required DateTime billingStart,
    required DateTime billingEnd,
    required DateTime dueDate,
  }) {
    List<UtilityProvider> providers = MalaysianUtilityProviders.allProviders
        .where((p) => p.type == utilityType && p.servesState(state))
        .toList();

    Map<String, UtilityBill> comparison = {};

    for (UtilityProvider provider in providers) {
      UtilityBill bill = UtilityBill.calculateFromUsage(
        expenseId: 'comparison_${provider.id}',
        provider: provider,
        totalUsage: usage,
        billingPeriodStart: billingStart,
        billingPeriodEnd: billingEnd,
        dueDate: dueDate,
      );
      
      comparison[provider.name] = bill;
    }

    return comparison;
  }

  // Calculate potential savings by switching providers
  static Map<String, double> calculateSavingsOpportunities({
    required MalaysianState state,
    required List<UtilityBill> currentBills,
  }) {
    Map<String, double> savings = {};

    for (UtilityBill currentBill in currentBills) {
      Map<String, UtilityBill> alternatives = compareUtilityProviders(
        state: state,
        utilityType: currentBill.utilityType,
        usage: currentBill.totalUsage,
        billingStart: currentBill.billingPeriodStart,
        billingEnd: currentBill.billingPeriodEnd,
        dueDate: currentBill.dueDate,
      );

      double currentAmount = currentBill.totalAmount;
      double lowestAmount = alternatives.values
          .map((bill) => bill.totalAmount)
          .reduce((a, b) => a < b ? a : b);

      if (currentAmount > lowestAmount) {
        savings['${currentBill.utilityType.name}_savings'] = currentAmount - lowestAmount;
      }
    }

    return savings;
  }
}

extension ListUtilityExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}