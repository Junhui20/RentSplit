import 'package:uuid/uuid.dart';
import 'utility_provider.dart';

class UtilityBill {
  final String id;
  final String expenseId;
  final String providerId;
  final UtilityType utilityType;
  final double totalUsage; // kWh for electricity, m³ for water
  final String usageUnit; // "kWh", "m³", etc.
  final Map<String, double> charges; // Breakdown of charges
  final double totalAmount;
  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;
  final DateTime dueDate;
  final DateTime createdAt;
  final Map<String, dynamic> additionalData; // Provider-specific data

  UtilityBill({
    String? id,
    required this.expenseId,
    required this.providerId,
    required this.utilityType,
    required this.totalUsage,
    required this.usageUnit,
    this.charges = const {},
    required this.totalAmount,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.dueDate,
    this.additionalData = const {},
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // Calculate bill from usage and provider rates
  static UtilityBill calculateFromUsage({
    required String expenseId,
    required UtilityProvider provider,
    required double totalUsage,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
    required DateTime dueDate,
    Map<String, dynamic> additionalData = const {},
  }) {
    Map<String, double> charges = {};
    double totalAmount = 0.0;

    switch (provider.type) {
      case UtilityType.electricity:
        final result = _calculateElectricityCharges(provider, totalUsage);
        charges = result['charges'] as Map<String, double>;
        totalAmount = result['total'] as double;
        break;
        
      case UtilityType.water:
        final result = _calculateWaterCharges(provider, totalUsage);
        charges = result['charges'] as Map<String, double>;
        totalAmount = result['total'] as double;
        break;
        
      case UtilityType.gas:
        // Gas calculation can be added here
        charges['gas_usage'] = totalUsage * 2.0; // Example rate
        totalAmount = charges['gas_usage']!;
        break;

      case UtilityType.internet:
        // Internet is typically a fixed monthly fee
        charges['monthly_fee'] = provider.getRate('monthly_fee') ?? 149.0;
        totalAmount = charges['monthly_fee']!;
        break;

      case UtilityType.sewerage:
        // Sewerage is typically based on water usage
        charges['sewerage_fee'] = totalUsage * 0.50; // Example rate per m³
        totalAmount = charges['sewerage_fee']!;
        break;

      case UtilityType.waste:
        // Waste management is typically a fixed monthly fee
        charges['waste_collection'] = 15.0; // Example fixed rate
        totalAmount = charges['waste_collection']!;
        break;
    }

    return UtilityBill(
      expenseId: expenseId,
      providerId: provider.id,
      utilityType: provider.type,
      totalUsage: totalUsage,
      usageUnit: _getUsageUnit(provider.type),
      charges: charges,
      totalAmount: totalAmount,
      billingPeriodStart: billingPeriodStart,
      billingPeriodEnd: billingPeriodEnd,
      dueDate: dueDate,
      additionalData: additionalData,
    );
  }

  // Calculate electricity charges based on provider
  static Map<String, dynamic> _calculateElectricityCharges(
    UtilityProvider provider,
    double usage,
  ) {
    Map<String, double> charges = {};
    double total = 0.0;

    if (provider.shortName == 'TNB') {
      // TNB calculation (Peninsular Malaysia)
      double energyCharge = 0.0;
      if (usage <= 1500) {
        energyCharge = usage * (provider.getRate('energy_charge_below_1500') ?? 0.2703);
      } else {
        energyCharge = (1500 * (provider.getRate('energy_charge_below_1500') ?? 0.2703)) +
                      ((usage - 1500) * (provider.getRate('energy_charge_above_1500') ?? 0.3703));
      }
      
      charges['Energy Charge'] = energyCharge;
      charges['Capacity Charge'] = usage * (provider.getRate('capacity_charge') ?? 0.0455);
      charges['Network Charge'] = usage * (provider.getRate('network_charge') ?? 0.1285);
      
      if (usage > 600) {
        charges['Retail Charge'] = provider.getRate('retail_charge') ?? 10.0;
      }
      
      // Calculate Energy Efficiency Incentive
      double eeIncentive = _calculateTNBEEIncentive(usage);
      if (eeIncentive != 0) {
        charges['EE Incentive'] = eeIncentive;
      }
      
      // Calculate subtotal before taxes
      double subtotal = charges.values.reduce((a, b) => a + b);
      
      // KWTBB Tax
      if (usage > 300) {
        charges['KWTBB Tax'] = subtotal * (provider.getRate('kwtbb_tax_rate') ?? 0.016);
      }
      
      // SST Tax
      if (usage > 600) {
        double sstTaxableUsage = usage - 600;
        double sstTaxableAmount = sstTaxableUsage * 0.2703; // Simplified
        charges['SST Tax'] = sstTaxableAmount * (provider.getRate('sst_tax_rate') ?? 0.08);
      }
      
    } else if (provider.shortName == 'SESB') {
      // SESB calculation (Sabah)
      if (usage <= 200) {
        charges['Domestic 1-200 kWh'] = usage * (provider.getRate('domestic_rate_1_200') ?? 0.21);
      } else if (usage <= 300) {
        charges['Domestic 1-200 kWh'] = 200 * 0.21;
        charges['Domestic 201-300 kWh'] = (usage - 200) * (provider.getRate('domestic_rate_201_300') ?? 0.33);
      } else if (usage <= 600) {
        charges['Domestic 1-200 kWh'] = 200 * 0.21;
        charges['Domestic 201-300 kWh'] = 100 * 0.33;
        charges['Domestic 301-600 kWh'] = (usage - 300) * (provider.getRate('domestic_rate_301_600') ?? 0.52);
      } else {
        charges['Domestic 1-200 kWh'] = 200 * 0.21;
        charges['Domestic 201-300 kWh'] = 100 * 0.33;
        charges['Domestic 301-600 kWh'] = 300 * 0.52;
        charges['Domestic >600 kWh'] = (usage - 600) * (provider.getRate('domestic_rate_above_600') ?? 0.54);
      }
      
    } else if (provider.shortName == 'SEB') {
      // SEB calculation (Sarawak)
      if (usage <= 200) {
        charges['Domestic 1-200 kWh'] = usage * (provider.getRate('domestic_rate_1_200') ?? 0.205);
      } else if (usage <= 400) {
        charges['Domestic 1-200 kWh'] = 200 * 0.205;
        charges['Domestic 201-400 kWh'] = (usage - 200) * (provider.getRate('domestic_rate_201_400') ?? 0.334);
      } else {
        charges['Domestic 1-200 kWh'] = 200 * 0.205;
        charges['Domestic 201-400 kWh'] = 200 * 0.334;
        charges['Domestic >400 kWh'] = (usage - 400) * (provider.getRate('domestic_rate_above_400') ?? 0.515);
      }
    }

    total = charges.values.reduce((a, b) => a + b);
    return {'charges': charges, 'total': total};
  }

  // Calculate water charges based on provider
  static Map<String, dynamic> _calculateWaterCharges(
    UtilityProvider provider,
    double usage,
  ) {
    Map<String, double> charges = {};
    double total = 0.0;

    if (provider.shortName == 'Air Selangor') {
      if (usage <= 20) {
        charges['Free Allocation (1-20 m³)'] = 0.0;
      } else if (usage <= 35) {
        charges['Free Allocation (1-20 m³)'] = 0.0;
        charges['Usage 21-35 m³'] = (usage - 20) * (provider.getRate('domestic_rate_21_35') ?? 0.57);
      } else {
        charges['Free Allocation (1-20 m³)'] = 0.0;
        charges['Usage 21-35 m³'] = 15 * 0.57;
        charges['Usage >35 m³'] = (usage - 35) * (provider.getRate('domestic_rate_36_above') ?? 1.24);
      }
    } else if (provider.shortName == 'PBAPP') {
      if (usage <= 20) {
        charges['Free Allocation (1-20 m³)'] = 0.0;
      } else if (usage <= 40) {
        charges['Free Allocation (1-20 m³)'] = 0.0;
        charges['Usage 21-40 m³'] = (usage - 20) * (provider.getRate('domestic_rate_21_40') ?? 0.28);
      } else {
        charges['Free Allocation (1-20 m³)'] = 0.0;
        charges['Usage 21-40 m³'] = 20 * 0.28;
        charges['Usage >40 m³'] = (usage - 40) * (provider.getRate('domestic_rate_above_40') ?? 0.56);
      }
    } else if (provider.shortName == 'SAJ') {
      if (usage <= 20) {
        charges['Free Allocation (1-20 m³)'] = 0.0;
      } else if (usage <= 40) {
        charges['Free Allocation (1-20 m³)'] = 0.0;
        charges['Usage 21-40 m³'] = (usage - 20) * (provider.getRate('domestic_rate_21_40') ?? 0.64);
      } else {
        charges['Free Allocation (1-20 m³)'] = 0.0;
        charges['Usage 21-40 m³'] = 20 * 0.64;
        charges['Usage >40 m³'] = (usage - 40) * (provider.getRate('domestic_rate_above_40') ?? 1.17);
      }
    }

    total = charges.values.fold(0.0, (a, b) => a + b);
    return {'charges': charges, 'total': total};
  }

  // TNB Energy Efficiency Incentive calculation
  static double _calculateTNBEEIncentive(double usage) {
    if (usage > 1000) return 0.0;

    final incentiveRates = {
      200: -0.250,
      300: -0.200,
      400: -0.150,
      500: -0.100,
      600: -0.075,
      700: -0.050,
      750: -0.045,
      800: -0.040,
      850: -0.035,
      900: -0.030,
      950: -0.025,
      1000: -0.020,
    };

    double incentive = 0.0;
    double remainingUsage = usage;
    int previousThreshold = 0;

    for (var entry in incentiveRates.entries) {
      int threshold = entry.key;
      double rate = entry.value;
      
      if (remainingUsage <= 0) break;

      double tierUsage = (threshold - previousThreshold).toDouble();
      double applicableUsage = remainingUsage > tierUsage ? tierUsage : remainingUsage;
      
      incentive += applicableUsage * rate;
      remainingUsage -= applicableUsage;
      previousThreshold = threshold;
    }

    return incentive;
  }

  static String _getUsageUnit(UtilityType type) {
    switch (type) {
      case UtilityType.electricity:
        return 'kWh';
      case UtilityType.water:
        return 'm³';
      case UtilityType.gas:
        return 'm³';
      case UtilityType.internet:
        return 'Mbps';
      case UtilityType.sewerage:
        return 'm³';
      case UtilityType.waste:
        return 'kg';
    }
  }

  // Get breakdown components
  Map<String, double> get breakdown => Map.from(charges)..['Total'] = totalAmount;

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_id': expenseId,
      'provider_id': providerId,
      'utility_type': utilityType.name,
      'total_usage': totalUsage,
      'usage_unit': usageUnit,
      'charges': charges.toString(), // JSON string
      'total_amount': totalAmount,
      'billing_period_start': billingPeriodStart.toIso8601String(),
      'billing_period_end': billingPeriodEnd.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'additional_data': additionalData.toString(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create from Map (database)
  factory UtilityBill.fromMap(Map<String, dynamic> map) {
    return UtilityBill(
      id: map['id'] as String,
      expenseId: map['expense_id'] as String,
      providerId: map['provider_id'] as String,
      utilityType: UtilityType.values.firstWhere((t) => t.name == map['utility_type']),
      totalUsage: (map['total_usage'] as num).toDouble(),
      usageUnit: map['usage_unit'] as String,
      charges: {}, // Parse JSON string if needed
      totalAmount: (map['total_amount'] as num).toDouble(),
      billingPeriodStart: DateTime.parse(map['billing_period_start'] as String),
      billingPeriodEnd: DateTime.parse(map['billing_period_end'] as String),
      dueDate: DateTime.parse(map['due_date'] as String),
      additionalData: {}, // Parse JSON string if needed
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  String toString() {
    return 'UtilityBill{provider: $providerId, type: ${utilityType.name}, amount: ${totalAmount.toStringAsFixed(2)}RM, usage: $totalUsage$usageUnit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UtilityBill && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}