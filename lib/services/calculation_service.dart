import '../models/models.dart';
import '../database/database_helper.dart';
import 'preferences_service.dart';
import 'tnb_calculation_service.dart';

class CalculationService {
  static final CalculationService _instance = CalculationService._internal();
  factory CalculationService() => _instance;
  CalculationService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final PreferencesService _prefsService = PreferencesService();

  /// Calculate and save rent split for a given expense and tenants
  Future<CalculationResult> calculateAndSaveRentSplit({
    required Expense expense,
    List<Tenant>? tenants,
    double? customACRate,
  }) async {
    // Get active tenants if not provided
    tenants ??= await _dbHelper.getActiveTenants();

    // Get AC rate from preferences if not provided
    customACRate ??= await _prefsService.getACRate();

    // Get property data for rental pricing
    final property = await _dbHelper.getProperty(expense.propertyId);

    // Get rental unit data for each tenant
    final Map<String, RentalUnit> tenantRentalUnits = {};
    for (final tenant in tenants) {
      if (tenant.rentalUnitId != null) {
        final rentalUnit = await _dbHelper.getRentalUnit(tenant.rentalUnitId!);
        if (rentalUnit != null) {
          tenantRentalUnits[tenant.rentalUnitId!] = rentalUnit;
        }
      }
    }

    // Get or create TNB bill for this expense
    final tnbBill = await _dbHelper.getTNBBillByExpenseId(expense.id);
    if (tnbBill == null) {
      throw Exception('TNB bill not found for expense ${expense.id}');
    }

    // Perform the calculation using TNBCalculationService
    final result = TNBCalculationService.calculateRentSplit(
      expense: expense,
      tnbBill: tnbBill,
      activeTenants: tenants,
      method: CalculationMethod.simpleAverage, // Default method
      property: property,
      tenantRentalUnits: tenantRentalUnits,
    );

    // Save the calculation result to database
    try {
      await _dbHelper.insertCalculationResult(result);
    } catch (e) {
      // If insert fails, try update (might be recalculation)
      await _dbHelper.updateCalculationResult(result);
    }

    return result;
  }

  /// Get existing calculation for an expense, or calculate new one
  Future<CalculationResult?> getOrCalculateRentSplit({
    required String expenseId,
    bool forceRecalculate = false,
  }) async {
    if (!forceRecalculate) {
      // Try to get existing calculation
      final existing = await _dbHelper.getCalculationResultByExpenseId(expenseId);
      if (existing != null) {
        return existing;
      }
    }
    
    // Get the expense
    final expense = await _dbHelper.getExpenseById(expenseId);
    if (expense == null) {
      return null;
    }
    
    // Calculate new result
    return await calculateAndSaveRentSplit(expense: expense);
  }

  /// Recalculate all existing calculation results
  Future<List<CalculationResult>> recalculateAllRentSplits() async {
    final expenses = await _dbHelper.getAllExpenses();
    final results = <CalculationResult>[];
    
    for (final expense in expenses) {
      try {
        final result = await calculateAndSaveRentSplit(expense: expense);
        results.add(result);
      } catch (e) {
        // Continue with other calculations even if one fails
        continue;
      }
    }
    
    return results;
  }

  /// Calculate summary statistics for a calculation result
  Map<String, dynamic> calculateSummaryStats(CalculationResult result) {
    if (result.tenantCalculations.isEmpty) {
      return {
        'totalTenants': 0,
        'totalAmount': 0.0,
        'averagePerTenant': 0.0,
        'minAmount': 0.0,
        'maxAmount': 0.0,
        'totalACUsage': 0.0,
        'totalACCost': 0.0,
        'averageACUsage': 0.0,
      };
    }

    final amounts = result.tenantCalculations.map((t) => t.totalAmount).toList();
    final acUsages = result.tenantCalculations.map((t) => t.acUsageKWh).toList();
    final acCosts = result.tenantCalculations.map((t) => t.individualACCost).toList();

    return {
      'totalTenants': result.activeTenantsCount,
      'totalAmount': result.totalAmount,
      'averagePerTenant': result.totalAmount / result.activeTenantsCount,
      'minAmount': amounts.reduce((a, b) => a < b ? a : b),
      'maxAmount': amounts.reduce((a, b) => a > b ? a : b),
      'totalACUsage': acUsages.fold(0.0, (sum, usage) => sum + usage),
      'totalACCost': acCosts.fold(0.0, (sum, cost) => sum + cost),
      'averageACUsage': acUsages.fold(0.0, (sum, usage) => sum + usage) / result.activeTenantsCount,
    };
  }

  /// Validate tenant meter readings for calculation
  List<String> validateTenantReadings(List<Tenant> tenants) {
    final errors = <String>[];
    
    for (final tenant in tenants) {
      if (!tenant.isActive) continue;
      
      if (tenant.currentACReading < 0) {
        errors.add('${tenant.name}: Missing current AC reading');
      }
      
      if (tenant.previousACReading < 0) {
        errors.add('${tenant.name}: Missing previous AC reading');
      }
      
      if (tenant.currentACReading < tenant.previousACReading) {
        errors.add('${tenant.name}: Current reading is less than previous reading');
      }
    }
    
    return errors;
  }

