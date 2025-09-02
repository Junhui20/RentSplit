import 'package:uuid/uuid.dart';
import 'dart:convert';

enum UtilityType {
  electricity,
  water,
  gas,
  internet,
  sewerage,
  waste,
}

enum MalaysianState {
  kualaLumpur,
  selangor,
  johor,
  penang,
  perak,
  kedah,
  kelantan,
  terengganu,
  pahang,
  negeriSembilan,
  melaka,
  perlis,
  sabah,
  sarawak,
  putrajaya,
  labuan,
}

extension MalaysianStateExtension on MalaysianState {
  String get displayName {
    switch (this) {
      case MalaysianState.kualaLumpur:
        return 'Kuala Lumpur';
      case MalaysianState.selangor:
        return 'Selangor';
      case MalaysianState.johor:
        return 'Johor';
      case MalaysianState.penang:
        return 'Penang';
      case MalaysianState.perak:
        return 'Perak';
      case MalaysianState.kedah:
        return 'Kedah';
      case MalaysianState.kelantan:
        return 'Kelantan';
      case MalaysianState.terengganu:
        return 'Terengganu';
      case MalaysianState.pahang:
        return 'Pahang';
      case MalaysianState.negeriSembilan:
        return 'Negeri Sembilan';
      case MalaysianState.melaka:
        return 'Melaka';
      case MalaysianState.perlis:
        return 'Perlis';
      case MalaysianState.sabah:
        return 'Sabah';
      case MalaysianState.sarawak:
        return 'Sarawak';
      case MalaysianState.putrajaya:
        return 'Putrajaya';
      case MalaysianState.labuan:
        return 'Labuan';
    }
  }

  String get value {
    return name;
  }

  static MalaysianState fromValue(String value) {
    return MalaysianState.values.firstWhere(
      (state) => state.value == value,
      orElse: () => MalaysianState.kualaLumpur,
    );
  }
}

class UtilityProvider {
  final String id;
  final String name;
  final String shortName;
  final UtilityType type;
  final List<MalaysianState> serviceAreas;
  final String website;
  final String? customerServicePhone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Rate structure specific to each provider
  final Map<String, dynamic> rateStructure;

