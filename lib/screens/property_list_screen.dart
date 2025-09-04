import 'package:flutter/material.dart';
import '../models/property.dart';
import '../models/rental_unit.dart';
import '../models/utility_provider.dart';
import '../models/malaysian_currency.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import 'property_form_screen.dart';
import 'property_details_screen.dart';
import 'unit_form_screen.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Property> _properties = [];
  Map<String, List<RentalUnit>> _unitsByProperty = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() => _isLoading = true);

    try {
      // Load properties from database
      final properties = await _databaseHelper.getProperties();

      // Load units for each property
      final Map<String, List<RentalUnit>> unitsByProperty = {};
      for (final property in properties) {
        final units = await _databaseHelper.getRentalUnitsByProperty(property.id);
        unitsByProperty[property.id] = units;
      }

      setState(() {
        _properties = properties;
        _unitsByProperty = unitsByProperty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading properties: $e')),
        );
      }
    }
  }

  List<Property> get _filteredProperties {
    if (_searchQuery.isEmpty) {
      return _properties;
    }
    return _properties.where((property) =>
        property.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        property.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        property.state.displayName.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Properties'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProperties,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProperties.isEmpty
                    ? _buildEmptyState()
                    : _buildPropertyList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddProperty(),
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
          hintText: 'Search properties by name, address, or state...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
          filled: true,
          fillColor: Colors.grey.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              'No properties found for "$_searchQuery"',
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
          Icon(Icons.home_work, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Properties Yet',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first property to get started',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddProperty(),
            icon: const Icon(Icons.add),
            label: const Text('Add Property'),
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

  Widget _buildPropertyList() {
    return RefreshIndicator(
      onRefresh: _loadProperties,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _filteredProperties.length,
        itemBuilder: (context, index) {
          final property = _filteredProperties[index];
          final units = _unitsByProperty[property.id] ?? [];
          return _buildPropertyCard(property, units);
        },
      ),
    );
  }

  Widget _buildPropertyCard(Property property, List<RentalUnit> units) {
    final int totalUnits = units.length;
    final int occupiedUnits = units.where((u) => u.currentOccupancy > 0).length;
    final int availableUnits = units.where((u) => u.isAvailable).length;
    final double totalMonthlyRent = units.fold(0.0, (sum, u) => sum + u.monthlyRent);
    final double occupancyRate = totalUnits > 0 ? (occupiedUnits / totalUnits) * 100 : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        elevation: 8,
        shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: InkWell(
          onTap: () => _navigateToPropertyDetails(property),
          borderRadius: BorderRadius.circular(18),
          splashColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
          highlightColor: AppTheme.primaryBlue.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  Colors.grey.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                  spreadRadius: 0,
                ),
              ],
            ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue.withValues(alpha: 0.15),
                          AppTheme.primaryBlue.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.home_work,
                      color: Theme.of(context).primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                property.state.displayName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                property.propertyType.displayName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handlePropertyAction(value, property),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit Property'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add_unit',
                        child: ListTile(
                          leading: Icon(Icons.add_home),
                          title: Text('Add Unit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'view_details',
                        child: ListTile(
                          leading: Icon(Icons.info),
                          title: Text('View Details'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (!property.isActive)
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
              const SizedBox(height: 12),
              Text(
                property.address,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              // Property stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Units',
                        '$totalUnits',
                        Icons.apartment,
                        Colors.blue,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Occupancy',
                        '${occupancyRate.toStringAsFixed(0)}%',
                        Icons.people,
                        occupancyRate >= 80 ? Colors.green :
                        occupancyRate >= 50 ? Colors.orange : Colors.red,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Monthly Rent',
                        totalMonthlyRent > 999
                          ? 'RM${(totalMonthlyRent / 1000).toStringAsFixed(1)}k'
                          : MalaysianCurrency.format(totalMonthlyRent),
                        Icons.attach_money,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),

              if (totalUnits > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusChip('$occupiedUnits Occupied', Colors.green),
                    const SizedBox(width: 8),
                    _buildStatusChip('$availableUnits Available', Colors.blue),
                    if (totalUnits - occupiedUnits - availableUnits > 0) ...[
                      const SizedBox(width: 8),
                      _buildStatusChip('${totalUnits - occupiedUnits - availableUnits} Maintenance', Colors.orange),
                    ],
                  ],
                ),
              ],

              if (!property.isActive) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'INACTIVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 6),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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

  void _handlePropertyAction(String action, Property property) {
    switch (action) {
      case 'edit':
        _navigateToEditProperty(property);
        break;
      case 'add_unit':
        _navigateToAddUnit(property);
        break;
      case 'view_details':
        _navigateToPropertyDetails(property);
        break;
      case 'activate':
      case 'deactivate':
        _togglePropertyStatus(property);
        break;
      case 'delete':
        _showDeleteConfirmation(property);
        break;
    }
  }

  void _navigateToAddProperty() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PropertyFormScreen()),
    ).then((_) => _loadProperties());
  }

  void _navigateToEditProperty(Property property) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PropertyFormScreen(property: property)),
    ).then((_) => _loadProperties());
  }

  void _navigateToAddUnit(Property property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnitFormScreen(property: property),
      ),
    ).then((_) => _loadProperties());
  }

  void _navigateToPropertyDetails(Property property) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PropertyDetailsScreen(property: property)),
    ).then((_) => _loadProperties()); // Refresh the list when returning
  }

  Future<void> _togglePropertyStatus(Property property) async {
    try {
      final updatedProperty = property.copyWith(isActive: !property.isActive);
      await _databaseHelper.updateProperty(updatedProperty);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Property ${property.isActive ? 'deactivated' : 'activated'}')),
        );
        _loadProperties();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating property status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Property property) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Property'),
        content: Text('Are you sure you want to delete "${property.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProperty(property);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProperty(Property property) async {
    try {
      await _databaseHelper.deleteProperty(property.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property deleted')),
        );
        _loadProperties();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting property: $e'),
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