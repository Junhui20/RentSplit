import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/tenant.dart';
import '../models/expense.dart';
import '../models/property.dart';
import '../models/rental_unit.dart';
import '../models/rental_agreement.dart';
import '../models/utility_bill.dart';
import '../models/utility_provider.dart';
import '../models/tnb_electricity_bill.dart';
import '../models/calculation_result.dart';
import '../models/tenant_calculation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'rent_split_malaysia.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onOpen(Database db) async {
    // Initialize utility providers if they don't exist
    final providers = await db.query('utility_providers', limit: 1);
    if (providers.isEmpty) {
      await _initializeUtilityProviders(db);
    }
  }

  Future<void> _initializeUtilityProviders(Database db) async {
    final providers = MalaysianUtilityProviders.allProviders;
    for (final provider in providers) {
      await db.insert('utility_providers', provider.toMap());
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create properties table
    await db.execute('''
      CREATE TABLE properties (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        state TEXT NOT NULL,
        property_type TEXT NOT NULL DEFAULT 'house',
        total_rooms INTEGER DEFAULT 1,
        total_bathrooms INTEGER DEFAULT 1,
        total_square_feet REAL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        electricity_provider_id TEXT NOT NULL,
        water_provider_id TEXT NOT NULL,
        internet_provider_id TEXT NOT NULL DEFAULT 'unifi',
        base_rental_price REAL DEFAULT 0.0,
        internet_fixed_fee REAL DEFAULT 0.0,
        has_common_areas INTEGER DEFAULT 1,
        has_shared_utilities INTEGER DEFAULT 1,
        has_individual_meters INTEGER DEFAULT 0,
        contact_phone TEXT,
        contact_email TEXT,
        notes TEXT,
        image_urls TEXT,
        document_urls TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create rental units table
    await db.execute('''
      CREATE TABLE rental_units (
        id TEXT PRIMARY KEY,
        property_id TEXT NOT NULL,
        unit_number TEXT NOT NULL,
        name TEXT NOT NULL,
        unit_type TEXT NOT NULL DEFAULT 'room',
        status TEXT NOT NULL DEFAULT 'available',
        monthly_rent REAL NOT NULL,
        deposit REAL,
        utility_deposit REAL,
        square_feet REAL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        has_air_con INTEGER DEFAULT 0,
        has_private_bathroom INTEGER DEFAULT 0,
        has_furniture INTEGER DEFAULT 0,
        has_window INTEGER DEFAULT 1,
        has_balcony INTEGER DEFAULT 0,
        electricity_meter_number TEXT,
        water_meter_number TEXT,
        has_individual_meter INTEGER DEFAULT 0,
        max_occupancy INTEGER DEFAULT 1,
        current_occupancy INTEGER DEFAULT 0,
        description TEXT,
        notes TEXT,
        amenities TEXT,
        image_urls TEXT,
        available_from TEXT,
        available_to TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE CASCADE
      )
    ''');

    // Create rental agreements table
    await db.execute('''
      CREATE TABLE rental_agreements (
        id TEXT PRIMARY KEY,
        property_id TEXT NOT NULL,
        rental_unit_id TEXT NOT NULL,
        tenant_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        monthly_rent REAL NOT NULL,
        payment_frequency TEXT DEFAULT 'monthly',
        security_deposit REAL DEFAULT 0,
        utility_deposit REAL DEFAULT 0,
        payment_due_day INTEGER DEFAULT 1,
        grace_period_days INTEGER DEFAULT 5,
        late_fee_amount REAL DEFAULT 0,
        late_fee_percentage REAL DEFAULT 0,
        includes_electricity INTEGER DEFAULT 0,
        includes_water INTEGER DEFAULT 0,
        includes_gas INTEGER DEFAULT 0,
        includes_internet INTEGER DEFAULT 0,
        electricity_allowance REAL DEFAULT 0,
        water_allowance REAL DEFAULT 0,
        special_terms TEXT,
        notes TEXT,
        included_services TEXT,
        restrictions TEXT,
        contract_document_url TEXT,
        attachment_urls TEXT,
        auto_renewal INTEGER DEFAULT 0,
        renewal_notice_days INTEGER DEFAULT 30,
        renewal_terms TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE CASCADE,
        FOREIGN KEY (rental_unit_id) REFERENCES rental_units (id) ON DELETE CASCADE,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
      )
    ''');

    // Create utility providers table
    await db.execute('''
      CREATE TABLE utility_providers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        short_name TEXT NOT NULL,
        type TEXT NOT NULL,
        service_areas TEXT NOT NULL,
        website TEXT NOT NULL,
        customer_service_phone TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        rate_structure TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create tenants table (updated for multi-property)
    await db.execute('''
      CREATE TABLE tenants (
        id TEXT PRIMARY KEY,
        property_id TEXT,
        rental_unit_id TEXT,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        emergency_contact TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        current_ac_reading REAL DEFAULT 0,
        previous_ac_reading REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE SET NULL,
        FOREIGN KEY (rental_unit_id) REFERENCES rental_units (id) ON DELETE SET NULL
      )
    ''');

    // Create expenses table (updated for multi-property)
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        property_id TEXT NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        base_rent REAL NOT NULL DEFAULT 0,
        internet_fee REAL NOT NULL DEFAULT 0,
        water_bill REAL NOT NULL DEFAULT 0,
        miscellaneous_expenses REAL NOT NULL DEFAULT 0,
        split_miscellaneous INTEGER NOT NULL DEFAULT 1,
        total_kwh_usage REAL NOT NULL DEFAULT 0,
        total_ac_kwh_usage REAL NOT NULL DEFAULT 0,
        electric_price_per_kwh REAL DEFAULT 0.218,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE CASCADE
      )
    ''');

    // Create utility bills table (replaces TNB-specific table)
    await db.execute('''
      CREATE TABLE utility_bills (
        id TEXT PRIMARY KEY,
        expense_id TEXT NOT NULL,
        provider_id TEXT NOT NULL,
        utility_type TEXT NOT NULL,
        total_usage REAL NOT NULL,
        usage_unit TEXT NOT NULL,
        charges TEXT,
        total_amount REAL NOT NULL,
        billing_period_start TEXT NOT NULL,
        billing_period_end TEXT NOT NULL,
        due_date TEXT NOT NULL,
        additional_data TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE CASCADE,
        FOREIGN KEY (provider_id) REFERENCES utility_providers (id)
      )
    ''');

    // Create TNB electricity bills table (for TNB-specific calculations)
    await db.execute('''
      CREATE TABLE tnb_electricity_bills (
        id TEXT PRIMARY KEY,
        expense_id TEXT NOT NULL,
        total_kwh_usage REAL NOT NULL,
        energy_charge REAL NOT NULL DEFAULT 0,
        capacity_charge REAL NOT NULL DEFAULT 0,
        network_charge REAL NOT NULL DEFAULT 0,
        retail_charge REAL NOT NULL DEFAULT 0,
        ee_incentive REAL NOT NULL DEFAULT 0,
        kwtbb_tax REAL NOT NULL DEFAULT 0,
        sst_tax REAL NOT NULL DEFAULT 0,
        total_amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE CASCADE
      )
    ''');

    // Create calculation results table
    await db.execute('''
      CREATE TABLE calculation_results (
        id TEXT PRIMARY KEY,
        expense_id TEXT NOT NULL,
        calculation_method TEXT NOT NULL,
        total_amount REAL NOT NULL,
        active_tenants_count INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE CASCADE
      )
    ''');

    // Create tenant calculations table
    await db.execute('''
      CREATE TABLE tenant_calculations (
        id TEXT PRIMARY KEY,
        calculation_result_id TEXT NOT NULL,
        tenant_id TEXT NOT NULL,
        tenant_name TEXT NOT NULL,
        rent_share REAL NOT NULL DEFAULT 0,
        internet_share REAL NOT NULL DEFAULT 0,
        water_share REAL NOT NULL DEFAULT 0,
        common_electricity_share REAL NOT NULL DEFAULT 0,
        individual_ac_cost REAL NOT NULL DEFAULT 0,
        miscellaneous_share REAL NOT NULL DEFAULT 0,
        total_amount REAL NOT NULL,
        ac_usage_kwh REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (calculation_result_id) REFERENCES calculation_results (id) ON DELETE CASCADE,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
      )
    ''');

    // Create AC usage history table
    await db.execute('''
      CREATE TABLE ac_usage_history (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        reading_date TEXT NOT NULL,
        meter_reading REAL NOT NULL,
        usage_kwh REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
      )
    ''');

    // Create tenant AC watt usage table for calculation inputs
    await db.execute('''
      CREATE TABLE tenant_ac_watt_usage (
        id TEXT PRIMARY KEY,
        expense_id TEXT NOT NULL,
        tenant_id TEXT NOT NULL,
        ac_watt_usage REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE CASCADE,
        FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE,
        UNIQUE(expense_id, tenant_id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_properties_owner ON properties (owner_id)');
    await db.execute('CREATE INDEX idx_properties_state ON properties (state)');
    await db.execute('CREATE INDEX idx_rental_units_property ON rental_units (property_id)');
    await db.execute('CREATE INDEX idx_rental_units_status ON rental_units (status)');
    await db.execute('CREATE INDEX idx_rental_agreements_property ON rental_agreements (property_id)');
    await db.execute('CREATE INDEX idx_rental_agreements_tenant ON rental_agreements (tenant_id)');
    await db.execute('CREATE INDEX idx_rental_agreements_dates ON rental_agreements (start_date, end_date)');
    await db.execute('CREATE INDEX idx_tenants_property ON tenants (property_id)');
    await db.execute('CREATE INDEX idx_expenses_property_month_year ON expenses (property_id, month, year)');
    await db.execute('CREATE INDEX idx_utility_bills_expense ON utility_bills (expense_id)');
    await db.execute('CREATE INDEX idx_utility_bills_provider ON utility_bills (provider_id)');
    await db.execute('CREATE INDEX idx_tenant_calculations_result_id ON tenant_calculations (calculation_result_id)');
    await db.execute('CREATE INDEX idx_ac_usage_tenant_id ON ac_usage_history (tenant_id)');
    await db.execute('CREATE INDEX idx_ac_usage_date ON ac_usage_history (reading_date)');
    await db.execute('CREATE INDEX idx_tenant_ac_watt_expense ON tenant_ac_watt_usage (expense_id)');
    await db.execute('CREATE INDEX idx_tenant_ac_watt_tenant ON tenant_ac_watt_usage (tenant_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2 && newVersion >= 2) {
      // Add notes column to expenses table
      await db.execute('ALTER TABLE expenses ADD COLUMN notes TEXT');
    }

    if (oldVersion < 3 && newVersion >= 3) {
      // Add electric price column to expenses table
      await db.execute('ALTER TABLE expenses ADD COLUMN electric_price_per_kwh REAL DEFAULT 0.218');

      // Create tenant AC watt usage table
      await db.execute('''
        CREATE TABLE tenant_ac_watt_usage (
          id TEXT PRIMARY KEY,
          expense_id TEXT NOT NULL,
          tenant_id TEXT NOT NULL,
          ac_watt_usage REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE CASCADE,
          FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE,
          UNIQUE(expense_id, tenant_id)
        )
      ''');

      // Create indexes for new table
      await db.execute('CREATE INDEX idx_tenant_ac_watt_expense ON tenant_ac_watt_usage (expense_id)');
      await db.execute('CREATE INDEX idx_tenant_ac_watt_tenant ON tenant_ac_watt_usage (tenant_id)');
    }

    if (oldVersion < 4 && newVersion >= 4) {
      // Remove gas provider and add internet provider and rental pricing
      await db.execute('ALTER TABLE properties ADD COLUMN internet_provider_id TEXT DEFAULT "unifi"');
      await db.execute('ALTER TABLE properties ADD COLUMN base_rental_price REAL DEFAULT 0.0');
      await db.execute('ALTER TABLE properties ADD COLUMN internet_fixed_fee REAL DEFAULT 0.0');

      // Update existing properties to have internet provider
      await db.execute('UPDATE properties SET internet_provider_id = "unifi" WHERE internet_provider_id IS NULL');
    }

    if (oldVersion < 5 && newVersion >= 5) {
      // Add emergency_contact column to tenants table
      await db.execute('ALTER TABLE tenants ADD COLUMN emergency_contact TEXT');
    }

    if (oldVersion < 6 && newVersion >= 6) {
      // Create TNB electricity bills table for TNB-specific calculations
      await db.execute('''
        CREATE TABLE tnb_electricity_bills (
          id TEXT PRIMARY KEY,
          expense_id TEXT NOT NULL,
          total_kwh_usage REAL NOT NULL,
          energy_charge REAL NOT NULL DEFAULT 0,
          capacity_charge REAL NOT NULL DEFAULT 0,
          network_charge REAL NOT NULL DEFAULT 0,
          retail_charge REAL NOT NULL DEFAULT 0,
          ee_incentive REAL NOT NULL DEFAULT 0,
          kwtbb_tax REAL NOT NULL DEFAULT 0,
          sst_tax REAL NOT NULL DEFAULT 0,
          total_amount REAL NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // Helper method to update unit occupancy count
  Future<void> _updateUnitOccupancy(String unitId, int change) async {
    final db = await database;

    // Get current occupancy
    final unitMaps = await db.query(
      'rental_units',
      columns: ['current_occupancy'],
      where: 'id = ?',
      whereArgs: [unitId],
    );

    if (unitMaps.isNotEmpty) {
      final currentOccupancy = unitMaps.first['current_occupancy'] as int;
      final newOccupancy = (currentOccupancy + change).clamp(0, 999); // Prevent negative values

      await db.update(
        'rental_units',
        {'current_occupancy': newOccupancy},
        where: 'id = ?',
        whereArgs: [unitId],
      );
    }
  }

  // Method to recalculate all unit occupancy counts (for fixing inconsistencies)
  Future<void> recalculateUnitOccupancy() async {
    final db = await database;

    // Get all rental units
    final units = await getRentalUnits();

    for (final unit in units) {
      // Count active tenants assigned to this unit
      final tenantCount = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM tenants
        WHERE rental_unit_id = ? AND is_active = 1
      ''', [unit.id]);

      final actualCount = tenantCount.first['count'] as int;

      // Update the unit's current occupancy
      await db.update(
        'rental_units',
        {'current_occupancy': actualCount},
        where: 'id = ?',
        whereArgs: [unit.id],
      );
    }
  }

  // Reset database for testing
  Future<void> resetDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'rent_split_malaysia.db');

    // Close current database
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    // Delete database file
    await deleteDatabase(path);

    // Reinitialize
    _database = await _initDatabase();
  }

  // Tenant operations
  Future<int> insertTenant(Tenant tenant) async {
    final db = await database;
    final result = await db.insert('tenants', tenant.toMap());

    // Update unit occupancy if tenant is assigned to a unit
    if (tenant.rentalUnitId != null) {
      await _updateUnitOccupancy(tenant.rentalUnitId!, 1);
    }

    return result;
  }

  Future<List<Tenant>> getTenants() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tenants');
    return List.generate(maps.length, (i) => Tenant.fromMap(maps[i]));
  }

  Future<List<Tenant>> getTenantsByProperty(String propertyId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT t.* FROM tenants t
      INNER JOIN rental_units ru ON t.rental_unit_id = ru.id
      WHERE ru.property_id = ?
      ORDER BY t.name
    ''', [propertyId]);
    return List.generate(maps.length, (i) => Tenant.fromMap(maps[i]));
  }

  Future<List<Tenant>> getActiveTenants() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tenants',
      where: 'is_active = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) => Tenant.fromMap(maps[i]));
  }

  Future<int> updateTenant(Tenant tenant) async {
    final db = await database;

    // Get the old tenant data to check for unit changes
    final oldTenantMaps = await db.query(
      'tenants',
      where: 'id = ?',
      whereArgs: [tenant.id],
    );

    if (oldTenantMaps.isNotEmpty) {
      final oldTenant = Tenant.fromMap(oldTenantMaps.first);

      // Handle unit assignment changes
      if (oldTenant.rentalUnitId != tenant.rentalUnitId) {
        // Remove from old unit
        if (oldTenant.rentalUnitId != null) {
          await _updateUnitOccupancy(oldTenant.rentalUnitId!, -1);
        }

        // Add to new unit
        if (tenant.rentalUnitId != null) {
          await _updateUnitOccupancy(tenant.rentalUnitId!, 1);
        }
      }
    }

    return await db.update(
      'tenants',
      tenant.toMap(),
      where: 'id = ?',
      whereArgs: [tenant.id],
    );
  }

  Future<int> deleteTenant(String id) async {
    final db = await database;

    // Get tenant data before deletion to update unit occupancy
    final tenantMaps = await db.query(
      'tenants',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (tenantMaps.isNotEmpty) {
      final tenant = Tenant.fromMap(tenantMaps.first);

      // Update unit occupancy if tenant was assigned to a unit
      if (tenant.rentalUnitId != null) {
        await _updateUnitOccupancy(tenant.rentalUnitId!, -1);
      }
    }

    return await db.delete(
      'tenants',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Expense operations
  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      orderBy: 'year DESC, month DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<Expense?> getExpenseByMonthYear(int month, int year) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
    );
    if (maps.isEmpty) return null;
    return Expense.fromMap(maps.first);
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(String id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // TNB Electricity Bill operations
  Future<int> insertTNBBill(TNBElectricityBill bill) async {
    final db = await database;
    return await db.insert('tnb_electricity_bills', bill.toMap());
  }

  Future<TNBElectricityBill?> getTNBBillByExpenseId(String expenseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tnb_electricity_bills',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    if (maps.isEmpty) return null;
    return TNBElectricityBill.fromMap(maps.first);
  }

  Future<int> updateTNBBill(TNBElectricityBill bill) async {
    final db = await database;
    return await db.update(
      'tnb_electricity_bills',
      bill.toMap(),
      where: 'id = ?',
      whereArgs: [bill.id],
    );
  }

  // Calculation Result operations
  Future<int> insertCalculationResult(CalculationResult result) async {
    final db = await database;
    return await db.insert('calculation_results', result.toMap());
  }

  Future<List<CalculationResult>> getCalculationResults() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'calculation_results',
      orderBy: 'created_at DESC',
    );

    // Load tenant calculations for each result efficiently
    List<CalculationResult> results = [];
    for (var map in maps) {
      results.add(CalculationResult.fromMap(map));
    }

    return results;
  }

  Future<int> deleteCalculationResult(String id) async {
    final db = await database;
    return await db.delete(
      'calculation_results',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<CalculationResult?> getCalculationResultByExpenseId(String expenseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'calculation_results',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    if (maps.isEmpty) return null;
    return CalculationResult.fromMap(maps.first);
  }

  // Tenant Calculation operations
  Future<int> insertTenantCalculation(TenantCalculation calculation) async {
    final db = await database;
    return await db.insert('tenant_calculations', calculation.toMap());
  }

  Future<List<TenantCalculation>> getTenantCalculationsByResultId(String resultId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tenant_calculations',
      where: 'calculation_result_id = ?',
      whereArgs: [resultId],
    );
    return List.generate(maps.length, (i) => TenantCalculation.fromMap(maps[i]));
  }

  // AC Usage History operations
  Future<int> insertACUsageHistory(String tenantId, DateTime date, double reading, double usage) async {
    final db = await database;
    return await db.insert('ac_usage_history', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'tenant_id': tenantId,
      'reading_date': date.toIso8601String(),
      'meter_reading': reading,
      'usage_kwh': usage,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getACUsageHistory(String tenantId, {int limit = 12}) async {
    final db = await database;
    return await db.query(
      'ac_usage_history',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'reading_date DESC',
      limit: limit,
    );
  }

  // Utility methods
  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tenant_calculations');
      await txn.delete('calculation_results');
      await txn.delete('utility_bills');
      await txn.delete('rental_agreements');
      await txn.delete('ac_usage_history');
      await txn.delete('expenses');
      await txn.delete('tenants');
      await txn.delete('rental_units');
      await txn.delete('properties');
      await txn.delete('utility_providers');
    });
  }

  // Property operations
  Future<int> insertProperty(Property property) async {
    final db = await database;
    return await db.insert('properties', property.toMap());
  }

  Future<List<Property>> getProperties() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'properties',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Property.fromMap(maps[i]));
  }

  Future<List<Property>> getActiveProperties() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'properties',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Property.fromMap(maps[i]));
  }

  Future<Property?> getProperty(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'properties',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Property.fromMap(maps.first);
  }

  Future<int> updateProperty(Property property) async {
    final db = await database;
    return await db.update(
      'properties',
      property.toMap(),
      where: 'id = ?',
      whereArgs: [property.id],
    );
  }

  Future<int> deleteProperty(String id) async {
    final db = await database;
    return await db.delete(
      'properties',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Rental Unit operations
  Future<int> insertRentalUnit(RentalUnit unit) async {
    final db = await database;
    return await db.insert('rental_units', unit.toMap());
  }

  Future<List<RentalUnit>> getRentalUnits() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rental_units',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => RentalUnit.fromMap(maps[i]));
  }

  Future<List<RentalUnit>> getRentalUnitsByProperty(String propertyId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rental_units',
      where: 'property_id = ?',
      whereArgs: [propertyId],
      orderBy: 'unit_number ASC',
    );
    return List.generate(maps.length, (i) => RentalUnit.fromMap(maps[i]));
  }

  Future<List<RentalUnit>> getAvailableRentalUnits(String propertyId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rental_units',
      where: 'property_id = ? AND status = ? AND is_active = ?',
      whereArgs: [propertyId, 'available', 1],
      orderBy: 'unit_number ASC',
    );
    return List.generate(maps.length, (i) => RentalUnit.fromMap(maps[i]));
  }

  Future<RentalUnit?> getRentalUnit(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rental_units',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return RentalUnit.fromMap(maps.first);
  }

  Future<int> updateRentalUnit(RentalUnit unit) async {
    final db = await database;
    return await db.update(
      'rental_units',
      unit.toMap(),
      where: 'id = ?',
      whereArgs: [unit.id],
    );
  }

  Future<int> deleteRentalUnit(String id) async {
    final db = await database;
    return await db.delete(
      'rental_units',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Rental Agreement operations
  Future<int> insertRentalAgreement(RentalAgreement agreement) async {
    final db = await database;
    return await db.insert('rental_agreements', agreement.toMap());
  }

  Future<List<RentalAgreement>> getRentalAgreements() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rental_agreements',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => RentalAgreement.fromMap(maps[i]));
  }

  Future<List<RentalAgreement>> getRentalAgreementsByProperty(String propertyId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rental_agreements',
      where: 'property_id = ?',
      whereArgs: [propertyId],
      orderBy: 'start_date DESC',
    );
    return List.generate(maps.length, (i) => RentalAgreement.fromMap(maps[i]));
  }

  Future<List<RentalAgreement>> getActiveRentalAgreements() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rental_agreements',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'start_date DESC',
    );
    return List.generate(maps.length, (i) => RentalAgreement.fromMap(maps[i]));
  }

  Future<RentalAgreement?> getRentalAgreement(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rental_agreements',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return RentalAgreement.fromMap(maps.first);
  }

  Future<int> updateRentalAgreement(RentalAgreement agreement) async {
    final db = await database;
    return await db.update(
      'rental_agreements',
      agreement.toMap(),
      where: 'id = ?',
      whereArgs: [agreement.id],
    );
  }

  Future<int> deleteRentalAgreement(String id) async {
    final db = await database;
    return await db.delete(
      'rental_agreements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Utility Provider operations
  Future<int> insertUtilityProvider(UtilityProvider provider) async {
    final db = await database;
    return await db.insert('utility_providers', provider.toMap());
  }

  Future<List<UtilityProvider>> getUtilityProviders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'utility_providers',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => UtilityProvider.fromMap(maps[i]));
  }

  Future<List<UtilityProvider>> getUtilityProvidersByType(String type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'utility_providers',
      where: 'type = ? AND is_active = ?',
      whereArgs: [type, 1],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => UtilityProvider.fromMap(maps[i]));
  }

  Future<UtilityProvider?> getUtilityProvider(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'utility_providers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return UtilityProvider.fromMap(maps.first);
  }

  // Utility Bill operations
  Future<int> insertUtilityBill(UtilityBill bill) async {
    final db = await database;
    return await db.insert('utility_bills', bill.toMap());
  }

  Future<List<UtilityBill>> getUtilityBills() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'utility_bills',
      orderBy: 'billing_period_start DESC',
    );
    return List.generate(maps.length, (i) => UtilityBill.fromMap(maps[i]));
  }

  Future<List<UtilityBill>> getUtilityBillsByExpense(String expenseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'utility_bills',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
      orderBy: 'utility_type ASC',
    );
    return List.generate(maps.length, (i) => UtilityBill.fromMap(maps[i]));
  }

  Future<UtilityBill?> getUtilityBill(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'utility_bills',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return UtilityBill.fromMap(maps.first);
  }

  Future<int> updateUtilityBill(UtilityBill bill) async {
    final db = await database;
    return await db.update(
      'utility_bills',
      bill.toMap(),
      where: 'id = ?',
      whereArgs: [bill.id],
    );
  }

  Future<int> deleteUtilityBill(String id) async {
    final db = await database;
    return await db.delete(
      'utility_bills',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Initialize utility providers with predefined Malaysian providers
  Future<void> initializeUtilityProviders() async {
    final providers = MalaysianUtilityProviders.allProviders;
    for (final provider in providers) {
      await insertUtilityProvider(provider);
    }
  }

  // Portfolio analytics methods
  Future<Map<String, dynamic>> getPropertyPortfolioSummary() async {
    final properties = await getActiveProperties();
    final allUnits = await getRentalUnits();
    final allAgreements = await getActiveRentalAgreements();
    
    int totalProperties = properties.length;
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
      List<RentalUnit> propertyUnits = allUnits.where((u) => u.propertyId == property.id).toList();
      unitsByState[state] = (unitsByState[state] ?? 0) + propertyUnits.length;
    }
    
    return {
      'totalProperties': totalProperties,
      'activeProperties': totalProperties,
      'totalUnits': totalUnits,
      'occupiedUnits': occupiedUnits,
      'availableUnits': availableUnits,
      'occupancyRate': occupancyRate,
      'totalMonthlyRent': totalMonthlyRent,
      'unitsByState': unitsByState,
      'propertiesNeedingAttention': <Map<String, dynamic>>[],
    };
  }

  // Update calculation result
  Future<void> updateCalculationResult(CalculationResult calculationResult) async {
    final db = await database;
    await db.update(
      'calculation_results',
      calculationResult.toMap(),
      where: 'id = ?',
      whereArgs: [calculationResult.id],
    );
  }

  // Get expense by ID  
  Future<Expense?> getExpenseById(String expenseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
    );

    if (maps.isEmpty) {
      return null;
    }

    return Expense.fromMap(maps.first);
  }

  // Get all expenses
  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      orderBy: 'year DESC, month DESC',
    );

    return List.generate(maps.length, (i) {
      return Expense.fromMap(maps[i]);
    });
  }

  // Tenant AC Watt Usage operations
  Future<void> insertTenantACWattUsage(String expenseId, String tenantId, double acWattUsage) async {
    final db = await database;
    await db.insert(
      'tenant_ac_watt_usage',
      {
        'id': const Uuid().v4(),
        'expense_id': expenseId,
        'tenant_id': tenantId,
        'ac_watt_usage': acWattUsage,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTenantACWattUsage(String expenseId, String tenantId, double acWattUsage) async {
    final db = await database;
    await db.update(
      'tenant_ac_watt_usage',
      {
        'ac_watt_usage': acWattUsage,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'expense_id = ? AND tenant_id = ?',
      whereArgs: [expenseId, tenantId],
    );
  }

  Future<Map<String, double>> getTenantACWattUsageByExpense(String expenseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tenant_ac_watt_usage',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );

    Map<String, double> result = {};
    for (var map in maps) {
      result[map['tenant_id'] as String] = (map['ac_watt_usage'] as num).toDouble();
    }
    return result;
  }

  Future<double?> getTenantACWattUsage(String expenseId, String tenantId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tenant_ac_watt_usage',
      where: 'expense_id = ? AND tenant_id = ?',
      whereArgs: [expenseId, tenantId],
    );

    if (maps.isNotEmpty) {
      return (maps.first['ac_watt_usage'] as num).toDouble();
    }
    return null;
  }

  Future<Map<String, double>> getPreviousMonthTenantACWattUsage(String propertyId, int month, int year) async {
    // Calculate previous month/year
    int prevMonth = month - 1;
    int prevYear = year;
    if (prevMonth <= 0) {
      prevMonth = 12;
      prevYear = year - 1;
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT taw.tenant_id, taw.ac_watt_usage
      FROM tenant_ac_watt_usage taw
      INNER JOIN expenses e ON taw.expense_id = e.id
      WHERE e.property_id = ? AND e.month = ? AND e.year = ?
    ''', [propertyId, prevMonth, prevYear]);

    Map<String, double> result = {};
    for (var map in maps) {
      result[map['tenant_id'] as String] = (map['ac_watt_usage'] as num).toDouble();
    }
    return result;
  }

  Future<void> deleteTenantACWattUsageByExpense(String expenseId) async {
    final db = await database;
    await db.delete(
      'tenant_ac_watt_usage',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
  }
}