  UtilityProvider({
    String? id,
    required this.name,
    required this.shortName,
    required this.type,
    required this.serviceAreas,
    required this.website,
    this.customerServicePhone,
    this.isActive = true,
    this.rateStructure = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Check if provider serves a specific state
  bool servesState(MalaysianState state) {
    return serviceAreas.contains(state);
  }

  // Get rate for specific usage tier
  double? getRate(String rateType, {double? usage}) {
    if (rateStructure.isEmpty) return null;
    
    final rates = rateStructure[rateType];
    if (rates == null) return null;
    
    // Handle tiered rates
    if (rates is Map<String, dynamic> && usage != null) {
      for (final entry in rates.entries) {
        final threshold = double.tryParse(entry.key) ?? 0;
        if (usage <= threshold) {
          return (entry.value as num?)?.toDouble();
        }
      }
    }
    
    // Handle flat rate
    if (rates is num) {
      return rates.toDouble();
    }
    
    return null;
  }

  // Create a copy with updated values
  UtilityProvider copyWith({
    String? name,
    String? shortName,
    UtilityType? type,
    List<MalaysianState>? serviceAreas,
    String? website,
    String? customerServicePhone,
    bool? isActive,
    Map<String, dynamic>? rateStructure,
  }) {
    return UtilityProvider(
      id: id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      type: type ?? this.type,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      website: website ?? this.website,
      customerServicePhone: customerServicePhone ?? this.customerServicePhone,
      isActive: isActive ?? this.isActive,
      rateStructure: rateStructure ?? this.rateStructure,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Convert to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'short_name': shortName,
      'type': type.name,
      'service_areas': serviceAreas.map((s) => s.value).join(','),
      'website': website,
      'customer_service_phone': customerServicePhone,
      'is_active': isActive ? 1 : 0,
      'rate_structure': jsonEncode(rateStructure), // Proper JSON string
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create from Map (database)
  factory UtilityProvider.fromMap(Map<String, dynamic> map) {
    return UtilityProvider(
      id: map['id'] as String,
      name: map['name'] as String,
      shortName: map['short_name'] as String,
      type: UtilityType.values.firstWhere((t) => t.name == map['type']),
      serviceAreas: (map['service_areas'] as String)
          .split(',')
          .map((s) => MalaysianStateExtension.fromValue(s))
          .toList(),
      website: map['website'] as String,
      customerServicePhone: map['customer_service_phone'] as String?,
      isActive: (map['is_active'] as int) == 1,
      rateStructure: map['rate_structure'] != null
          ? jsonDecode(map['rate_structure'] as String) as Map<String, dynamic>
          : {},
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() {
    return 'UtilityProvider{name: $name, type: ${type.name}, areas: ${serviceAreas.length}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UtilityProvider && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Predefined Malaysian Utility Providers
class MalaysianUtilityProviders {
  // Electricity Providers
  static final UtilityProvider tnb = UtilityProvider(
    id: 'tnb_malaysia',
    name: 'Tenaga Nasional Berhad',
    shortName: 'TNB',
    type: UtilityType.electricity,
    serviceAreas: [
      MalaysianState.kualaLumpur,
      MalaysianState.selangor,
      MalaysianState.johor,
      MalaysianState.penang,
      MalaysianState.perak,
      MalaysianState.kedah,
      MalaysianState.kelantan,
      MalaysianState.terengganu,
      MalaysianState.pahang,
      MalaysianState.negeriSembilan,
      MalaysianState.melaka,
      MalaysianState.perlis,
      MalaysianState.putrajaya,
    ],
    website: 'https://www.tnb.com.my',
    customerServicePhone: '15454',
    rateStructure: {
      'energy_charge_below_1500': 0.2703,
      'energy_charge_above_1500': 0.3703,
      'capacity_charge': 0.0455,
      'network_charge': 0.1285,
      'retail_charge': 10.0,
      'kwtbb_tax_rate': 0.016,
      'sst_tax_rate': 0.08,
    },
  );

  static final UtilityProvider sesb = UtilityProvider(
    id: 'sesb_sabah',
    name: 'Sabah Electricity Sdn Bhd',
    shortName: 'SESB',
    type: UtilityType.electricity,
    serviceAreas: [MalaysianState.sabah],
    website: 'https://www.sesb.com.my',
    customerServicePhone: '088-515000',
    rateStructure: {
      'domestic_rate_1_200': 0.21,
      'domestic_rate_201_300': 0.33,
      'domestic_rate_301_600': 0.52,
      'domestic_rate_above_600': 0.54,
    },
  );

  static final UtilityProvider seb = UtilityProvider(
    id: 'seb_sarawak',
    name: 'Sarawak Energy Berhad',
    shortName: 'SEB',
    type: UtilityType.electricity,
    serviceAreas: [MalaysianState.sarawak],
    website: 'https://www.sarawakenergy.com',
    customerServicePhone: '082-388388',
    rateStructure: {
      'domestic_rate_1_200': 0.205,
      'domestic_rate_201_400': 0.334,
      'domestic_rate_above_400': 0.515,
    },
  );

  // Water Providers
  static final UtilityProvider airSelangor = UtilityProvider(
    id: 'air_selangor',
    name: 'Air Selangor',
    shortName: 'Air Selangor',
    type: UtilityType.water,
    serviceAreas: [
      MalaysianState.selangor,
      MalaysianState.kualaLumpur,
      MalaysianState.putrajaya,
    ],
    website: 'https://www.airselangor.com',
    customerServicePhone: '15300',
    rateStructure: {
      'domestic_rate_1_20': 0.0,      // First 20m³ free
      'domestic_rate_21_35': 0.57,     // 21-35m³
      'domestic_rate_36_above': 1.24,  // Above 35m³
    },
  );

  static final UtilityProvider pbapp = UtilityProvider(
    id: 'pbapp_penang',
    name: 'Perbadanan Bekalan Air Pulau Pinang',
    shortName: 'PBAPP',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.penang],
    website: 'https://www.pba.com.my',
    customerServicePhone: '04-5050088',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_40': 0.28,
      'domestic_rate_above_40': 0.56,
    },
  );

  static final UtilityProvider sajHoldings = UtilityProvider(
    id: 'saj_johor',
    name: 'SAJ Holdings Sdn Bhd',
    shortName: 'SAJ',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.johor],
    website: 'https://www.saj.com.my',
    customerServicePhone: '1800-88-7252',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_40': 0.64,
      'domestic_rate_above_40': 1.17,
    },
  );

  // Perak Water Board
  static final UtilityProvider lakPerak = UtilityProvider(
    id: 'lak_perak',
    name: 'Lembaga Air Perak',
    shortName: 'LAP',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.perak],
    website: 'https://www.lap.gov.my',
    customerServicePhone: '05-254 6001',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_35': 0.52,
      'domestic_rate_above_35': 1.04,
    },
  );

  // Kedah Water Supply Corporation
  static final UtilityProvider puncakNiaga = UtilityProvider(
    id: 'puncak_niaga_kedah',
    name: 'Puncak Niaga (M) Sdn Bhd - Kedah',
    shortName: 'PNSB Kedah',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.kedah],
    website: 'https://www.puncakniaga.com.my',
    customerServicePhone: '04-733 8999',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_40': 0.57,
      'domestic_rate_above_40': 1.14,
    },
  );

