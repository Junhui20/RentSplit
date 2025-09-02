import 'package:uuid/uuid.dart';
import 'utility_provider.dart';

enum PropertyType {
  house,
  apartment,
  condominium,
  townhouse,
  room,
  studio,
}

extension PropertyTypeExtension on PropertyType {
  String get displayName {
    switch (this) {
      case PropertyType.house:
        return 'House';
      case PropertyType.apartment:
        return 'Apartment';
      case PropertyType.condominium:
        return 'Condominium';
      case PropertyType.townhouse:
        return 'Townhouse';
      case PropertyType.room:
        return 'Room';
      case PropertyType.studio:
        return 'Studio';
    }
  }

  String get value => name;

  static PropertyType fromValue(String value) {
    return PropertyType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => PropertyType.house,
    );
  }
}

class Property {
  final String id;
  final String ownerId; // Reference to property owner/user
  final String name;
  final String address;
  final MalaysianState state;
  final PropertyType propertyType;
  final int totalRooms;
  final int totalBathrooms;
  final double totalSquareFeet;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Utility provider IDs for this property
  final String electricityProviderId;
  final String waterProviderId;
  final String internetProviderId;

  // Rental pricing information
  final double baseRentalPrice;
  final double internetFixedFee;
  
  // Property-specific settings
  final bool hasCommonAreas;
  final bool hasSharedUtilities;
  final bool hasIndividualMeters;
  
  // Contact and notes
  final String? contactPhone;
  final String? contactEmail;
  final String? notes;
  
  // Images and documents
  final List<String> imageUrls;
  final List<String> documentUrls;

  Property({
    String? id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.state,
    this.propertyType = PropertyType.house,
    this.totalRooms = 1,
    this.totalBathrooms = 1,
    this.totalSquareFeet = 0.0,
    this.isActive = true,
    required this.electricityProviderId,
    required this.waterProviderId,
    required this.internetProviderId,
    this.baseRentalPrice = 0.0,
    this.internetFixedFee = 0.0,
    this.hasCommonAreas = true,
    this.hasSharedUtilities = true,
    this.hasIndividualMeters = false,
    this.contactPhone,
    this.contactEmail,
    this.notes,
    this.imageUrls = const [],
    this.documentUrls = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Get property's electricity provider
  UtilityProvider? get electricityProvider {
    return MalaysianUtilityProviders.allProviders
        .where((p) => p.id == electricityProviderId)
        .firstOrNull;
  }

  // Get property's water provider
  UtilityProvider? get waterProvider {
    return MalaysianUtilityProviders.allProviders
        .where((p) => p.id == waterProviderId)
        .firstOrNull;
  }

  // Get full address with state
  String get fullAddress {
    return '$address, ${state.displayName}';
  }

  // Get property description
  String get description {
    return '${propertyType.displayName} - $totalRooms rooms, $totalBathrooms bathrooms';
  }

  // Check if property has valid providers for its state
  bool get hasValidProviders {
    final electricityValid = electricityProvider?.servesState(state) ?? false;
    final waterValid = waterProvider?.servesState(state) ?? false;
    return electricityValid && waterValid;
  }

  // Create a copy with updated values
  Property copyWith({
    String? ownerId,
    String? name,
    String? address,
    MalaysianState? state,
    PropertyType? propertyType,
    int? totalRooms,
    int? totalBathrooms,
    double? totalSquareFeet,
    bool? isActive,
    String? electricityProviderId,
    String? waterProviderId,
    String? internetProviderId,
    double? baseRentalPrice,
    double? internetFixedFee,
    bool? hasCommonAreas,
    bool? hasSharedUtilities,
    bool? hasIndividualMeters,
    String? contactPhone,
    String? contactEmail,
    String? notes,
    List<String>? imageUrls,
    List<String>? documentUrls,
  }) {
    return Property(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      state: state ?? this.state,
      propertyType: propertyType ?? this.propertyType,
      totalRooms: totalRooms ?? this.totalRooms,
      totalBathrooms: totalBathrooms ?? this.totalBathrooms,
      totalSquareFeet: totalSquareFeet ?? this.totalSquareFeet,
      isActive: isActive ?? this.isActive,
      electricityProviderId: electricityProviderId ?? this.electricityProviderId,
      waterProviderId: waterProviderId ?? this.waterProviderId,
      internetProviderId: internetProviderId ?? this.internetProviderId,
      baseRentalPrice: baseRentalPrice ?? this.baseRentalPrice,
      internetFixedFee: internetFixedFee ?? this.internetFixedFee,
      hasCommonAreas: hasCommonAreas ?? this.hasCommonAreas,
      hasSharedUtilities: hasSharedUtilities ?? this.hasSharedUtilities,
      hasIndividualMeters: hasIndividualMeters ?? this.hasIndividualMeters,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      notes: notes ?? this.notes,
      imageUrls: imageUrls ?? this.imageUrls,
      documentUrls: documentUrls ?? this.documentUrls,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'address': address,
      'state': state.value,
      'property_type': propertyType.value,
      'total_rooms': totalRooms,
      'total_bathrooms': totalBathrooms,
      'total_square_feet': totalSquareFeet,
      'is_active': isActive ? 1 : 0,
      'electricity_provider_id': electricityProviderId,
      'water_provider_id': waterProviderId,
      'internet_provider_id': internetProviderId,
      'base_rental_price': baseRentalPrice,
      'internet_fixed_fee': internetFixedFee,
      'has_common_areas': hasCommonAreas ? 1 : 0,
      'has_shared_utilities': hasSharedUtilities ? 1 : 0,
      'has_individual_meters': hasIndividualMeters ? 1 : 0,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'notes': notes,
      'image_urls': imageUrls.join(','),
      'document_urls': documentUrls.join(','),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create from Map (database)
  factory Property.fromMap(Map<String, dynamic> map) {
    return Property(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      address: map['address'] as String,
      state: MalaysianStateExtension.fromValue(map['state'] as String),
      propertyType: PropertyTypeExtension.fromValue(map['property_type'] as String),
      totalRooms: map['total_rooms'] as int? ?? 1,
      totalBathrooms: map['total_bathrooms'] as int? ?? 1,
      totalSquareFeet: (map['total_square_feet'] as num?)?.toDouble() ?? 0.0,
      isActive: (map['is_active'] as int?) == 1,
      electricityProviderId: map['electricity_provider_id'] as String,
      waterProviderId: map['water_provider_id'] as String,
      internetProviderId: map['internet_provider_id'] as String? ?? 'unifi',
      baseRentalPrice: (map['base_rental_price'] as num?)?.toDouble() ?? 0.0,
      internetFixedFee: (map['internet_fixed_fee'] as num?)?.toDouble() ?? 0.0,
      hasCommonAreas: (map['has_common_areas'] as int?) == 1,
      hasSharedUtilities: (map['has_shared_utilities'] as int?) == 1,
      hasIndividualMeters: (map['has_individual_meters'] as int?) == 1,
      contactPhone: map['contact_phone'] as String?,
      contactEmail: map['contact_email'] as String?,
      notes: map['notes'] as String?,
      imageUrls: (map['image_urls'] as String?)?.split(',') ?? [],
      documentUrls: (map['document_urls'] as String?)?.split(',') ?? [],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() {
    return 'Property{name: $name, type: ${propertyType.displayName}, rooms: $totalRooms, state: ${state.displayName}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Property && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

extension ListPropertyExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}