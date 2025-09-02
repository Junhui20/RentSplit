import 'package:uuid/uuid.dart';

enum RentalUnitType {
  unit,
  masterBedroom,
  singleRoom,
  sharedRoom,
  studio,
  entire,
}

enum RentalUnitStatus {
  available,
  occupied,
  maintenance,
  reserved,
}

extension RentalUnitTypeExtension on RentalUnitType {
  String get displayName {
    switch (this) {
      case RentalUnitType.unit:
        return 'Unit';
      case RentalUnitType.masterBedroom:
        return 'Master Bedroom';
      case RentalUnitType.singleRoom:
        return 'Single Room';
      case RentalUnitType.sharedRoom:
        return 'Shared Room';
      case RentalUnitType.studio:
        return 'Studio';
      case RentalUnitType.entire:
        return 'Entire Property';
    }
  }

  String get value => name;

  static RentalUnitType fromValue(String value) {
    return RentalUnitType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => RentalUnitType.unit,
    );
  }
}

extension RentalUnitStatusExtension on RentalUnitStatus {
  String get displayName {
    switch (this) {
      case RentalUnitStatus.available:
        return 'Available';
      case RentalUnitStatus.occupied:
        return 'Occupied';
      case RentalUnitStatus.maintenance:
        return 'Maintenance';
      case RentalUnitStatus.reserved:
        return 'Reserved';
    }
  }

  String get value => name;

  static RentalUnitStatus fromValue(String value) {
    return RentalUnitStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => RentalUnitStatus.available,
    );
  }
}

class RentalUnit {
  final String id;
  final String propertyId;
  final String unitNumber; // e.g., "Room 1", "A-101", "Master Bedroom"
  final String name; // Display name for the unit
  final RentalUnitType unitType;
  final RentalUnitStatus status;
  final double monthlyRent;
  final double? deposit; // Security deposit
  final double? utilityDeposit; // Separate utility deposit
  final double squareFeet;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Unit amenities and features
  final bool hasAirCon;
  final bool hasPrivateBathroom;
  final bool hasFurniture;
  final bool hasWindow;
  final bool hasBalcony;
  
  // Utility meter information
  final String? electricityMeterNumber;
  final String? waterMeterNumber;
  final bool hasIndividualMeter;
  
  // Tenant capacity
  final int maxOccupancy;
  final int currentOccupancy;
  
  // Notes and description
  final String? description;
  final String? notes;
  final List<String> amenities;
  final List<String> imageUrls;
  
  // Availability dates
  final DateTime? availableFrom;
  final DateTime? availableTo;

