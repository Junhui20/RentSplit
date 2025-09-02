import '../models/property.dart';
import '../models/rental_unit.dart';
import '../models/rental_agreement.dart';
import '../models/tenant.dart';
import '../models/expense.dart';
import '../models/utility_bill.dart';
import '../models/calculation_result.dart';
import '../models/utility_provider.dart';
import '../models/malaysian_currency.dart';
import 'multi_utility_calculation_service.dart';

class PropertyManagementService {
  // Property Portfolio Management
  
  /// Get property portfolio overview for owner
  static Map<String, dynamic> getPropertyPortfolioSummary(
    List<Property> properties,
    List<RentalUnit> allUnits,
    List<RentalAgreement> allAgreements,
  ) {
    int totalProperties = properties.length;
    int activeProperties = properties.where((p) => p.isActive).length;
    int totalUnits = allUnits.length;
    int occupiedUnits = allUnits.where((u) => u.currentOccupancy > 0).length;
    int availableUnits = allUnits.where((u) => u.isAvailable).length;
    
    double totalMonthlyRent = allAgreements
        .where((a) => a.isActive)
        .fold(0.0, (sum, a) => sum + a.monthlyRent);
    
    double occupancyRate = totalUnits > 0 ? (occupiedUnits / totalUnits) * 100 : 0.0;
    
    Map<String, int> unitsByState = {};
    for (Property property in properties) {
      String state = property.state.displayName;
      unitsByState[state] = (unitsByState[state] ?? 0) + 
          allUnits.where((u) => u.propertyId == property.id).length;
    }
    
    return {
      'totalProperties': totalProperties,
      'activeProperties': activeProperties,
      'totalUnits': totalUnits,
      'occupiedUnits': occupiedUnits,
      'availableUnits': availableUnits,
      'occupancyRate': occupancyRate,
      'totalMonthlyRent': totalMonthlyRent,
      'unitsByState': unitsByState,
      'propertiesNeedingAttention': _getPropertiesNeedingAttention(properties, allUnits, allAgreements),
    };
  }
  
  /// Get properties requiring owner attention
  static List<Map<String, dynamic>> _getPropertiesNeedingAttention(
    List<Property> properties,
    List<RentalUnit> allUnits,
    List<RentalAgreement> allAgreements,
  ) {
    List<Map<String, dynamic>> attention = [];
    
    for (Property property in properties) {
      List<RentalUnit> propertyUnits = allUnits.where((u) => u.propertyId == property.id).toList();
      List<RentalAgreement> propertyAgreements = allAgreements
          .where((a) => a.propertyId == property.id)
          .toList();
      
      // Check for expiring agreements (next 30 days)
      int expiringAgreements = propertyAgreements
          .where((a) => a.daysUntilExpiry <= 30 && a.daysUntilExpiry > 0)
          .length;
      
      // Check for vacant units
      int vacantUnits = propertyUnits
          .where((u) => u.isAvailable && u.currentOccupancy == 0)
          .length;
      
      // Check for maintenance units
      int maintenanceUnits = propertyUnits
          .where((u) => u.status == RentalUnitStatus.maintenance)
          .length;
      
      if (expiringAgreements > 0 || vacantUnits > 0 || maintenanceUnits > 0) {
        attention.add({
          'propertyId': property.id,
          'propertyName': property.name,
          'expiringAgreements': expiringAgreements,
          'vacantUnits': vacantUnits,
          'maintenanceUnits': maintenanceUnits,
        });
      }
    }
    
    return attention;
  }
  
  // Multi-Property Utility Management
  
  /// Calculate utilities for all properties in a month
  static Future<Map<String, List<CalculationResult>>> calculateAllPropertiesUtilities({
    required List<Property> properties,
    required Map<String, List<RentalUnit>> unitsByProperty,
    required Map<String, List<Tenant>> tenantsByProperty,
    required Map<String, List<Expense>> expensesByProperty,
    required Map<String, List<UtilityBill>> utilityBillsByProperty,
    required int month,
    required int year,
    required CalculationMethod method,
  }) async {
    Map<String, List<CalculationResult>> results = {};
    
    for (Property property in properties) {
      List<Tenant> propertyTenants = tenantsByProperty[property.id] ?? [];
      List<Tenant> activeTenants = propertyTenants.where((t) => t.isActive).toList();
      
      List<Expense> propertyExpenses = expensesByProperty[property.id] ?? [];
      Expense? monthExpense = propertyExpenses
          .where((e) => e.month == month && e.year == year)
          .firstOrNull;
      
      if (monthExpense != null && activeTenants.isNotEmpty) {
        List<UtilityBill> propertyBills = utilityBillsByProperty[property.id] ?? [];
        
        try {
          CalculationResult result = MultiUtilityCalculationService.calculateRentSplit(
            expense: monthExpense,
            utilityBills: propertyBills,
            activeTenants: activeTenants,
            method: method,
            userState: property.state,
          );
          
          results[property.id] = [result];
        } catch (e) {
          // Log error but continue with other properties
          results[property.id] = [];
        }
      } else {
        results[property.id] = [];
      }
    }
    
    return results;
  }
  