  // Kelantan Water Board
  static final UtilityProvider airKelantan = UtilityProvider(
    id: 'air_kelantan',
    name: 'Air Kelantan Sdn Bhd',
    shortName: 'AKSB',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.kelantan],
    website: 'https://www.aksb.com.my',
    customerServicePhone: '09-748 7000',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_40': 0.65,
      'domestic_rate_above_40': 1.30,
    },
  );

  // Terengganu Water Board
  static final UtilityProvider satu = UtilityProvider(
    id: 'satu_terengganu',
    name: 'Syarikat Air Terengganu Sdn Bhd',
    shortName: 'SATU',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.terengganu],
    website: 'https://www.satu.com.my',
    customerServicePhone: '09-622 4400',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_40': 0.60,
      'domestic_rate_above_40': 1.20,
    },
  );

  // Pahang Water Board
  static final UtilityProvider paip = UtilityProvider(
    id: 'paip_pahang',
    name: 'Pengurusan Air Pahang Berhad',
    shortName: 'PAIP',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.pahang],
    website: 'https://www.paip.com.my',
    customerServicePhone: '1-800-88-7247',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_40': 0.70,
      'domestic_rate_above_40': 1.40,
    },
  );

  // Negeri Sembilan Water Board
  static final UtilityProvider airNS = UtilityProvider(
    id: 'air_ns',
    name: 'Syarikat Air Negeri Sembilan Sdn Bhd',
    shortName: 'SAINS',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.negeriSembilan],
    website: 'https://www.sains.com.my',
    customerServicePhone: '06-455 8888',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_35': 0.57,
      'domestic_rate_above_35': 1.14,
    },
  );

  // Melaka Water Corporation
  static final UtilityProvider samh = UtilityProvider(
    id: 'samh_melaka',
    name: 'Syarikat Air Melaka Holdings Berhad',
    shortName: 'SAMH',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.melaka],
    website: 'https://www.samh.com.my',
    customerServicePhone: '1-800-88-7862',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_40': 0.68,
      'domestic_rate_above_40': 1.36,
    },
  );

  // Perlis Water Board
  static final UtilityProvider perbadananAirPerlis = UtilityProvider(
    id: 'pap_perlis',
    name: 'Perbadanan Air Perlis',
    shortName: 'PAP',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.perlis],
    website: 'https://www.pap.gov.my',
    customerServicePhone: '04-977 7946',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_40': 0.50,
      'domestic_rate_above_40': 1.00,
    },
  );

  // Sabah Water Department
  static final UtilityProvider jkrSabah = UtilityProvider(
    id: 'jkr_sabah',
    name: 'Jabatan Kerja Raya Sabah',
    shortName: 'JKR Sabah',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.sabah],
    website: 'https://www.jkr.sabah.gov.my',
    customerServicePhone: '088-326 201',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_40': 0.75,
      'domestic_rate_above_40': 1.50,
    },
  );

  // Sarawak Water Board
  static final UtilityProvider kualaSarawak = UtilityProvider(
    id: 'kuching_water_board',
    name: 'Kuching Water Board',
    shortName: 'KWB',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.sarawak],
    website: 'https://www.kwb.gov.my',
    customerServicePhone: '082-338 999',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_35': 0.35,
      'domestic_rate_above_35': 0.70,
    },
  );

  // Labuan Water Department
  static final UtilityProvider labuanWater = UtilityProvider(
    id: 'labuan_water',
    name: 'Perbadanan Labuan Water Department',
    shortName: 'Labuan Water',
    type: UtilityType.water,
    serviceAreas: [MalaysianState.labuan],
    website: 'https://www.labuan.gov.my',
    customerServicePhone: '087-590 300',
    rateStructure: {
      'domestic_rate_1_20': 0.0,
      'domestic_rate_21_40': 0.80,
      'domestic_rate_above_40': 1.60,
    },
  );

  // Internet Providers
  static final UtilityProvider tmUnifi = UtilityProvider(
    id: 'tm_unifi',
    name: 'TM Unifi',
    shortName: 'Unifi',
    type: UtilityType.internet,
    serviceAreas: MalaysianState.values, // Available nationwide
    website: 'https://www.unifi.com.my',
    customerServicePhone: '100',
    rateStructure: {
      'unifi_30mbps': 89.0,
      'unifi_100mbps': 149.0,
      'unifi_300mbps': 199.0,
      'unifi_500mbps': 249.0,
      'unifi_800mbps': 299.0,
    },
  );

  static final UtilityProvider maxis = UtilityProvider(
    id: 'maxis_fibre',
    name: 'Maxis Fibre',
    shortName: 'Maxis',
    type: UtilityType.internet,
    serviceAreas: [
      MalaysianState.kualaLumpur,
      MalaysianState.selangor,
      MalaysianState.johor,
      MalaysianState.penang,
      MalaysianState.perak,
    ],
    website: 'https://www.maxis.com.my',
    customerServicePhone: '123',
    rateStructure: {
      'maxis_30mbps': 99.0,
      'maxis_100mbps': 149.0,
      'maxis_300mbps': 199.0,
      'maxis_800mbps': 299.0,
    },
  );

  static final UtilityProvider timeInternet = UtilityProvider(
    id: 'time_internet',
    name: 'TIME Internet',
    shortName: 'TIME',
    type: UtilityType.internet,
    serviceAreas: [
      MalaysianState.kualaLumpur,
      MalaysianState.selangor,
      MalaysianState.penang,
      MalaysianState.johor,
    ],
    website: 'https://www.time.com.my',
    customerServicePhone: '1800-18-1818',
    rateStructure: {
      'time_100mbps': 149.0,
      'time_500mbps': 199.0,
      'time_1gbps': 249.0,
    },
  );

  // Get all electricity providers
  static List<UtilityProvider> get electricityProviders => [tnb, sesb, seb];

  // Get all internet providers
  static List<UtilityProvider> get internetProviders => [
    tmUnifi,
    maxis,
    timeInternet,
  ];

  // Get all water providers
  static List<UtilityProvider> get waterProviders => [
    airSelangor,
    pbapp, 
    sajHoldings,
    lakPerak,
    puncakNiaga,
    airKelantan,
    satu,
    paip,
    airNS,
    samh,
    perbadananAirPerlis,
    jkrSabah,
    kualaSarawak,
    labuanWater,
  ];

  // Get all providers
  static List<UtilityProvider> get allProviders => [
    ...electricityProviders,
    ...waterProviders,
    ...internetProviders,
  ];

  // Get providers by state
  static List<UtilityProvider> getProvidersByState(MalaysianState state) {
    return allProviders.where((provider) => provider.servesState(state)).toList();
  }

  // Get electricity provider by state
  static UtilityProvider? getElectricityProvider(MalaysianState state) {
    return electricityProviders
        .where((provider) => provider.servesState(state))
        .firstOrNull;
  }

  // Get water provider by state
  static UtilityProvider? getWaterProvider(MalaysianState state) {
    return waterProviders
        .where((provider) => provider.servesState(state))
        .firstOrNull;
  }

  // Get internet providers by state
  static List<UtilityProvider> getInternetProviders(MalaysianState state) {
    return internetProviders
        .where((provider) => provider.servesState(state))
        .toList();
  }
}

extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}