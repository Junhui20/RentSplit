import 'package:uuid/uuid.dart';

class Expense {
  final String id;
  final String propertyId;
  final int month;
  final int year;
  final double baseRent;
  final double internetFee;
  final double waterBill;
  final double miscellaneousExpenses;
  final bool splitMiscellaneous;
  final double totalKWhUsage;
  final double totalACKWhUsage;
  final double electricPricePerKWh;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    String? id,
    required this.propertyId,
    required this.month,
    required this.year,
    this.baseRent = 0.0,
    this.internetFee = 0.0,
    this.waterBill = 0.0,
    this.miscellaneousExpenses = 0.0,
    this.splitMiscellaneous = true,
    this.totalKWhUsage = 0.0,
    this.totalACKWhUsage = 0.0,
    this.electricPricePerKWh = 0.218,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Calculate common area electricity usage
  double get commonKWhUsage {
    return totalKWhUsage - totalACKWhUsage;
  }

  // Get total non-electricity expenses
  double get totalNonElectricityExpenses {
    return baseRent + internetFee + waterBill + 
           (splitMiscellaneous ? miscellaneousExpenses : 0.0);
  }

  // Get month name
  String get monthName {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }

  // Get period description
  String get periodDescription {
    return '$monthName $year';
  }

  // Create a copy with updated values
  Expense copyWith({
    String? propertyId,
    int? month,
    int? year,
    double? baseRent,
    double? internetFee,
    double? waterBill,
    double? miscellaneousExpenses,
    bool? splitMiscellaneous,
    double? totalKWhUsage,
    double? totalACKWhUsage,
    double? electricPricePerKWh,
    String? notes,
  }) {
    return Expense(
      id: id,
      propertyId: propertyId ?? this.propertyId,
      month: month ?? this.month,
      year: year ?? this.year,
      baseRent: baseRent ?? this.baseRent,
      internetFee: internetFee ?? this.internetFee,
      waterBill: waterBill ?? this.waterBill,
      miscellaneousExpenses: miscellaneousExpenses ?? this.miscellaneousExpenses,
      splitMiscellaneous: splitMiscellaneous ?? this.splitMiscellaneous,
      totalKWhUsage: totalKWhUsage ?? this.totalKWhUsage,
      totalACKWhUsage: totalACKWhUsage ?? this.totalACKWhUsage,
      electricPricePerKWh: electricPricePerKWh ?? this.electricPricePerKWh,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'property_id': propertyId,
      'month': month,
      'year': year,
      'base_rent': baseRent,
      'internet_fee': internetFee,
      'water_bill': waterBill,
      'miscellaneous_expenses': miscellaneousExpenses,
      'split_miscellaneous': splitMiscellaneous ? 1 : 0,
      'total_kwh_usage': totalKWhUsage,
      'total_ac_kwh_usage': totalACKWhUsage,
      'electric_price_per_kwh': electricPricePerKWh,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create from Map (database)
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      propertyId: map['property_id'] as String,
      month: map['month'] as int,
      year: map['year'] as int,
      baseRent: (map['base_rent'] as num?)?.toDouble() ?? 0.0,
      internetFee: (map['internet_fee'] as num?)?.toDouble() ?? 0.0,
      waterBill: (map['water_bill'] as num?)?.toDouble() ?? 0.0,
      miscellaneousExpenses: (map['miscellaneous_expenses'] as num?)?.toDouble() ?? 0.0,
      splitMiscellaneous: (map['split_miscellaneous'] as int?) == 1,
      totalKWhUsage: (map['total_kwh_usage'] as num?)?.toDouble() ?? 0.0,
      totalACKWhUsage: (map['total_ac_kwh_usage'] as num?)?.toDouble() ?? 0.0,
      electricPricePerKWh: (map['electric_price_per_kwh'] as num?)?.toDouble() ?? 0.218,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() {
    return 'Expense{id: $id, period: $periodDescription, totalExpenses: ${totalNonElectricityExpenses}RM, electricity: ${totalKWhUsage}kWh}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Expense && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}