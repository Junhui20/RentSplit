import 'package:uuid/uuid.dart';

enum RentalAgreementStatus {
  draft,
  active,
  expired,
  terminated,
  renewed,
}

enum PaymentFrequency {
  monthly,
  quarterly,
  semiAnnual,
  annual,
}

extension RentalAgreementStatusExtension on RentalAgreementStatus {
  String get displayName {
    switch (this) {
      case RentalAgreementStatus.draft:
        return 'Draft';
      case RentalAgreementStatus.active:
        return 'Active';
      case RentalAgreementStatus.expired:
        return 'Expired';
      case RentalAgreementStatus.terminated:
        return 'Terminated';
      case RentalAgreementStatus.renewed:
        return 'Renewed';
    }
  }

  String get value => name;

  static RentalAgreementStatus fromValue(String value) {
    return RentalAgreementStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => RentalAgreementStatus.draft,
    );
  }
}

extension PaymentFrequencyExtension on PaymentFrequency {
  String get displayName {
    switch (this) {
      case PaymentFrequency.monthly:
        return 'Monthly';
      case PaymentFrequency.quarterly:
        return 'Quarterly';
      case PaymentFrequency.semiAnnual:
        return 'Semi-Annual';
      case PaymentFrequency.annual:
        return 'Annual';
    }
  }

  String get value => name;

  int get monthsMultiplier {
    switch (this) {
      case PaymentFrequency.monthly:
        return 1;
      case PaymentFrequency.quarterly:
        return 3;
      case PaymentFrequency.semiAnnual:
        return 6;
      case PaymentFrequency.annual:
        return 12;
    }
  }

  static PaymentFrequency fromValue(String value) {
    return PaymentFrequency.values.firstWhere(
      (freq) => freq.value == value,
      orElse: () => PaymentFrequency.monthly,
    );
  }
}

class RentalAgreement {
  final String id;
  final String propertyId;
  final String rentalUnitId;
  final String tenantId;
  final RentalAgreementStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final double monthlyRent;
  final PaymentFrequency paymentFrequency;
  final double securityDeposit;
  final double utilityDeposit;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Payment terms
  final int paymentDueDay; // Day of month payment is due (e.g., 1 for 1st of month)
  final int gracePeriodDays; // Days after due date before late fee
  final double lateFeeAmount;
  final double lateFeePercentage;
  
  // Utility arrangements
  final bool includesElectricity;
  final bool includesWater;
  final bool includesGas;
  final bool includesInternet;
  final double electricityAllowance; // Free kWh per month
  final double waterAllowance; // Free m³ per month
  
  // Terms and conditions
  final String? specialTerms;
  final String? notes;
  final List<String> includedServices;
  final List<String> restrictions;
  
  // Document references
  final String? contractDocumentUrl;
  final List<String> attachmentUrls;
  
  // Renewal information
  final bool autoRenewal;
  final int renewalNoticeDays; // Days notice required for non-renewal
  final String? renewalTerms;

