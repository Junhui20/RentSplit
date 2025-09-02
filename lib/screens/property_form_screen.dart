import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/property.dart';
import '../models/utility_provider.dart';
import '../models/internet_provider.dart';
import '../database/database_helper.dart';
import 'unit_form_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PropertyFormScreen extends StatefulWidget {
  final Property? property; // null for new property, existing property for edit

  const PropertyFormScreen({super.key, this.property});

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _totalRoomsController = TextEditingController();
  final _totalBathroomsController = TextEditingController();
  final _totalSquareFeetController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _notesController = TextEditingController();
  final _baseRentalPriceController = TextEditingController();
  final _internetFixedFeeController = TextEditingController();

  MalaysianState? _selectedState;
  PropertyType _selectedPropertyType = PropertyType.house;
  String? _selectedElectricityProvider;
  String? _selectedWaterProvider;
  InternetProvider _selectedInternetProvider = InternetProvider.unifi;
  bool _hasCommonAreas = true;
  bool _hasSharedUtilities = true;
  bool _hasIndividualMeters = false;
  bool _isActive = true;
  bool _isLoading = false;

  List<UtilityProvider> _availableElectricityProviders = [];
  List<UtilityProvider> _availableWaterProviders = [];

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadUtilityProviders();
  }

  void _initializeForm() {
    if (widget.property != null) {
      // Editing existing property
      final property = widget.property!;
      _nameController.text = property.name;
      _addressController.text = property.address;
      _selectedState = property.state;
      _selectedPropertyType = property.propertyType;
      _totalRoomsController.text = property.totalRooms.toString();
      _totalBathroomsController.text = property.totalBathrooms.toString();
      _totalSquareFeetController.text = property.totalSquareFeet.toString();
      _selectedElectricityProvider = property.electricityProviderId;
      _selectedWaterProvider = property.waterProviderId;
      _selectedInternetProvider = InternetProviderExtension.fromValue(property.internetProviderId);
      _baseRentalPriceController.text = property.baseRentalPrice.toString();
      _internetFixedFeeController.text = property.internetFixedFee.toString();
      _hasCommonAreas = property.hasCommonAreas;
      _hasSharedUtilities = property.hasSharedUtilities;
      _hasIndividualMeters = property.hasIndividualMeters;
      _contactPhoneController.text = property.contactPhone ?? '';
      _contactEmailController.text = property.contactEmail ?? '';
      _notesController.text = property.notes ?? '';
      _isActive = property.isActive;
    }
  }

  void _loadUtilityProviders() {
    // Load predefined utility providers
    _availableElectricityProviders = MalaysianUtilityProviders.electricityProviders;
    _availableWaterProviders = MalaysianUtilityProviders.waterProviders;

    // Filter providers based on selected state
    if (_selectedState != null) {
      _updateProvidersForState(_selectedState!);
    }
  }

  void _updateProvidersForState(MalaysianState state) {
    setState(() {
      _availableElectricityProviders = MalaysianUtilityProviders.electricityProviders
          .where((p) => p.servesState(state)).toList();
      _availableWaterProviders = MalaysianUtilityProviders.waterProviders
          .where((p) => p.servesState(state)).toList();

      // Reset selections if current provider doesn't serve the new state
      if (_selectedElectricityProvider != null &&
          !_availableElectricityProviders.any((p) => p.id == _selectedElectricityProvider)) {
        _selectedElectricityProvider = null;
      }
      if (_selectedWaterProvider != null &&
          !_availableWaterProviders.any((p) => p.id == _selectedWaterProvider)) {
        _selectedWaterProvider = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.property == null ? 'Add Property' : 'Edit Property'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Center(child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ))
          else
            TextButton(
              onPressed: _saveProperty,
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
              _buildBasicInformationSection(),
              const SizedBox(height: 24),
              _buildLocationSection(),
              const SizedBox(height: 24),
              _buildUtilityProvidersSection(),
              const SizedBox(height: 24),
              _buildRentalPricingSection(),
              const SizedBox(height: 24),
              _buildPropertyDetailsSection(),
              const SizedBox(height: 24),
              _buildUtilitySettingsSection(),
              const SizedBox(height: 24),
              _buildContactInformationSection(),
              const SizedBox(height: 24),
              _buildPhotosSection(),
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
          color: Colors.black87,
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
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Property Name *',
                hintText: 'e.g., Sunway Apartment, KL House',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              validator: (value) {
                if (value?.trim().isEmpty == true) {
                  return 'Property name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PropertyType>(
              value: _selectedPropertyType,
              decoration: const InputDecoration(
                labelText: 'Property Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.apartment),
              ),
              items: PropertyType.values.map((type) => DropdownMenuItem(
                value: type,
                child: Text(type.displayName),
              )).toList(),
              onChanged: (PropertyType? value) {
                setState(() {
                  _selectedPropertyType = value ?? PropertyType.house;
                });
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Property is active'),
              subtitle: const Text('Inactive properties won\'t appear in calculations'),
              value: _isActive,
              onChanged: (bool? value) {
                setState(() {
                  _isActive = value ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Location'),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Full Address *',
                hintText: '123, Jalan ABC, Taman XYZ, 47500 Subang Jaya, Selangor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 3,
              validator: (value) {
                if (value?.trim().isEmpty == true) {
                  return 'Address is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MalaysianState>(
              value: _selectedState,
              decoration: const InputDecoration(
                labelText: 'State *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map),
              ),
              items: MalaysianState.values.map((state) => DropdownMenuItem(
                value: state,
                child: Text(state.displayName),
              )).toList(),
              onChanged: (MalaysianState? value) {
                setState(() {
                  _selectedState = value;
                  if (value != null) {
                    _updateProvidersForState(value);
                  }
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a state';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilityProvidersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Utility Providers'),
            if (_selectedState == null)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(child: Text('Please select a state first to see available utility providers')),
                  ],
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                value: _selectedElectricityProvider,
                decoration: const InputDecoration(
                  labelText: 'Electricity Provider *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.electric_bolt),
                ),
                items: _availableElectricityProviders.map((provider) => DropdownMenuItem(
                  value: provider.id,
                  child: Text('${provider.shortName} - ${provider.name}'),
                )).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedElectricityProvider = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select an electricity provider';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedWaterProvider,
                decoration: const InputDecoration(
                  labelText: 'Water Provider *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop),
                ),
                items: _availableWaterProviders.map((provider) => DropdownMenuItem(
                  value: provider.id,
                  child: Text('${provider.shortName} - ${provider.name}'),
                )).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedWaterProvider = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a water provider';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<InternetProvider>(
                value: _selectedInternetProvider,
                decoration: const InputDecoration(
                  labelText: 'Internet Provider *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
                items: MalaysianInternetProviders.allProviders.map((provider) => DropdownMenuItem(
                  value: provider,
                  child: Text(provider.displayName),
                )).toList(),
                onChanged: (InternetProvider? value) {
                  setState(() {
                    _selectedInternetProvider = value ?? InternetProvider.unifi;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select an internet provider';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRentalPricingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Rental Pricing'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _baseRentalPriceController,
              decoration: const InputDecoration(
                labelText: 'Base Rental Price (RM)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                prefixText: 'RM ',
                helperText: 'Monthly rental price per room/unit',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the base rental price';
                }
                final price = double.tryParse(value);
                if (price == null || price < 0) {
                  return 'Please enter a valid price';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _internetFixedFeeController,
              decoration: InputDecoration(
                labelText: 'Internet Fixed Fee (RM)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.wifi),
                prefixText: 'RM ',
                helperText: 'Monthly internet fee (${_selectedInternetProvider.displayName})',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the internet fixed fee';
                }
                final fee = double.tryParse(value);
                if (fee == null || fee < 0) {
                  return 'Please enter a valid fee';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total monthly cost per tenant: RM ${_calculateTotalMonthlyFee().toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
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

  double _calculateTotalMonthlyFee() {
    final baseRental = double.tryParse(_baseRentalPriceController.text) ?? 0.0;
    final internetFee = double.tryParse(_internetFixedFeeController.text) ?? 0.0;
    return baseRental + internetFee;
  }

  Widget _buildPropertyDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Property Details'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _totalRoomsController,
                    decoration: const InputDecoration(
                      labelText: 'Total Rooms',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.bed),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value?.isNotEmpty == true) {
                        final num = int.tryParse(value!);
                        if (num == null || num <= 0) {
                          return 'Must be a positive number';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _totalBathroomsController,
                    decoration: const InputDecoration(
                      labelText: 'Total Bathrooms',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.bathroom),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value?.isNotEmpty == true) {
                        final num = int.tryParse(value!);
                        if (num == null || num <= 0) {
                          return 'Must be a positive number';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _totalSquareFeetController,
              decoration: const InputDecoration(
                labelText: 'Total Square Feet',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.square_foot),
                suffixText: 'sq ft',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilitySettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Utility Settings'),
            CheckboxListTile(
              title: const Text('Has Common Areas'),
              subtitle: const Text('Shared spaces like living room, kitchen'),
              value: _hasCommonAreas,
              onChanged: (bool? value) {
                setState(() {
                  _hasCommonAreas = value ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: const Text('Has Shared Utilities'),
              subtitle: const Text('Some utilities are shared among tenants'),
              value: _hasSharedUtilities,
              onChanged: (bool? value) {
                setState(() {
                  _hasSharedUtilities = value ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: const Text('Has Individual Meters'),
              subtitle: const Text('Each unit has separate utility meters'),
              value: _hasIndividualMeters,
              onChanged: (bool? value) {
                setState(() {
                  _hasIndividualMeters = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInformationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Contact Information'),
            TextFormField(
              controller: _contactPhoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+60 12-345 6789',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactEmailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'owner@example.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isNotEmpty == true && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Property Photos'),
            if (_selectedImages.isEmpty)
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('Add Property Photos', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedImages.length + 1,
                itemBuilder: (context, index) {
                  if (index == _selectedImages.length) {
                    return GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Colors.grey),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_selectedImages[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.camera_alt),
              label: Text(_selectedImages.isEmpty ? 'Add Photos' : 'Add More Photos'),
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
            _buildSectionHeader('Additional Notes'),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Any additional information about the property...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _imagePicker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((xfile) => File(xfile.path)));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create property object
      final property = Property(
        id: widget.property?.id, // null for new property, existing ID for edit
        ownerId: 'current_user', // In real app, get from authentication
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        state: _selectedState!,
        propertyType: _selectedPropertyType,
        totalRooms: int.tryParse(_totalRoomsController.text) ?? 1,
        totalBathrooms: int.tryParse(_totalBathroomsController.text) ?? 1,
        totalSquareFeet: double.tryParse(_totalSquareFeetController.text) ?? 0.0,
        electricityProviderId: _selectedElectricityProvider!,
        waterProviderId: _selectedWaterProvider!,
        internetProviderId: _selectedInternetProvider.value,
        baseRentalPrice: double.tryParse(_baseRentalPriceController.text) ?? 0.0,
        internetFixedFee: double.tryParse(_internetFixedFeeController.text) ?? 0.0,
        hasCommonAreas: _hasCommonAreas,
        hasSharedUtilities: _hasSharedUtilities,
        hasIndividualMeters: _hasIndividualMeters,
        contactPhone: _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
        contactEmail: _contactEmailController.text.trim().isEmpty ? null : _contactEmailController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        imageUrls: _selectedImages.map((file) => file.path).toList(), // Store local file paths for now
        isActive: _isActive,
      );

      // Save to database
      if (widget.property == null) {
        // Create new property
        await _databaseHelper.insertProperty(property);
      } else {
        // Update existing property
        await _databaseHelper.updateProperty(property);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.property == null ? 'Property created successfully' : 'Property updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // For new properties, ask if user wants to add units (except for room types)
        if (widget.property == null && !_isRoomTypeProperty()) {
          _showAddUnitsDialog(property);
        } else {
          Navigator.pop(context, property); // Return the saved property
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving property: $e'),
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

  bool _isRoomTypeProperty() {
    // Check if property type suggests it's a single room (no need for multiple units)
    final type = _selectedPropertyType.toString().toLowerCase();
    return type.contains('room') || type.contains('studio');
  }

  void _showAddUnitsDialog(Property property) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Units?'),
          content: Text('Would you like to add rental units to "${property.name}" now?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.pop(context, property); // Return to previous screen
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.pop(context, property); // Return to previous screen
                // Navigate to unit form
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UnitFormScreen(property: property),
                  ),
                );
              },
              child: const Text('Add Units'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _totalRoomsController.dispose();
    _totalBathroomsController.dispose();
    _totalSquareFeetController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _notesController.dispose();
    _baseRentalPriceController.dispose();
    _internetFixedFeeController.dispose();
    super.dispose();
  }
}