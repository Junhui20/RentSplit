import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rental_unit.dart';
import '../models/property.dart';
import '../models/utility_provider.dart';
import '../database/database_helper.dart';

class UnitFormScreen extends StatefulWidget {
  final Property property;
  final RentalUnit? unit; // null for new unit, existing unit for edit

  const UnitFormScreen({
    super.key,
    required this.property,
    this.unit,
  });

  @override
  State<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends State<UnitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _unitNumberController = TextEditingController();
  final _monthlyRentController = TextEditingController();
  final _maxOccupancyController = TextEditingController();
  final _notesController = TextEditingController();

  RentalUnitType _selectedUnitType = RentalUnitType.unit;
  bool _hasAirCon = false;
  bool _hasPrivateBathroom = false;
  bool _isLoading = false;

  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.unit != null) {
      // Editing existing unit
      final unit = widget.unit!;
      _unitNumberController.text = unit.unitNumber;
      _selectedUnitType = unit.unitType;
      _monthlyRentController.text = unit.monthlyRent.toStringAsFixed(2);
      _maxOccupancyController.text = unit.maxOccupancy.toString();
      _notesController.text = unit.notes ?? '';
      _hasAirCon = unit.hasAirCon;
      _hasPrivateBathroom = unit.hasPrivateBathroom;
    } else {
      // Default value for new units
      _maxOccupancyController.text = '1';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.unit == null ? 'Add Unit' : 'Edit Unit'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: _saveUnit,
              child: const Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPropertyHeader(),
              const SizedBox(height: 24),
              _buildBasicInformationSection(),
              const SizedBox(height: 24),
              _buildRentalDetailsSection(),
              const SizedBox(height: 24),
              _buildSimpleAmenitiesSection(),
              const SizedBox(height: 24),
              _buildNotesSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPropertyHeader() {
    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.home_work,
              color: Theme.of(context).primaryColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.property.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.property.state.displayName,
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInformationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Basic Information'),
            TextFormField(
              controller: _unitNumberController,
              decoration: const InputDecoration(
                labelText: 'Unit Number *',
                hintText: 'e.g., Room 1, Master Bedroom, A-101',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room),
              ),
              validator: (value) {
                if (value?.trim().isEmpty == true) {
                  return 'Unit number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RentalUnitType>(
              value: _selectedUnitType,
              decoration: const InputDecoration(
                labelText: 'Unit Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: RentalUnitType.values.map((type) => DropdownMenuItem(
                value: type,
                child: Text(type.displayName),
              )).toList(),
              onChanged: (RentalUnitType? value) {
                setState(() {
                  _selectedUnitType = value ?? RentalUnitType.unit;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Rental Details'),
            TextFormField(
              controller: _monthlyRentController,
              decoration: const InputDecoration(
                labelText: 'Monthly Rent *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                prefixText: 'RM ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              validator: (value) {
                if (value?.trim().isEmpty == true) {
                  return 'Monthly rent is required';
                }
                final rent = double.tryParse(value!);
                if (rent == null || rent <= 0) {
                  return 'Please enter a valid rent amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxOccupancyController,
              decoration: const InputDecoration(
                labelText: 'Max Occupancy *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
                hintText: 'Number of people',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value?.trim().isEmpty == true) {
                  return 'Max occupancy is required';
                }
                final occupancy = int.tryParse(value!);
                if (occupancy == null || occupancy <= 0) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleAmenitiesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Basic Amenities'),
            CheckboxListTile(
              title: const Text('Air Conditioning'),
              value: _hasAirCon,
              onChanged: (bool? value) {
                setState(() {
                  _hasAirCon = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: const Text('Private Bathroom'),
              value: _hasPrivateBathroom,
              onChanged: (bool? value) {
                setState(() {
                  _hasPrivateBathroom = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Notes'),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                hintText: 'Any additional information about this unit...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create rental unit object
      final unit = RentalUnit(
        id: widget.unit?.id, // null for new unit, existing ID for edit
        propertyId: widget.property.id,
        unitNumber: _unitNumberController.text.trim(),
        name: _unitNumberController.text.trim(), // Use unit number as name
        unitType: _selectedUnitType,
        status: RentalUnitStatus.available, // Default status
        monthlyRent: double.parse(_monthlyRentController.text),
        maxOccupancy: int.parse(_maxOccupancyController.text),
        hasAirCon: _hasAirCon,
        hasPrivateBathroom: _hasPrivateBathroom,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Save to database
      if (widget.unit == null) {
        // Create new unit
        await _databaseHelper.insertRentalUnit(unit);
      } else {
        // Update existing unit
        await _databaseHelper.updateRentalUnit(unit);
      }

      if (mounted) {
        Navigator.pop(context, unit);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.unit == null ? 'Unit created successfully' : 'Unit updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving unit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _unitNumberController.dispose();
    _monthlyRentController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
