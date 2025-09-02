import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/property.dart';
import '../../models/tenant.dart';
import '../../models/rental_unit.dart';
import '../../database/database_helper.dart';

class Step2TenantOverview extends StatefulWidget {
  final Property property;
  final List<Tenant> tenants;
  final Map<String, double> previousACReadings;
  final Function(Map<String, double>) onACReadingsUpdated;

  const Step2TenantOverview({
    super.key,
    required this.property,
    required this.tenants,
    required this.previousACReadings,
    required this.onACReadingsUpdated,
  });

  @override
  State<Step2TenantOverview> createState() => _Step2TenantOverviewState();
}

class _Step2TenantOverviewState extends State<Step2TenantOverview> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final Map<String, TextEditingController> _acReadingControllers = {};
  List<RentalUnit> _units = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _initializeControllers();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoading = true);
    
    try {
      final units = await _databaseHelper.getRentalUnitsByProperty(widget.property.id);
      setState(() {
        _units = units;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading units: $e')),
        );
      }
    }
  }

  void _initializeControllers() {
    for (final tenant in widget.tenants) {
      final controller = TextEditingController();
      final existingReading = widget.previousACReadings[tenant.id];
      if (existingReading != null) {
        controller.text = existingReading.toString();
      } else if (tenant.previousACReading > 0) {
        controller.text = tenant.previousACReading.toString();
      } else if (tenant.currentACReading > 0) {
        // Use current reading as previous reading for first-time calculation
        controller.text = tenant.currentACReading.toString();
      }
      _acReadingControllers[tenant.id] = controller;
    }
  }

  void _updateACReadings() {
    final readings = <String, double>{};
    for (final entry in _acReadingControllers.entries) {
      final value = double.tryParse(entry.value.text);
      if (value != null) {
        readings[entry.key] = value;
      }
    }
    widget.onACReadingsUpdated(readings);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.people,
              color: Theme.of(context).primaryColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text(
              'Tenant Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Review tenants and set up AC meter readings for ${widget.property.name}',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (widget.tenants.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPropertySummary(),
          const SizedBox(height: 24),
          _buildTenantsSection(),
        ],
      ),
    );
  }

  Widget _buildPropertySummary() {
    final occupiedUnits = _units.where((unit) => 
        widget.tenants.any((tenant) => tenant.rentalUnitId == unit.id)).length;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Property Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSummaryItem(
                  icon: Icons.meeting_room,
                  label: 'Total Units',
                  value: '${_units.length}',
                ),
                const SizedBox(width: 24),
                _buildSummaryItem(
                  icon: Icons.people,
                  label: 'Active Tenants',
                  value: '${widget.tenants.length}',
                ),
                const SizedBox(width: 24),
                _buildSummaryItem(
                  icon: Icons.home,
                  label: 'Occupied',
                  value: '$occupiedUnits/${_units.length}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTenantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AC Meter Setup',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set previous AC meter readings for accurate calculation. This should be last month\'s ending reading.',
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        ...widget.tenants.map((tenant) => _buildTenantCard(tenant)),
      ],
    );
  }

  Widget _buildTenantCard(Tenant tenant) {
    final unit = _units.firstWhere(
      (u) => u.id == tenant.rentalUnitId,
      orElse: () => RentalUnit(
        propertyId: widget.property.id,
        unitNumber: 'Unknown',
        name: 'Unknown',
        monthlyRent: 0,
      ),
    );
    
    final controller = _acReadingControllers[tenant.id]!;
    final isNewTenant = tenant.previousACReading == 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).primaryColor,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Unit: ${unit.unitNumber}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (isNewTenant)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'New Tenant',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Previous AC Reading (kWh)',
                hintText: isNewTenant ? 'Enter starting meter reading' : 'Enter previous reading',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.electric_meter),
                helperText: isNewTenant
                    ? 'This tenant is new - enter their starting AC meter reading'
                    : 'Enter the AC meter reading from last month\'s bill (ending reading)',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => _updateACReadings(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Tenants',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add tenants to this property first',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _acReadingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
