import '../database/database_helper.dart';
import '../models/property.dart';
import '../models/rental_unit.dart';
import '../models/tenant.dart';
import '../models/expense.dart';
import '../models/utility_provider.dart';

class SampleDataService {
  static final DatabaseHelper _databaseHelper = DatabaseHelper();

  static Future<void> initializeSampleData() async {
    // Check if data already exists
    final existingProperties = await _databaseHelper.getProperties();
    if (existingProperties.isNotEmpty) {
      return; // Data already exists
    }

    // Create sample properties
    await _createSampleProperties();
  }

  static Future<void> _createSampleProperties() async {
    // Property 1: Condominium in Kuala Lumpur
    final property1 = Property(
      ownerId: 'owner_1',
      name: 'A517',
      address: 'Kondo Kamapar Barat',
      state: MalaysianState.selangor,
      propertyType: PropertyType.condominium,
      totalRooms: 3,
      totalBathrooms: 2,
      totalSquareFeet: 1200.0,
      electricityProviderId: 'tnb',
      waterProviderId: 'air_selangor',
      internetProviderId: 'unifi',
      baseRentalPrice: 1500.0,
      internetFixedFee: 89.0,
      hasCommonAreas: true,
      hasSharedUtilities: true,
      contactPhone: '+60123456789',
      contactEmail: 'owner@example.com',
    );

    await _databaseHelper.insertProperty(property1);

    // Create units for property 1
    final unit1 = RentalUnit(
      propertyId: property1.id,
      unitNumber: 'Room A',
      name: 'Master Room',
      unitType: RentalUnitType.masterBedroom,
      monthlyRent: 600.0,
      deposit: 1200.0,
      utilityDeposit: 200.0,
      squareFeet: 150.0,
      hasAirCon: true,
      hasPrivateBathroom: true,
      hasWindow: true,
      maxOccupancy: 1,
      currentOccupancy: 1,
    );

    final unit2 = RentalUnit(
      propertyId: property1.id,
      unitNumber: 'Room B',
      name: 'Medium Room',
      unitType: RentalUnitType.singleRoom,
      monthlyRent: 500.0,
      deposit: 1000.0,
      utilityDeposit: 200.0,
      squareFeet: 120.0,
      hasAirCon: true,
      hasPrivateBathroom: false,
      hasWindow: true,
      maxOccupancy: 1,
      currentOccupancy: 1,
    );

    final unit3 = RentalUnit(
      propertyId: property1.id,
      unitNumber: 'Room C',
      name: 'Small Room',
      unitType: RentalUnitType.singleRoom,
      monthlyRent: 450.0,
      deposit: 900.0,
      utilityDeposit: 200.0,
      squareFeet: 100.0,
      hasAirCon: true,
      hasPrivateBathroom: false,
      hasWindow: true,
      maxOccupancy: 1,
      currentOccupancy: 0,
      status: RentalUnitStatus.available,
    );

    await _databaseHelper.insertRentalUnit(unit1);
    await _databaseHelper.insertRentalUnit(unit2);
    await _databaseHelper.insertRentalUnit(unit3);

    // Create sample tenants
    final tenant1 = Tenant(
      name: 'Hui',
      email: 'hui@example.com',
      phone: '+60123456781',
      propertyId: property1.id,
      rentalUnitId: unit1.id,
      previousACReading: 1500.0,
      currentACReading: 1678.0,
    );

    final tenant2 = Tenant(
      name: 'Wilson',
      email: 'wilson@example.com',
      phone: '+60123456782',
      propertyId: property1.id,
      rentalUnitId: unit2.id,
      previousACReading: 4200.0,
      currentACReading: 4417.0,
    );

    await _databaseHelper.insertTenant(tenant1);
    await _databaseHelper.insertTenant(tenant2);

    // Property 2: House in Penang
    final property2 = Property(
      ownerId: 'owner_1',
      name: 'Penang Terrace House',
      address: 'Jalan Bukit Jambul, Penang',
      state: MalaysianState.penang,
      propertyType: PropertyType.house,
      totalRooms: 4,
      totalBathrooms: 3,
      totalSquareFeet: 1800.0,
      electricityProviderId: 'tnb',
      waterProviderId: 'pbapp',
      internetProviderId: 'unifi',
      baseRentalPrice: 2000.0,
      internetFixedFee: 89.0,
      hasCommonAreas: true,
      hasSharedUtilities: true,
      contactPhone: '+60123456789',
      contactEmail: 'owner@example.com',
    );

    await _databaseHelper.insertProperty(property2);

    // Create units for property 2
    final unit4 = RentalUnit(
      propertyId: property2.id,
      unitNumber: 'Room 1',
      name: 'Master Bedroom',
      unitType: RentalUnitType.masterBedroom,
      monthlyRent: 700.0,
      deposit: 1400.0,
      utilityDeposit: 300.0,
      squareFeet: 200.0,
      hasAirCon: true,
      hasPrivateBathroom: true,
      hasWindow: true,
      maxOccupancy: 1,
      currentOccupancy: 0,
      status: RentalUnitStatus.available,
    );

    final unit5 = RentalUnit(
      propertyId: property2.id,
      unitNumber: 'Room 2',
      name: 'Second Bedroom',
      unitType: RentalUnitType.singleRoom,
      monthlyRent: 600.0,
      deposit: 1200.0,
      utilityDeposit: 300.0,
      squareFeet: 150.0,
      hasAirCon: true,
      hasPrivateBathroom: false,
      hasWindow: true,
      maxOccupancy: 1,
      currentOccupancy: 1,
    );

    await _databaseHelper.insertRentalUnit(unit4);
    await _databaseHelper.insertRentalUnit(unit5);

    // Create tenant for property 2
    final tenant3 = Tenant(
      name: 'Yao',
      email: 'yao@example.com',
      phone: '+60123456783',
      propertyId: property2.id,
      rentalUnitId: unit5.id,
      previousACReading: 1500.0,
      currentACReading: 1637.0,
    );

    await _databaseHelper.insertTenant(tenant3);

    // Create sample expense for current month
    final now = DateTime.now();
    final expense = Expense(
      propertyId: property1.id,
      month: now.month,
      year: now.year,
      baseRent: 1500.0,
      internetFee: 89.00,
      waterBill: 35.80,
      miscellaneousExpenses: 175.0,
      totalKWhUsage: 850.0,
      totalACKWhUsage: 295.0,
      notes: 'Sample monthly expenses',
    );

    await _databaseHelper.insertExpense(expense);
  }

  static Future<void> clearAllData() async {
    await _databaseHelper.deleteAllData();
  }

  static Future<void> resetWithSampleData() async {
    await clearAllData();
    await initializeSampleData();
  }
}