  RentalAgreement({
    String? id,
    required this.propertyId,
    required this.rentalUnitId,
    required this.tenantId,
    this.status = RentalAgreementStatus.draft,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    this.paymentFrequency = PaymentFrequency.monthly,
    this.securityDeposit = 0.0,
    this.utilityDeposit = 0.0,
    this.paymentDueDay = 1,
    this.gracePeriodDays = 5,
    this.lateFeeAmount = 0.0,
    this.lateFeePercentage = 0.0,
    this.includesElectricity = false,
    this.includesWater = false,
    this.includesGas = false,
    this.includesInternet = false,
    this.electricityAllowance = 0.0,
    this.waterAllowance = 0.0,
    this.specialTerms,
    this.notes,
    this.includedServices = const [],
    this.restrictions = const [],
    this.contractDocumentUrl,
    this.attachmentUrls = const [],
    this.autoRenewal = false,
    this.renewalNoticeDays = 30,
    this.renewalTerms,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Check if agreement is currently active
  bool get isActive {
    if (status != RentalAgreementStatus.active) return false;
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  // Check if agreement is expired
  bool get isExpired {
    return DateTime.now().isAfter(endDate);
  }

  // Get days until expiry
  int get daysUntilExpiry {
    if (isExpired) return 0;
    return endDate.difference(DateTime.now()).inDays;
  }

  // Get agreement duration in months
  int get durationInMonths {
    return ((endDate.difference(startDate).inDays) / 30).round();
  }

  // Get total deposit amount
  double get totalDeposit {
    return securityDeposit + utilityDeposit;
  }

  // Get payment amount based on frequency
  double get paymentAmount {
    return monthlyRent * paymentFrequency.monthsMultiplier;
  }

  // Check if renewal notice is due
  bool get isRenewalNoticeRequired {
    if (autoRenewal) return false;
    final noticeDate = endDate.subtract(Duration(days: renewalNoticeDays));
    return DateTime.now().isAfter(noticeDate);
  }

  // Get next payment date
  DateTime getNextPaymentDate() {
    final now = DateTime.now();
    switch (paymentFrequency) {
      case PaymentFrequency.monthly:
        if (now.day <= paymentDueDay) {
          return DateTime(now.year, now.month, paymentDueDay);
        } else {
          return DateTime(now.year, now.month + 1, paymentDueDay);
        }
      case PaymentFrequency.quarterly:
        // Find next quarter
        int nextQuarter = ((now.month - 1) ~/ 3 + 1) * 3 + 1;
        if (nextQuarter > 12) {
          return DateTime(now.year + 1, 1, paymentDueDay);
        } else {
          return DateTime(now.year, nextQuarter, paymentDueDay);
        }
      case PaymentFrequency.semiAnnual:
        // Next semi-annual payment (Jan or July)
        if (now.month <= 6) {
          return DateTime(now.year, 7, paymentDueDay);
        } else {
          return DateTime(now.year + 1, 1, paymentDueDay);
        }
      case PaymentFrequency.annual:
        // Next annual payment
        return DateTime(now.year + 1, startDate.month, paymentDueDay);
    }
  }

  // Calculate late fee for overdue payment
  double calculateLateFee(DateTime paymentDate, double amount) {
    final dueDate = getNextPaymentDate();
    if (paymentDate.isBefore(dueDate.add(Duration(days: gracePeriodDays)))) {
      return 0.0; // No late fee within grace period
    }
    
    double fee = lateFeeAmount;
    if (lateFeePercentage > 0) {
      fee += amount * (lateFeePercentage / 100);
    }
    
    return fee;
  }

  // Create a copy with updated values
  RentalAgreement copyWith({
    String? propertyId,
    String? rentalUnitId,
    String? tenantId,
    RentalAgreementStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    double? monthlyRent,
    PaymentFrequency? paymentFrequency,
    double? securityDeposit,
    double? utilityDeposit,
    int? paymentDueDay,
    int? gracePeriodDays,
    double? lateFeeAmount,
    double? lateFeePercentage,
    bool? includesElectricity,
    bool? includesWater,
    bool? includesGas,
    bool? includesInternet,
    double? electricityAllowance,
    double? waterAllowance,
    String? specialTerms,
    String? notes,
    List<String>? includedServices,
    List<String>? restrictions,
    String? contractDocumentUrl,
    List<String>? attachmentUrls,
    bool? autoRenewal,
    int? renewalNoticeDays,
    String? renewalTerms,
  }) {
    return RentalAgreement(
      id: id,
      propertyId: propertyId ?? this.propertyId,
      rentalUnitId: rentalUnitId ?? this.rentalUnitId,
      tenantId: tenantId ?? this.tenantId,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      paymentFrequency: paymentFrequency ?? this.paymentFrequency,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      utilityDeposit: utilityDeposit ?? this.utilityDeposit,
      paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      lateFeeAmount: lateFeeAmount ?? this.lateFeeAmount,
      lateFeePercentage: lateFeePercentage ?? this.lateFeePercentage,
      includesElectricity: includesElectricity ?? this.includesElectricity,
      includesWater: includesWater ?? this.includesWater,
      includesGas: includesGas ?? this.includesGas,
      includesInternet: includesInternet ?? this.includesInternet,
      electricityAllowance: electricityAllowance ?? this.electricityAllowance,
      waterAllowance: waterAllowance ?? this.waterAllowance,
      specialTerms: specialTerms ?? this.specialTerms,
      notes: notes ?? this.notes,
      includedServices: includedServices ?? this.includedServices,
      restrictions: restrictions ?? this.restrictions,
      contractDocumentUrl: contractDocumentUrl ?? this.contractDocumentUrl,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      autoRenewal: autoRenewal ?? this.autoRenewal,
      renewalNoticeDays: renewalNoticeDays ?? this.renewalNoticeDays,
      renewalTerms: renewalTerms ?? this.renewalTerms,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'property_id': propertyId,
      'rental_unit_id': rentalUnitId,
      'tenant_id': tenantId,
      'status': status.value,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'monthly_rent': monthlyRent,
      'payment_frequency': paymentFrequency.value,
      'security_deposit': securityDeposit,
      'utility_deposit': utilityDeposit,
      'payment_due_day': paymentDueDay,
      'grace_period_days': gracePeriodDays,
      'late_fee_amount': lateFeeAmount,
      'late_fee_percentage': lateFeePercentage,
      'includes_electricity': includesElectricity ? 1 : 0,
      'includes_water': includesWater ? 1 : 0,
      'includes_gas': includesGas ? 1 : 0,
      'includes_internet': includesInternet ? 1 : 0,
      'electricity_allowance': electricityAllowance,
      'water_allowance': waterAllowance,
      'special_terms': specialTerms,
      'notes': notes,
      'included_services': includedServices.join(','),
      'restrictions': restrictions.join(','),
      'contract_document_url': contractDocumentUrl,
      'attachment_urls': attachmentUrls.join(','),
      'auto_renewal': autoRenewal ? 1 : 0,
      'renewal_notice_days': renewalNoticeDays,
      'renewal_terms': renewalTerms,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create from Map (database)
  factory RentalAgreement.fromMap(Map<String, dynamic> map) {
    return RentalAgreement(
      id: map['id'] as String,
      propertyId: map['property_id'] as String,
      rentalUnitId: map['rental_unit_id'] as String,
      tenantId: map['tenant_id'] as String,
      status: RentalAgreementStatusExtension.fromValue(map['status'] as String),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      monthlyRent: (map['monthly_rent'] as num).toDouble(),
      paymentFrequency: PaymentFrequencyExtension.fromValue(map['payment_frequency'] as String),
      securityDeposit: (map['security_deposit'] as num?)?.toDouble() ?? 0.0,
      utilityDeposit: (map['utility_deposit'] as num?)?.toDouble() ?? 0.0,
      paymentDueDay: map['payment_due_day'] as int? ?? 1,
      gracePeriodDays: map['grace_period_days'] as int? ?? 5,
      lateFeeAmount: (map['late_fee_amount'] as num?)?.toDouble() ?? 0.0,
      lateFeePercentage: (map['late_fee_percentage'] as num?)?.toDouble() ?? 0.0,
      includesElectricity: (map['includes_electricity'] as int?) == 1,
      includesWater: (map['includes_water'] as int?) == 1,
      includesGas: (map['includes_gas'] as int?) == 1,
      includesInternet: (map['includes_internet'] as int?) == 1,
      electricityAllowance: (map['electricity_allowance'] as num?)?.toDouble() ?? 0.0,
      waterAllowance: (map['water_allowance'] as num?)?.toDouble() ?? 0.0,
      specialTerms: map['special_terms'] as String?,
      notes: map['notes'] as String?,
      includedServices: (map['included_services'] as String?)?.split(',') ?? [],
      restrictions: (map['restrictions'] as String?)?.split(',') ?? [],
      contractDocumentUrl: map['contract_document_url'] as String?,
      attachmentUrls: (map['attachment_urls'] as String?)?.split(',') ?? [],
      autoRenewal: (map['auto_renewal'] as int?) == 1,
      renewalNoticeDays: map['renewal_notice_days'] as int? ?? 30,
      renewalTerms: map['renewal_terms'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() {
    return 'RentalAgreement{tenant: $tenantId, rent: ${monthlyRent}RM, period: ${startDate.year}-${startDate.month} to ${endDate.year}-${endDate.month}, status: ${status.displayName}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RentalAgreement && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}