  // Rental Unit Management
  
  /// Get rental unit performance analytics
  static Map<String, dynamic> getRentalUnitAnalytics(
    RentalUnit unit,
    List<RentalAgreement> agreements,
    List<Expense> expenses,
  ) {
    List<RentalAgreement> unitAgreements = agreements
        .where((a) => a.rentalUnitId == unit.id)
        .toList();
    
    double totalRentCollected = unitAgreements
        .where((a) => a.status == RentalAgreementStatus.active || 
                     a.status == RentalAgreementStatus.expired)
        .fold(0.0, (sum, a) => sum + (a.monthlyRent * a.durationInMonths));
    
    int totalDaysOccupied = unitAgreements
        .fold(0, (sum, a) => sum + a.endDate.difference(a.startDate).inDays);
    
    double averageRent = unitAgreements.isNotEmpty
        ? unitAgreements.fold(0.0, (sum, a) => sum + a.monthlyRent) / unitAgreements.length
        : 0.0;
    
    DateTime? lastOccupiedDate = unitAgreements.isNotEmpty
        ? unitAgreements.map((a) => a.endDate).reduce((a, b) => a.isAfter(b) ? a : b)
        : null;
    
    int vacantDays = lastOccupiedDate != null
        ? DateTime.now().difference(lastOccupiedDate).inDays
        : 0;
    
    return {
      'totalRentCollected': totalRentCollected,
      'totalDaysOccupied': totalDaysOccupied,
      'averageRent': averageRent,
      'totalAgreements': unitAgreements.length,
      'currentOccupancyRate': unit.occupancyRate,
      'vacantDays': vacantDays,
      'lastOccupiedDate': lastOccupiedDate,
      'isCurrentlyVacant': unit.currentOccupancy == 0,
    };
  }
  
  // Tenant Onboarding Workflow
  
  /// Create complete tenant onboarding package
  static Map<String, dynamic> createTenantOnboardingPackage({
    required Property property,
    required RentalUnit unit,
    required Tenant tenant,
    required DateTime startDate,
    required DateTime endDate,
    required double monthlyRent,
    double? securityDeposit,
    double? utilityDeposit,
  }) {
    // Create rental agreement
    RentalAgreement agreement = RentalAgreement(
      propertyId: property.id,
      rentalUnitId: unit.id,
      tenantId: tenant.id,
      startDate: startDate,
      endDate: endDate,
      monthlyRent: monthlyRent,
      securityDeposit: securityDeposit ?? monthlyRent,
      utilityDeposit: utilityDeposit ?? 100.0,
      status: RentalAgreementStatus.draft,
    );
    
    // Calculate initial costs
    double totalDeposit = agreement.totalDeposit;
    double firstMonthRent = monthlyRent;
    double totalInitialPayment = totalDeposit + firstMonthRent;
    
    // Get utility providers
    UtilityProvider? electricityProvider = property.electricityProvider;
    UtilityProvider? waterProvider = property.waterProvider;
    
    // Prepare onboarding checklist
    List<String> checklist = [
      'Complete rental agreement signing',
      'Collect security deposit (${MalaysianCurrency.format(agreement.securityDeposit)})',
      'Collect utility deposit (${MalaysianCurrency.format(agreement.utilityDeposit)})',
      'Collect first month rent (${MalaysianCurrency.format(firstMonthRent)})',
      'Provide keys and access cards',
      'Set up AC meter reading baseline',
      'Add tenant to utility accounts',
      'Explain house rules and guidelines',
      'Provide emergency contact information',
      'Conduct unit inspection and documentation',
    ];
    
    return {
      'agreement': agreement,
      'tenant': tenant,
      'property': property,
      'unit': unit,
      'totalInitialPayment': totalInitialPayment,
      'checklist': checklist,
      'electricityProvider': electricityProvider,
      'waterProvider': waterProvider,
      'estimatedUtilityCosts': _estimateUtilityCosts(property, unit),
    };
  }
  
  /// Estimate utility costs for new tenant
  static Map<String, double> _estimateUtilityCosts(Property property, RentalUnit unit) {
    Map<String, double> estimates = {};
    
    // Electricity estimate based on AC usage
    if (unit.hasAirCon) {
      double estimatedKWh = unit.squareFeet > 0 
          ? unit.squareFeet * 0.5 // Rough estimate: 0.5 kWh per sq ft
          : 150; // Default estimate for AC room
      
      UtilityProvider? electricityProvider = property.electricityProvider;
      if (electricityProvider != null) {
        if (electricityProvider.shortName == 'TNB') {
          estimates['electricity'] = estimatedKWh * 0.45; // Rough TNB rate including all charges
        } else if (electricityProvider.shortName == 'SESB') {
          estimates['electricity'] = estimatedKWh * 0.35; // Rough SESB rate
        } else if (electricityProvider.shortName == 'SEB') {
          estimates['electricity'] = estimatedKWh * 0.35; // Rough SEB rate
        }
      }
    }
    
    // Water estimate
    estimates['water'] = 25.0; // Rough estimate for individual usage
    
    // Total shared utilities estimate (rent portion)
    estimates['sharedUtilities'] = 50.0; // Common area electricity, internet, etc.
    
    return estimates;
  }
  
