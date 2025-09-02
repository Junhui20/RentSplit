import 'package:uuid/uuid.dart';

class TNBElectricityBill {
  final String id;
  final String expenseId;
  final double totalKWhUsage;
  final double energyCharge;
  final double capacityCharge;
  final double networkCharge;
  final double retailCharge;
  final double eeIncentive;
  final double kwtbbTax;
  final double sstTax;
  final double totalAmount;
  final DateTime createdAt;

  TNBElectricityBill({
    String? id,
    required this.expenseId,
    required this.totalKWhUsage,
    this.energyCharge = 0.0,
    this.capacityCharge = 0.0,
    this.networkCharge = 0.0,
    this.retailCharge = 0.0,
    this.eeIncentive = 0.0,
    this.kwtbbTax = 0.0,
    this.sstTax = 0.0,
    this.totalAmount = 0.0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // TNB Rate Constants (as of July 2024)
  static const double energyRateBelow1500 = 0.2703; // RM per kWh
  static const double energyRateAbove1500 = 0.3703; // RM per kWh
  static const double capacityRate = 0.0455; // RM per kWh
  static const double networkRate = 0.1285; // RM per kWh
  static const double retailChargeAmount = 10.0; // RM per month
  static const double kwtbbTaxRate = 0.016; // 1.6%
  static const double sstTaxRate = 0.08; // 8%

  // Usage thresholds
  static const double retailChargeExemptionThreshold = 600.0; // kWh
  static const double kwtbbTaxExemptionThreshold = 300.0; // kWh
  static const double sstTaxThreshold = 600.0; // kWh
  static const double eeIncentiveThreshold = 1000.0; // kWh

  // Energy Efficiency Incentive rates (discounts)
  static const Map<int, double> eeIncentiveRates = {
    200: -0.250,   // 1-200 kWh: -RM 0.250/kWh
    300: -0.200,   // 201-300 kWh: -RM 0.200/kWh
    400: -0.150,   // 301-400 kWh: -RM 0.150/kWh
    500: -0.100,   // 401-500 kWh: -RM 0.100/kWh
    600: -0.075,   // 501-600 kWh: -RM 0.075/kWh
    700: -0.050,   // 601-700 kWh: -RM 0.050/kWh
    750: -0.045,   // 701-750 kWh: -RM 0.045/kWh
    800: -0.040,   // 751-800 kWh: -RM 0.040/kWh
    850: -0.035,   // 801-850 kWh: -RM 0.035/kWh
    900: -0.030,   // 851-900 kWh: -RM 0.030/kWh
    950: -0.025,   // 901-950 kWh: -RM 0.025/kWh
    1000: -0.020,  // 951-1000 kWh: -RM 0.020/kWh
  };

  // Calculate TNB bill based on usage
  static TNBElectricityBill calculateFromUsage({
    required String expenseId,
    required double totalKWhUsage,
  }) {
    // Calculate Energy Charge
    double energyCharge = 0.0;
    if (totalKWhUsage <= 1500) {
      energyCharge = totalKWhUsage * energyRateBelow1500;
    } else {
      energyCharge = (1500 * energyRateBelow1500) + 
                    ((totalKWhUsage - 1500) * energyRateAbove1500);
    }

    // Calculate Capacity Charge
    double capacityCharge = totalKWhUsage * capacityRate;

    // Calculate Network Charge
    double networkCharge = totalKWhUsage * networkRate;

    // Calculate Retail Charge
    double retailCharge = totalKWhUsage <= retailChargeExemptionThreshold ? 0.0 : retailChargeAmount;

    // Calculate Energy Efficiency Incentive
    double eeIncentive = _calculateEEIncentive(totalKWhUsage);

    // Calculate subtotal before taxes
    double subtotal = energyCharge + capacityCharge + networkCharge + retailCharge + eeIncentive;

    // Calculate KWTBB Tax (1.6% if usage > 300kWh)
    double kwtbbTax = totalKWhUsage <= kwtbbTaxExemptionThreshold ? 0.0 : (subtotal * kwtbbTaxRate);

    // Calculate SST Tax (8% only on usage > 600kWh portion)
    double sstTax = 0.0;
    if (totalKWhUsage > sstTaxThreshold) {
      double sstTaxableUsage = totalKWhUsage - sstTaxThreshold;
      double sstTaxableAmount = (sstTaxableUsage * energyRateBelow1500) + 
                               (sstTaxableUsage * capacityRate) + 
                               (sstTaxableUsage * networkRate);
      sstTax = sstTaxableAmount * sstTaxRate;
    }

    // Calculate total amount
    double totalAmount = subtotal + kwtbbTax + sstTax;

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
      totalAmount: totalAmount,
    );
  }

  // Calculate Energy Efficiency Incentive
  static double _calculateEEIncentive(double usage) {
    if (usage > eeIncentiveThreshold) return 0.0;

    double incentive = 0.0;
    double remainingUsage = usage;

    for (var entry in eeIncentiveRates.entries) {
      int threshold = entry.key;
      double rate = entry.value;
      
      if (remainingUsage <= 0) break;

      double previousThreshold = threshold == 200 ? 0 : 
                                threshold == 300 ? 200 :
                                threshold == 400 ? 300 :
                                threshold == 500 ? 400 :
                                threshold == 600 ? 500 :
                                threshold == 700 ? 600 :
                                threshold == 750 ? 700 :
                                threshold == 800 ? 750 :
                                threshold == 850 ? 800 :
                                threshold == 900 ? 850 :
                                threshold == 950 ? 900 : 950;

      double tierUsage = (threshold - previousThreshold).toDouble();
      double applicableUsage = remainingUsage > tierUsage ? tierUsage : remainingUsage;
      
      incentive += applicableUsage * rate;
      remainingUsage -= applicableUsage;
    }

    return incentive;
  }

  // Get breakdown components
  Map<String, double> get breakdown {
    return {
      'Energy Charge': energyCharge,
      'Capacity Charge': capacityCharge,
      'Network Charge': networkCharge,
      'Retail Charge': retailCharge,
      'EE Incentive': eeIncentive,
      'KWTBB Tax': kwtbbTax,
      'SST Tax': sstTax,
      'Total Amount': totalAmount,
    };
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_id': expenseId,
      'total_kwh_usage': totalKWhUsage,
      'energy_charge': energyCharge,
      'capacity_charge': capacityCharge,
      'network_charge': networkCharge,
      'retail_charge': retailCharge,
      'ee_incentive': eeIncentive,
      'kwtbb_tax': kwtbbTax,
      'sst_tax': sstTax,
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create from Map (database)
  factory TNBElectricityBill.fromMap(Map<String, dynamic> map) {
    return TNBElectricityBill(
      id: map['id'] as String,
      expenseId: map['expense_id'] as String,
      totalKWhUsage: (map['total_kwh_usage'] as num).toDouble(),
      energyCharge: (map['energy_charge'] as num).toDouble(),
      capacityCharge: (map['capacity_charge'] as num).toDouble(),
      networkCharge: (map['network_charge'] as num).toDouble(),
      retailCharge: (map['retail_charge'] as num).toDouble(),
      eeIncentive: (map['ee_incentive'] as num).toDouble(),
      kwtbbTax: (map['kwtbb_tax'] as num).toDouble(),
      sstTax: (map['sst_tax'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Create a copy with updated values
  TNBElectricityBill copyWith({
    String? id,
    String? expenseId,
    double? totalKWhUsage,
    double? energyCharge,
    double? capacityCharge,
    double? networkCharge,
    double? retailCharge,
    double? eeIncentive,
    double? kwtbbTax,
    double? sstTax,
    double? totalAmount,
  }) {
    return TNBElectricityBill(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      totalKWhUsage: totalKWhUsage ?? this.totalKWhUsage,
      energyCharge: energyCharge ?? this.energyCharge,
      capacityCharge: capacityCharge ?? this.capacityCharge,
      networkCharge: networkCharge ?? this.networkCharge,
      retailCharge: retailCharge ?? this.retailCharge,
      eeIncentive: eeIncentive ?? this.eeIncentive,
      kwtbbTax: kwtbbTax ?? this.kwtbbTax,
      sstTax: sstTax ?? this.sstTax,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt,
    );
  }

  @override
  String toString() {
    return 'TNBElectricityBill{totalAmount: ${totalAmount.toStringAsFixed(2)}RM, usage: ${totalKWhUsage}kWh}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TNBElectricityBill && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}