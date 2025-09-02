import 'package:flutter/material.dart';
import '../models/property.dart';
import '../models/rental_unit.dart';
import '../models/tenant.dart';
import '../models/utility_provider.dart';
import '../models/internet_provider.dart';
import '../models/malaysian_currency.dart';
import '../database/database_helper.dart';
import 'property_form_screen.dart';
import 'unit_form_screen.dart';
import 'tenant_form_screen.dart';
import 'calculation_wizard_screen.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final Property property;

  const PropertyDetailsScreen({
    super.key,
    required this.property,
  });

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late Property _property;
  List<RentalUnit> _units = [];
  List<Tenant> _tenants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _property = widget.property;
    _loadPropertyData();
  }

  Future<void> _loadPropertyData() async {
    setState(() => _isLoading = true);

    try {
      // Load units for this property
      final units = await _databaseHelper.getRentalUnitsByProperty(_property.id);

      // Load tenants for this property
      final tenants = await _databaseHelper.getTenantsByProperty(_property.id);

      setState(() {
        _units = units;
        _tenants = tenants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading property data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_property.name),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Edit Property'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Property', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPropertyData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPropertyOverview(),
                    const SizedBox(height: 24),
                    _buildUnitsSection(),
                    const SizedBox(height: 24),
                    _buildTenantsSection(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPropertyOverview() {
    final internetProvider = MalaysianInternetProviders.getProviderById(_property.internetProviderId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home_work, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Property Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Name', _property.name),
            _buildInfoRow('Address', _property.address),
            _buildInfoRow('State', _property.state.displayName),
            _buildInfoRow('Type', _property.propertyType.displayName),
            _buildInfoRow('Rooms', '${_property.totalRooms}'),
            _buildInfoRow('Bathrooms', '${_property.totalBathrooms}'),
            _buildInfoRow('Square Feet', '${_property.totalSquareFeet.toStringAsFixed(0)} sq ft'),
            const Divider(height: 24),
            Text(
              'Utility Providers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Electricity', _property.electricityProvider?.shortName ?? 'Unknown'),
            _buildInfoRow('Water', _property.waterProvider?.shortName ?? 'Unknown'),
            _buildInfoRow('Internet', internetProvider?.displayName ?? 'Unknown'),
            const Divider(height: 24),
            Text(
              'Rental Pricing',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Base Rental', MalaysianCurrency.format(_property.baseRentalPrice)),
            _buildInfoRow('Internet Fee', MalaysianCurrency.format(_property.internetFixedFee)),
            _buildInfoRow('Total Monthly', MalaysianCurrency.format(_property.baseRentalPrice + _property.internetFixedFee)),
            if (_property.contactPhone != null || _property.contactEmail != null) ...[
              const Divider(height: 24),
              Text(
                'Contact Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_property.contactPhone != null)
                _buildInfoRow('Phone', _property.contactPhone!),
              if (_property.contactEmail != null)
                _buildInfoRow('Email', _property.contactEmail!),
            ],
            if (_property.notes != null) ...[
              const Divider(height: 24),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(_property.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.meeting_room, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Rental Units (${_units.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAddUnit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Unit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_units.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.meeting_room_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No units added yet',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      Text(
                        'Add units to start managing tenants',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: _units.map((unit) => _buildUnitCard(unit)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitCard(RentalUnit unit) {

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.meeting_room, color: Theme.of(context).primaryColor),
        ),
        title: Text(unit.unitNumber),
        subtitle: Text('${unit.unitType.displayName} - ${MalaysianCurrency.format(unit.monthlyRent)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Occupancy count display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '(${unit.currentOccupancy}/${unit.maxOccupancy})',
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: unit.hasCapacity ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unit.hasCapacity ? 'Available' : 'Full',
                style: TextStyle(
                  color: unit.hasCapacity ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleUnitAction(value, unit),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantsSection() {
    final activeTenants = _tenants.where((t) => t.isActive).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Tenants (${activeTenants.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAddTenant(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Tenant'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (activeTenants.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No active tenants',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      Text(
                        'Add tenants to start tracking expenses',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: activeTenants.map((tenant) => _buildTenantCard(tenant)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantCard(Tenant tenant) {
    final unit = _units.firstWhere((u) => u.id == tenant.rentalUnitId, orElse: () => RentalUnit(
      propertyId: _property.id,
      unitNumber: 'Unknown',
      name: 'Unknown',
      monthlyRent: 0,
    ));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.person, color: Theme.of(context).primaryColor),
        ),
        title: Text(tenant.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unit: ${unit.unitNumber}'),
            if (tenant.email != null) Text('Email: ${tenant.email}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleTenantAction(value, tenant),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildActionButton(
                  'Calculate Expenses',
                  Icons.calculate,
                  Colors.blue,
                  () => _navigateToCalculation(),
                ),
                _buildActionButton(
                  'View Reports',
                  Icons.analytics,
                  Colors.green,
                  () => _navigateToReports(),
                ),
                _buildActionButton(
                  'Add Expense',
                  Icons.receipt,
                  Colors.orange,
                  () => _navigateToAddExpense(),
                ),
                _buildActionButton(
                  'Property Settings',
                  Icons.settings,
                  Colors.purple,
                  () => _editProperty(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Action handlers
  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _editProperty();
        break;
      case 'delete':
        _deleteProperty();
        break;
    }
  }

  void _handleUnitAction(String action, RentalUnit unit) {
    switch (action) {
      case 'edit':
        _editUnit(unit);
        break;
      case 'delete':
        _deleteUnit(unit);
        break;
    }
  }

  void _handleTenantAction(String action, Tenant tenant) {
    switch (action) {
      case 'edit':
        _editTenant(tenant);
        break;
      case 'deactivate':
        _deactivateTenant(tenant);
        break;
    }
  }

  // Navigation methods
  void _editProperty() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyFormScreen(property: _property),
      ),
    ).then((result) {
      if (result != null && result is Property) {
        setState(() {
          _property = result;
        });
      }
      _loadPropertyData();
    });
  }

  void _navigateToAddUnit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnitFormScreen(property: _property),
      ),
    ).then((_) => _loadPropertyData());
  }

  void _editUnit(RentalUnit unit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnitFormScreen(property: _property, unit: unit),
      ),
    ).then((_) => _loadPropertyData());
  }

  void _navigateToAddTenant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TenantFormScreen(),
      ),
    ).then((_) => _loadPropertyData());
  }

  void _editTenant(Tenant tenant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TenantFormScreen(tenant: tenant),
      ),
    ).then((_) => _loadPropertyData());
  }

  // Delete operations
  Future<void> _deleteProperty() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Property'),
        content: Text('Are you sure you want to delete "${_property.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseHelper.deleteProperty(_property.id);
        if (mounted) {
          Navigator.pop(context); // Go back to property list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Property deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting property: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteUnit(RentalUnit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Unit'),
        content: Text('Are you sure you want to delete unit "${unit.unitNumber}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseHelper.deleteRentalUnit(unit.id);
        _loadPropertyData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unit deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting unit: $e')),
          );
        }
      }
    }
  }

  Future<void> _deactivateTenant(Tenant tenant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Tenant'),
        content: Text('Are you sure you want to deactivate "${tenant.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final updatedTenant = tenant.copyWith(isActive: false);
        await _databaseHelper.updateTenant(updatedTenant);
        _loadPropertyData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tenant deactivated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deactivating tenant: $e')),
          );
        }
      }
    }
  }

  // Quick action navigation methods
  void _navigateToCalculation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalculationWizardScreen()),
    );
  }

  void _navigateToReports() {
    // TODO: Navigate to reports screen for this property
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reports feature coming soon')),
    );
  }

  void _navigateToAddExpense() {
    // TODO: Navigate to expense form for this property
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add expense feature coming soon')),
    );
  }
}