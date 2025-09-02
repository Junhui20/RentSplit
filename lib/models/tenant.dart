import 'package:uuid/uuid.dart';

class Tenant {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? emergencyContact;
  final String? propertyId;
  final String? rentalUnitId;
  final bool isActive;
  final double currentACReading;
  final double previousACReading;
  final DateTime createdAt;
  final DateTime updatedAt;

  Tenant({
    String? id,
    required this.name,
    this.email,
    this.phone,
    this.emergencyContact,
    this.propertyId,
    this.rentalUnitId,
    this.isActive = true,
    this.currentACReading = 0.0,
    this.previousACReading = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Calculate AC usage for current period
  double get acUsageKWh {
    return currentACReading - previousACReading;
  }

  // Check if tenant has valid AC readings
  bool get hasValidACReadings {
    return currentACReading >= previousACReading && previousACReading >= 0;
  }

  // Create a copy with updated values
  Tenant copyWith({
    String? name,
    String? email,
    String? phone,
    String? emergencyContact,
    String? propertyId,
    String? rentalUnitId,
    bool? isActive,
    double? currentACReading,
    double? previousACReading,
  }) {
    return Tenant(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      propertyId: propertyId ?? this.propertyId,
      rentalUnitId: rentalUnitId ?? this.rentalUnitId,
      isActive: isActive ?? this.isActive,
      currentACReading: currentACReading ?? this.currentACReading,
      previousACReading: previousACReading ?? this.previousACReading,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'emergency_contact': emergencyContact,
      'property_id': propertyId,
      'rental_unit_id': rentalUnitId,
      'is_active': isActive ? 1 : 0,
      'current_ac_reading': currentACReading,
      'previous_ac_reading': previousACReading,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create from Map (database)
  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      emergencyContact: map['emergency_contact'] as String?,
      propertyId: map['property_id'] as String?,
      rentalUnitId: map['rental_unit_id'] as String?,
      isActive: (map['is_active'] as int) == 1,
      currentACReading: (map['current_ac_reading'] as num?)?.toDouble() ?? 0.0,
      previousACReading: (map['previous_ac_reading'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() {
    return 'Tenant{id: $id, name: $name, email: $email, phone: $phone, '
           'isActive: $isActive, acUsage: ${acUsageKWh}kWh}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tenant && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 