  // Financial Reporting
  
  /// Generate financial report for property portfolio
  static Map<String, dynamic> generateFinancialReport({
    required List<Property> properties,
    required Map<String, List<RentalAgreement>> agreementsByProperty,
    required Map<String, List<Expense>> expensesByProperty,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    double totalRentIncome = 0.0;
    double totalExpenses = 0.0;
    Map<String, double> incomeByProperty = {};
    Map<String, double> expensesByPropertyMap = {};
    
    for (Property property in properties) {
      List<RentalAgreement> propertyAgreements = agreementsByProperty[property.id] ?? [];
      List<Expense> propertyExpenses = expensesByProperty[property.id] ?? [];
      
      // Calculate rental income for period
      double propertyIncome = 0.0;
      for (RentalAgreement agreement in propertyAgreements) {
        if (agreement.isActive && 
            agreement.startDate.isBefore(endDate) && 
            agreement.endDate.isAfter(startDate)) {
          
          // Calculate overlapping months
          DateTime periodStart = agreement.startDate.isBefore(startDate) ? startDate : agreement.startDate;
          DateTime periodEnd = agreement.endDate.isAfter(endDate) ? endDate : agreement.endDate;
          int months = ((periodEnd.difference(periodStart).inDays) / 30).ceil();
          
          propertyIncome += agreement.monthlyRent * months;
        }
      }
      
      // Calculate expenses for period
      double propertyExpenseTotal = propertyExpenses
          .where((e) {
                DateTime expenseDate = DateTime(e.year, e.month);
                return expenseDate.isAfter(startDate.subtract(const Duration(days: 31))) && 
                       expenseDate.isBefore(endDate.add(const Duration(days: 31)));
              })
          .fold(0.0, (sum, e) => sum + e.totalNonElectricityExpenses);
      
      incomeByProperty[property.name] = propertyIncome;
      expensesByPropertyMap[property.name] = propertyExpenseTotal;
      totalRentIncome += propertyIncome;
      totalExpenses += propertyExpenseTotal;
    }
    
    double netIncome = totalRentIncome - totalExpenses;
    double profitMargin = totalRentIncome > 0 ? (netIncome / totalRentIncome) * 100 : 0.0;
    
    return {
      'period': {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
      'summary': {
        'totalRentIncome': totalRentIncome,
        'totalExpenses': totalExpenses,
        'netIncome': netIncome,
        'profitMargin': profitMargin,
      },
      'incomeByProperty': incomeByProperty,
      'expensesByProperty': expensesByPropertyMap,
      'totalProperties': properties.length,
      'averageIncomePerProperty': properties.isNotEmpty ? totalRentIncome / properties.length : 0.0,
    };
  }
  
  // Maintenance and Operations
  
  /// Get maintenance schedule and reminders
  static List<Map<String, dynamic>> getMaintenanceSchedule(
    List<Property> properties,
    List<RentalUnit> allUnits,
    List<RentalAgreement> allAgreements,
  ) {
    List<Map<String, dynamic>> schedule = [];
    
    for (Property property in properties) {
      List<RentalUnit> propertyUnits = allUnits.where((u) => u.propertyId == property.id).toList();
      List<RentalAgreement> propertyAgreements = allAgreements
          .where((a) => a.propertyId == property.id)
          .toList();
      
      // Check for expiring agreements requiring unit turnaround
      for (RentalAgreement agreement in propertyAgreements) {
        if (agreement.daysUntilExpiry <= 14 && agreement.daysUntilExpiry > 0) {
          RentalUnit? unit = propertyUnits
              .where((u) => u.id == agreement.rentalUnitId)
              .firstOrNull;
          
          if (unit != null) {
            schedule.add({
              'type': 'unit_turnaround',
              'priority': 'high',
              'dueDate': agreement.endDate,
              'propertyName': property.name,
              'unitName': unit.name,
              'description': 'Prepare unit for new tenant',
              'tasks': [
                'Deep cleaning',
                'Maintenance check',
                'Repair any damages',
                'Reset AC meter readings',
                'Update unit photos',
              ],
            });
          }
        }
      }
      
      // Regular maintenance reminders
      schedule.add({
        'type': 'regular_inspection',
        'priority': 'medium',
        'dueDate': DateTime.now().add(const Duration(days: 30)),
        'propertyName': property.name,
        'description': 'Monthly property inspection',
        'tasks': [
          'Check common areas',
          'Inspect utilities',
          'Review safety equipment',
          'Collect tenant feedback',
        ],
      });
    }
    
    return schedule..sort((a, b) => 
        (a['dueDate'] as DateTime).compareTo(b['dueDate'] as DateTime));
  }
}

extension PropertyListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}