  /// Get calculation breakdown for a specific tenant
  Map<String, dynamic> getTenantBreakdown(
    CalculationResult result,
    String tenantId,
    Currency currency,
  ) {
    final tenantCalc = result.tenantCalculations
        .where((calc) => calc.tenantId == tenantId)
        .firstOrNull;
    
    if (tenantCalc == null) {
      return {};
    }

    return {
      'tenantName': tenantCalc.tenantName,
      'breakdown': [
        {
          'category': 'Rent Share',
          'amount': tenantCalc.rentShare,
          'formatted': currency.formatAmount(tenantCalc.rentShare),
          'description': 'Base rent divided equally among all tenants',
        },
        {
          'category': 'Internet Share',
          'amount': tenantCalc.internetShare,
          'formatted': currency.formatAmount(tenantCalc.internetShare),
          'description': 'Internet/WiFi fee divided equally among all tenants',
        },
        {
          'category': 'Water Share',
          'amount': tenantCalc.waterShare,
          'formatted': currency.formatAmount(tenantCalc.waterShare),
          'description': 'Water bill divided equally among all tenants',
        },
        {
          'category': 'Electricity (Non-AC)',
          'amount': tenantCalc.commonElectricityShare,
          'formatted': currency.formatAmount(tenantCalc.commonElectricityShare),
          'description': 'Non-AC electricity cost divided equally among all tenants',
        },
        {
          'category': 'Air Conditioning',
          'amount': tenantCalc.individualACCost,
          'formatted': currency.formatAmount(tenantCalc.individualACCost),
          'description': 'Individual AC usage: ${tenantCalc.acUsageKWh.toStringAsFixed(1)} kWh × RM 0.40/kWh',
        },
        if (tenantCalc.miscellaneousShare > 0)
          {
            'category': 'Miscellaneous',
            'amount': tenantCalc.miscellaneousShare,
            'formatted': currency.formatAmount(tenantCalc.miscellaneousShare),
            'description': 'Additional expenses divided equally among all tenants',
          },
      ],
      'total': {
        'amount': tenantCalc.totalAmount,
        'formatted': currency.formatAmount(tenantCalc.totalAmount),
      },
      'acUsage': {
        'units': tenantCalc.acUsageKWh,
        'rate': 0.40, // Default AC rate
        'cost': tenantCalc.individualACCost,
      },
    };
  }

  /// Generate a comparison report between multiple months
  Future<Map<String, dynamic>> generateComparisonReport(
    List<String> expenseIds,
    Currency currency,
  ) async {
    final comparisons = <Map<String, dynamic>>[];
    
    for (final expenseId in expenseIds) {
      final result = await getOrCalculateRentSplit(expenseId: expenseId);
      if (result != null) {
        final expense = await _dbHelper.getExpenseById(expenseId);
        if (expense != null) {
          final stats = calculateSummaryStats(result);
          comparisons.add({
            'month': expense.month,
            'monthName': expense.month,
            'year': expense.year,
            'result': result,
            'expense': expense,
            'stats': stats,
            'totalFormatted': currency.formatAmount(stats['totalAmount']),
          });
        }
      }
    }
    
    // Sort by year and month
    comparisons.sort((a, b) {
      int yearCompare = (a['year'] as int).compareTo(b['year'] as int);
      if (yearCompare != 0) return yearCompare;
      return (a['month'] as int).compareTo(b['month'] as int);
    });
    
    return {
      'comparisons': comparisons,
      'trends': _calculateTrends(comparisons),
    };
  }

  Map<String, dynamic> _calculateTrends(List<Map<String, dynamic>> comparisons) {
    if (comparisons.length < 2) {
      return {'hasEnoughData': false};
    }

    final totals = comparisons.map((c) => c['stats']['totalAmount'] as double).toList();
    final acUsages = comparisons.map((c) => c['stats']['totalACUsage'] as double).toList();
    
    // Calculate month-over-month changes
    final totalChanges = <double>[];
    final acUsageChanges = <double>[];
    
    for (int i = 1; i < totals.length; i++) {
      final totalChange = ((totals[i] - totals[i-1]) / totals[i-1]) * 100;
      final acChange = acUsages[i-1] != 0 
          ? ((acUsages[i] - acUsages[i-1]) / acUsages[i-1]) * 100
          : 0.0;
      
      totalChanges.add(totalChange);
      acUsageChanges.add(acChange);
    }
    
    return {
      'hasEnoughData': true,
      'averageMonthlyChange': totalChanges.fold(0.0, (sum, change) => sum + change) / totalChanges.length,
      'averageACUsageChange': acUsageChanges.fold(0.0, (sum, change) => sum + change) / acUsageChanges.length,
      'totalGrowth': totalChanges.isNotEmpty ? ((totals.last - totals.first) / totals.first) * 100 : 0.0,
      'acUsageGrowth': acUsages.first != 0 ? ((acUsages.last - acUsages.first) / acUsages.first) * 100 : 0.0,
    };
  }

  /// Export calculation data for sharing
  Map<String, dynamic> exportCalculationData(
    CalculationResult result,
    Expense expense,
    Currency currency,
  ) {
    return {
      'exportDate': DateTime.now().toIso8601String(),
      'month': DateTime(expense.year, expense.month).toIso8601String(),
      'currency': currency.toMap(),
      'expense': expense.toMap(),
      'calculation': result.toMap(),
      'summary': calculateSummaryStats(result),
      'formattedBreakdowns': result.tenantCalculations.map((calc) => 
        getTenantBreakdown(result, calc.tenantId, currency)
      ).toList(),
    };
  }
} 