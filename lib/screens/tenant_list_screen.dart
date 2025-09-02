import 'package:flutter/material.dart';
import '../models/tenant.dart';
import '../models/property.dart';
import '../models/rental_unit.dart';
import '../database/database_helper.dart';
import 'tenant_form_screen.dart';

class TenantListScreen extends StatefulWidget {
  const TenantListScreen({super.key});

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Tenant> _tenants = [];
  Map<String, Property> _propertiesMap = {};
  Map<String, RentalUnit> _unitsMap = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load tenants
      final tenants = await _databaseHelper.getTenants();

      // Load properties and units for reference
      final properties = await _databaseHelper.getProperties();
      final propertiesMap = <String, Property>{};
      for (final property in properties) {
        propertiesMap[property.id] = property;
      }

      final unitsMap = <String, RentalUnit>{};
      for (final property in properties) {
        final units = await _databaseHelper.getRentalUnitsByProperty(property.id);
        for (final unit in units) {
          unitsMap[unit.id] = unit;
        }
      }

      setState(() {
        _tenants = tenants;
        _propertiesMap = propertiesMap;
        _unitsMap = unitsMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tenants: $e')),
        );
      }
    }
  }

  List<Tenant> get _filteredTenants {
    if (_searchQuery.isEmpty) {
      return _tenants;
    }
    return _tenants.where((tenant) =>
        tenant.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (tenant.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
        (tenant.phone?.contains(_searchQuery) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenants'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTenants.isEmpty
                    ? _buildEmptyState()
                    : _buildTenantList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddTenant(),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search tenants...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (query) {
          setState(() => _searchQuery = query);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No tenants found for "$_searchQuery"',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try different search terms',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Tenants Yet',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first tenant to get started',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddTenant(),
            icon: const Icon(Icons.add),
            label: const Text('Add Tenant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _filteredTenants.length,
        itemBuilder: (context, index) {
          final tenant = _filteredTenants[index];
          return _buildTenantCard(tenant);
        },
      ),
    );
  }

  Widget _buildTenantCard(Tenant tenant) {
    // Get property and unit info if available
    final property = tenant.propertyId != null ? _propertiesMap[tenant.propertyId] : null;
    final unit = tenant.rentalUnitId != null ? _unitsMap[tenant.rentalUnitId] : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 3,
      child: InkWell(
        onTap: () => _navigateToEditTenant(tenant),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tenant.isActive ? Colors.green : Colors.grey,
                    child: Text(
                      tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : 'T',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (tenant.email != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            tenant.email!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleTenantAction(value, tenant),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit Tenant'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'update_reading',
                        child: ListTile(
                          leading: Icon(Icons.electric_meter),
                          title: Text('Update AC Reading'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (!tenant.isActive)
                        const PopupMenuItem(
                          value: 'activate',
                          child: ListTile(
                            leading: Icon(Icons.check_circle, color: Colors.green),
                            title: Text('Activate'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                      else
                        const PopupMenuItem(
                          value: 'deactivate',
                          child: ListTile(
                            leading: Icon(Icons.pause_circle, color: Colors.orange),
                            title: Text('Deactivate'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (tenant.phone != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      tenant.phone!,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],

              if (property != null || unit != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.home, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${property?.name ?? 'Unknown Property'}${unit != null ? ' - ${unit.unitNumber}' : ''}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // AC Usage Information
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Current AC Reading',
                      '${tenant.currentACReading.toStringAsFixed(1)} kWh',
                      Icons.electric_meter,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Monthly Usage',
                      '${tenant.acUsageKWh.toStringAsFixed(1)} kWh',
                      Icons.trending_up,
                      tenant.acUsageKWh > 0 ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Status indicators
              Row(
                children: [
                  _buildStatusChip(
                    tenant.isActive ? 'Active' : 'Inactive',
                    tenant.isActive ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  if (tenant.hasValidACReadings)
                    _buildStatusChip('Valid Readings', Colors.blue)
                  else
                    _buildStatusChip('Check Readings', Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _handleTenantAction(String action, Tenant tenant) {
    switch (action) {
      case 'edit':
        _navigateToEditTenant(tenant);
        break;
      case 'update_reading':
        _showUpdateReadingDialog(tenant);
        break;
      case 'activate':
      case 'deactivate':
        _toggleTenantStatus(tenant);
        break;
      case 'delete':
        _showDeleteConfirmation(tenant);
        break;
    }
  }

  void _navigateToAddTenant() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TenantFormScreen()),
    ).then((_) => _loadData());
  }

  void _navigateToEditTenant(Tenant tenant) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TenantFormScreen(tenant: tenant)),
    ).then((_) => _loadData());
  }

  void _showUpdateReadingDialog(Tenant tenant) {
    final controller = TextEditingController(text: tenant.currentACReading.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update AC Reading for ${tenant.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Previous Reading: ${tenant.previousACReading.toStringAsFixed(1)} kWh'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New AC Reading (kWh)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newReading = double.tryParse(controller.text);
              if (newReading != null && newReading >= tenant.previousACReading) {
                Navigator.pop(context);
                _updateACReading(tenant, newReading);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid reading. Must be greater than or equal to previous reading.')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateACReading(Tenant tenant, double newReading) async {
    try {
      final updatedTenant = tenant.copyWith(
        previousACReading: tenant.currentACReading,
        currentACReading: newReading,
      );

      await _databaseHelper.updateTenant(updatedTenant);

      // Record AC usage history
      await _databaseHelper.insertACUsageHistory(
        tenant.id,
        DateTime.now(),
        newReading,
        newReading - tenant.currentACReading,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AC reading updated successfully')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating AC reading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTenantStatus(Tenant tenant) async {
    try {
      final updatedTenant = tenant.copyWith(isActive: !tenant.isActive);
      await _databaseHelper.updateTenant(updatedTenant);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tenant ${tenant.isActive ? 'deactivated' : 'activated'}')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating tenant status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Tenant tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: Text('Are you sure you want to delete "${tenant.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTenant(tenant);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTenant(Tenant tenant) async {
    try {
      await _databaseHelper.deleteTenant(tenant.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant deleted')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting tenant: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}