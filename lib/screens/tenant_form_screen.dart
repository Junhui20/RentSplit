import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tenant.dart';
import '../models/property.dart';
import '../models/rental_unit.dart';
import '../models/utility_provider.dart';
import '../database/database_helper.dart';
import '../widgets/responsive_helper.dart';

class TenantFormScreen extends StatefulWidget {
  final Tenant? tenant; // null for new tenant, existing tenant for edit

  const TenantFormScreen({super.key, this.tenant});

  @override
  State<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends State<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  String _selectedCountryCode = '+60'; // Default to Malaysia

  String? _selectedPropertyId;
  String? _selectedUnitId;
  bool _isActive = true;
  bool _isLoading = false;

  List<Property> _availableProperties = [];
  List<RentalUnit> _availableUnits = [];
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadProperties();
  }

  void _initializeForm() {
    if (widget.tenant != null) {
      // Editing existing tenant
      final tenant = widget.tenant!;
      _nameController.text = tenant.name;
      _emailController.text = tenant.email ?? '';
      // Parse phone number to extract country code and number
      final phone = tenant.phone ?? '';
      if (phone.isNotEmpty) {
        // Try to extract country code from phone number
        final validCodes = ['+60', '+65', '+62', '+66', '+84', '+63', '+1', '+44', '+86', '+91'];
        bool foundValidCode = false;

        for (final code in validCodes) {
          if (phone.startsWith(code)) {
            _selectedCountryCode = code;
            // Extract the phone number part after the country code
            _phoneController.text = phone.substring(code.length).trim();
            foundValidCode = true;
            break;
          }
        }

        if (!foundValidCode) {
          // No valid country code found, use default and keep full phone
          _selectedCountryCode = '+60'; // Default to Malaysia
          _phoneController.text = phone.startsWith('+') ? phone.substring(1) : phone;
        }
      }
      _emergencyPhoneController.text = tenant.emergencyContact ?? '';
      _selectedPropertyId = tenant.propertyId;
      _selectedUnitId = tenant.rentalUnitId;
      _isActive = tenant.isActive;
    }
  }

  Future<void> _loadProperties() async {
    try {
      final properties = await _databaseHelper.getProperties();
      setState(() {
        _availableProperties = properties.where((p) => p.isActive).toList();
      });
      
      // Load units for selected property
      if (_selectedPropertyId != null) {
        _loadUnitsForProperty(_selectedPropertyId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading properties: $e')),
        );
      }
    }
  }

  Future<void> _loadUnitsForProperty(String propertyId) async {
    try {
      final units = await _databaseHelper.getRentalUnitsByProperty(propertyId);
      setState(() {
        // Filter units to only show available ones with capacity (unless editing existing tenant in same unit)
        _availableUnits = units.where((u) =>
          u.isAvailable && (u.hasCapacity || widget.tenant?.rentalUnitId == u.id)
        ).toList();

        // Reset unit selection if current unit is not available for this property
        if (_selectedUnitId != null && !_availableUnits.any((u) => u.id == _selectedUnitId)) {
          _selectedUnitId = null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading units: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tenant == null ? 'Add Tenant' : 'Edit Tenant'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (widget.tenant != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPersonalInfoSection(),
            const SizedBox(height: 24),
            _buildPropertyAssignmentSection(),
            const SizedBox(height: 24),
            _buildStatusSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter tenant name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Use different layouts based on screen size
            ResponsiveHelper.getScreenWidth(context) < 350
                ? Column(
                    children: [
                      // Country code dropdown (full width on very small screens)
                      DropdownButtonFormField<String>(
                        value: _selectedCountryCode,
                        decoration: const InputDecoration(
                          labelText: 'Country Code',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag),
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: '+60', child: Text('+60 🇲🇾 Malaysia')),
                          DropdownMenuItem(value: '+65', child: Text('+65 🇸🇬 Singapore')),
                          DropdownMenuItem(value: '+62', child: Text('+62 🇮🇩 Indonesia')),
                          DropdownMenuItem(value: '+66', child: Text('+66 🇹🇭 Thailand')),
                          DropdownMenuItem(value: '+84', child: Text('+84 🇻🇳 Vietnam')),
                          DropdownMenuItem(value: '+63', child: Text('+63 🇵🇭 Philippines')),
                          DropdownMenuItem(value: '+1', child: Text('+1 🇺🇸 USA')),
                          DropdownMenuItem(value: '+44', child: Text('+44 🇬🇧 UK')),
                          DropdownMenuItem(value: '+86', child: Text('+86 🇨🇳 China')),
                          DropdownMenuItem(value: '+91', child: Text('+91 🇮🇳 India')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCountryCode = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      // Phone number field (full width)
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone),
                          prefixText: '$_selectedCountryCode ',
                          hintText: '123456789',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9\-\s]')),
                        ],
                        validator: (value) {
                          if (value?.trim().isEmpty == true) {
                            return 'Phone number is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // Country code dropdown (side by side on larger screens)
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCountryCode,
                          decoration: const InputDecoration(
                            labelText: 'Code',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: '+60', child: Text('+60🇲🇾', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: '+65', child: Text('+65🇸🇬', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: '+62', child: Text('+62🇮🇩', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: '+66', child: Text('+66🇹🇭', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: '+84', child: Text('+84🇻🇳', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: '+63', child: Text('+63🇵🇭', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: '+1', child: Text('+1🇺🇸', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: '+44', child: Text('+44🇬🇧', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: '+86', child: Text('+86🇨🇳', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: '+91', child: Text('+91🇮🇳', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCountryCode = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Phone number field
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone),
                            hintText: '123456789',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9\-\s]')),
                          ],
                          validator: (value) {
                            if (value?.trim().isEmpty == true) {
                              return 'Phone number is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyPhoneController,
              decoration: InputDecoration(
                labelText: 'Emergency Contact',
                prefixIcon: const Icon(Icons.emergency),
                prefixText: '$_selectedCountryCode ',
                hintText: '123456789',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\-\s]')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyAssignmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Property Assignment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPropertyId,
              decoration: const InputDecoration(
                labelText: 'Property',
                prefixIcon: Icon(Icons.home_work),
              ),
              items: _availableProperties.map((property) {
                return DropdownMenuItem(
                  value: property.id,
                  child: Text('${property.name} - ${property.state.displayName}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPropertyId = value;
                  _selectedUnitId = null; // Reset unit selection
                  _availableUnits = [];
                });
                if (value != null) {
                  _loadUnitsForProperty(value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedUnitId,
              decoration: const InputDecoration(
                labelText: 'Rental Unit (Optional)',
                prefixIcon: Icon(Icons.apartment),
              ),
              items: _availableUnits.map((unit) {
                final occupancyText = '(${unit.currentOccupancy}/${unit.maxOccupancy})';
                return DropdownMenuItem(
                  value: unit.id,
                  child: Text('${unit.unitNumber} - RM ${unit.monthlyRent.toStringAsFixed(2)} $occupancyText'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedUnitId = value;
                });
              },
            ),
            if (_selectedPropertyId == null)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Select a property to assign this tenant',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }





  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Active Tenant'),
              subtitle: Text(_isActive ? 'Tenant is currently active' : 'Tenant is inactive'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
              secondary: Icon(
                _isActive ? Icons.check_circle : Icons.pause_circle,
                color: _isActive ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveTenant,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.tenant == null ? 'Add Tenant' : 'Update Tenant'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTenant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Helper function to format phone number with country code
      String? formatPhoneNumber(String phoneText, String countryCode) {
        if (phoneText.trim().isEmpty) return null;
        final cleanPhone = phoneText.trim();
        // Check if phone already starts with the country code
        if (cleanPhone.startsWith(countryCode)) {
          return cleanPhone; // Already has country code, don't add again
        }
        return '$countryCode$cleanPhone'; // Add country code
      }

      final tenant = Tenant(
        id: widget.tenant?.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: formatPhoneNumber(_phoneController.text, _selectedCountryCode),
        emergencyContact: formatPhoneNumber(_emergencyPhoneController.text, _selectedCountryCode),
        isActive: _isActive,
        propertyId: _selectedPropertyId,
        rentalUnitId: _selectedUnitId,
        createdAt: widget.tenant?.createdAt,
      );

      if (widget.tenant == null) {
        // Adding new tenant
        await _databaseHelper.insertTenant(tenant);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tenant added successfully')),
          );
        }
      } else {
        // Updating existing tenant
        await _databaseHelper.updateTenant(tenant);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tenant updated successfully')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving tenant: $e'),
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

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: Text('Are you sure you want to delete "${widget.tenant!.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTenant();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTenant() async {
    setState(() => _isLoading = true);

    try {
      await _databaseHelper.deleteTenant(widget.tenant!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant deleted successfully')),
        );
        Navigator.pop(context, true);
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }
}