  RentalUnit({
    String? id,
    required this.propertyId,
    required this.unitNumber,
    required this.name,
    this.unitType = RentalUnitType.unit,
    this.status = RentalUnitStatus.available,
    required this.monthlyRent,
    this.deposit,
    this.utilityDeposit,
    this.squareFeet = 0.0,
    this.isActive = true,
    this.hasAirCon = false,
    this.hasPrivateBathroom = false,
    this.hasFurniture = false,
    this.hasWindow = true,
    this.hasBalcony = false,
    this.electricityMeterNumber,
    this.waterMeterNumber,
    this.hasIndividualMeter = false,
    this.maxOccupancy = 1,
    this.currentOccupancy = 0,
    this.description,
    this.notes,
    this.amenities = const [],
    this.imageUrls = const [],
    this.availableFrom,
    this.availableTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Check if unit is available for rent
  bool get isAvailable {
    if (!isActive || status != RentalUnitStatus.available) return false;
    if (currentOccupancy >= maxOccupancy) return false;
    
    final now = DateTime.now();
    if (availableFrom != null && now.isBefore(availableFrom!)) return false;
    if (availableTo != null && now.isAfter(availableTo!)) return false;
    
    return true;
  }

  // Check if unit has space for more tenants
  bool get hasCapacity => currentOccupancy < maxOccupancy;

  // Get occupancy rate as percentage
  double get occupancyRate => maxOccupancy > 0 ? (currentOccupancy / maxOccupancy) * 100 : 0.0;

  // Get unit full name with property context
  String getFullName(String propertyName) {
    return '$propertyName - $name';
  }

  // Get deposit total
  double get totalDeposit {
    return (deposit ?? 0.0) + (utilityDeposit ?? 0.0);
  }

  // Get amenities list as string
  String get amenitiesDisplay {
    List<String> allAmenities = List.from(amenities);
    
    if (hasAirCon) allAmenities.add('Air Conditioning');
    if (hasPrivateBathroom) allAmenities.add('Private Bathroom');
    if (hasFurniture) allAmenities.add('Furnished');
    if (hasWindow) allAmenities.add('Window');
    if (hasBalcony) allAmenities.add('Balcony');
    if (hasIndividualMeter) allAmenities.add('Individual Meter');
    
    return allAmenities.join(', ');
  }

  // Create a copy with updated values
  RentalUnit copyWith({
    String? propertyId,
    String? unitNumber,
    String? name,
    RentalUnitType? unitType,
    RentalUnitStatus? status,
    double? monthlyRent,
    double? deposit,
    double? utilityDeposit,
    double? squareFeet,
    bool? isActive,
    bool? hasAirCon,
    bool? hasPrivateBathroom,
    bool? hasFurniture,
    bool? hasWindow,
    bool? hasBalcony,
    String? electricityMeterNumber,
    String? waterMeterNumber,
    bool? hasIndividualMeter,
    int? maxOccupancy,
    int? currentOccupancy,
    String? description,
    String? notes,
    List<String>? amenities,
    List<String>? imageUrls,
    DateTime? availableFrom,
    DateTime? availableTo,
  }) {
    return RentalUnit(
      id: id,
      propertyId: propertyId ?? this.propertyId,
      unitNumber: unitNumber ?? this.unitNumber,
      name: name ?? this.name,
      unitType: unitType ?? this.unitType,
      status: status ?? this.status,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      deposit: deposit ?? this.deposit,
      utilityDeposit: utilityDeposit ?? this.utilityDeposit,
      squareFeet: squareFeet ?? this.squareFeet,
      isActive: isActive ?? this.isActive,
      hasAirCon: hasAirCon ?? this.hasAirCon,
      hasPrivateBathroom: hasPrivateBathroom ?? this.hasPrivateBathroom,
      hasFurniture: hasFurniture ?? this.hasFurniture,
      hasWindow: hasWindow ?? this.hasWindow,
      hasBalcony: hasBalcony ?? this.hasBalcony,
      electricityMeterNumber: electricityMeterNumber ?? this.electricityMeterNumber,
      waterMeterNumber: waterMeterNumber ?? this.waterMeterNumber,
      hasIndividualMeter: hasIndividualMeter ?? this.hasIndividualMeter,
      maxOccupancy: maxOccupancy ?? this.maxOccupancy,
      currentOccupancy: currentOccupancy ?? this.currentOccupancy,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      amenities: amenities ?? this.amenities,
      imageUrls: imageUrls ?? this.imageUrls,
      availableFrom: availableFrom ?? this.availableFrom,
      availableTo: availableTo ?? this.availableTo,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'property_id': propertyId,
      'unit_number': unitNumber,
      'name': name,
      'unit_type': unitType.value,
      'status': status.value,
      'monthly_rent': monthlyRent,
      'deposit': deposit,
      'utility_deposit': utilityDeposit,
      'square_feet': squareFeet,
      'is_active': isActive ? 1 : 0,
      'has_air_con': hasAirCon ? 1 : 0,
      'has_private_bathroom': hasPrivateBathroom ? 1 : 0,
      'has_furniture': hasFurniture ? 1 : 0,
      'has_window': hasWindow ? 1 : 0,
      'has_balcony': hasBalcony ? 1 : 0,
      'electricity_meter_number': electricityMeterNumber,
      'water_meter_number': waterMeterNumber,
      'has_individual_meter': hasIndividualMeter ? 1 : 0,
      'max_occupancy': maxOccupancy,
      'current_occupancy': currentOccupancy,
      'description': description,
      'notes': notes,
      'amenities': amenities.join(','),
      'image_urls': imageUrls.join(','),
      'available_from': availableFrom?.toIso8601String(),
      'available_to': availableTo?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create from Map (database)
  factory RentalUnit.fromMap(Map<String, dynamic> map) {
    return RentalUnit(
      id: map['id'] as String,
      propertyId: map['property_id'] as String,
      unitNumber: map['unit_number'] as String,
      name: map['name'] as String,
      unitType: RentalUnitTypeExtension.fromValue(map['unit_type'] as String),
      status: RentalUnitStatusExtension.fromValue(map['status'] as String),
      monthlyRent: (map['monthly_rent'] as num).toDouble(),
      deposit: (map['deposit'] as num?)?.toDouble(),
      utilityDeposit: (map['utility_deposit'] as num?)?.toDouble(),
      squareFeet: (map['square_feet'] as num?)?.toDouble() ?? 0.0,
      isActive: (map['is_active'] as int?) == 1,
      hasAirCon: (map['has_air_con'] as int?) == 1,
      hasPrivateBathroom: (map['has_private_bathroom'] as int?) == 1,
      hasFurniture: (map['has_furniture'] as int?) == 1,
      hasWindow: (map['has_window'] as int?) == 1,
      hasBalcony: (map['has_balcony'] as int?) == 1,
      electricityMeterNumber: map['electricity_meter_number'] as String?,
      waterMeterNumber: map['water_meter_number'] as String?,
      hasIndividualMeter: (map['has_individual_meter'] as int?) == 1,
      maxOccupancy: map['max_occupancy'] as int? ?? 1,
      currentOccupancy: map['current_occupancy'] as int? ?? 0,
      description: map['description'] as String?,
      notes: map['notes'] as String?,
      amenities: (map['amenities'] as String?)?.split(',') ?? [],
      imageUrls: (map['image_urls'] as String?)?.split(',') ?? [],
      availableFrom: map['available_from'] != null 
          ? DateTime.parse(map['available_from'] as String) 
          : null,
      availableTo: map['available_to'] != null 
          ? DateTime.parse(map['available_to'] as String) 
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() {
    return 'RentalUnit{name: $name, type: ${unitType.displayName}, rent: ${monthlyRent}RM, status: ${status.displayName}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RentalUnit && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}