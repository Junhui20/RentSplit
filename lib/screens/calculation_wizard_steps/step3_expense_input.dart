import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/property.dart';
import '../../models/tenant.dart';



class Step3ExpenseInput extends StatefulWidget {
  final Property property;
  final List<Tenant> tenants;
  final Map<String, double> previousACReadings;
  final double electricPrice;
  final double? totalKWh;
  final Map<String, double> tenantACWattUsage;
  final double waterFee;
  final double otherFees;
  final double rentalFee;
  final double internetFee;
  final String notes;
  final Function({
    required double electricPrice,
    required double totalKWh,
    required Map<String, double> tenantACWattUsage,
    required double waterFee,
    required double otherFees,
    required double rentalFee,
    required double internetFee,
    required String notes,
  }) onExpenseDataUpdated;

  const Step3ExpenseInput({
    super.key,
    required this.property,
    required this.tenants,
    required this.previousACReadings,
    required this.electricPrice,
    this.totalKWh,
    required this.tenantACWattUsage,
    required this.waterFee,
    required this.otherFees,
    required this.rentalFee,
    required this.internetFee,
    required this.notes,
    required this.onExpenseDataUpdated,
  });

  @override
  State<Step3ExpenseInput> createState() => _Step3ExpenseInputState();
}

class _Step3ExpenseInputState extends State<Step3ExpenseInput> {
  
  late TextEditingController _electricPriceController;
  late TextEditingController _totalKWhController;
  late TextEditingController _waterFeeController;
  late TextEditingController _otherFeesController;
  late TextEditingController _rentalFeeController;
  late TextEditingController _internetFeeController;
  late TextEditingController _notesController;
  
  final Map<String, TextEditingController> _tenantWattControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPreviousData();
  }

  void _initializeControllers() {
    _electricPriceController = TextEditingController(text: widget.electricPrice.toString());
    _totalKWhController = TextEditingController(text: widget.totalKWh?.toString() ?? '');
    _waterFeeController = TextEditingController(text: widget.waterFee.toString());
    _otherFeesController = TextEditingController(text: widget.otherFees.toString());

    // Auto-populate rental and internet fees from property if available
    _rentalFeeController = TextEditingController(
      text: widget.rentalFee > 0 ? widget.rentalFee.toString() : widget.property.baseRentalPrice.toString()
    );
    _internetFeeController = TextEditingController(
      text: widget.internetFee > 0 ? widget.internetFee.toString() : widget.property.internetFixedFee.toString()
    );

    _notesController = TextEditingController(text: widget.notes);
    
    // Initialize tenant watt controllers
    for (final tenant in widget.tenants) {
      final controller = TextEditingController();
      final existingWattage = widget.tenantACWattUsage[tenant.id];
      if (existingWattage != null) {
        controller.text = existingWattage.toString();
      }
      _tenantWattControllers[tenant.id] = controller;
    }
  }

  Future<void> _loadPreviousData() async {
    try {
      // TODO: Load previous month's expense data
      // final expenses = await _databaseHelper.getExpensesByProperty(widget.property.id);

      // TODO: Load default electric price from preferences
      // final defaultPrice = await _preferencesService.getDefaultElectricPrice();

      _updateExpenseData();
    } catch (e) {
      // Handle error silently for now
    }
  }

  void _updateExpenseData() {
    final electricPrice = double.tryParse(_electricPriceController.text) ?? 0.0;
    final totalKWh = double.tryParse(_totalKWhController.text) ?? 0.0;
    final waterFee = double.tryParse(_waterFeeController.text) ?? 0.0;
    final otherFees = double.tryParse(_otherFeesController.text) ?? 0.0;
    final rentalFee = double.tryParse(_rentalFeeController.text) ?? 0.0;
    final internetFee = double.tryParse(_internetFeeController.text) ?? 0.0;

    // Calculate AC usage: current reading - previous reading
    final tenantWattUsage = <String, double>{};
    for (final entry in _tenantWattControllers.entries) {
      final currentReading = double.tryParse(entry.value.text) ?? 0.0;
      final previousReading = widget.previousACReadings[entry.key] ?? 0.0;
      final usage = currentReading - previousReading;
      // Ensure usage is not negative (in case of meter reset or error)
      tenantWattUsage[entry.key] = usage > 0 ? usage : 0.0;
    }

    widget.onExpenseDataUpdated(
      electricPrice: electricPrice,
      totalKWh: totalKWh,
      tenantACWattUsage: tenantWattUsage,
      waterFee: waterFee,
      otherFees: otherFees,
      rentalFee: rentalFee,
      internetFee: internetFee,
      notes: _notesController.text,
    );
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildElectricPriceSection(),
                  const SizedBox(height: 24),
                  _buildTenantACWattageSection(),
                  const SizedBox(height: 24),
                  _buildOtherExpensesSection(),
                  const SizedBox(height: 24),
                  _buildNotesSection(),
                ],
              ),
            ),
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
              Icons.receipt,
              color: Theme.of(context).primaryColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text(
              'Expense Input',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Enter this month\'s expenses and AC meter readings',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildElectricPriceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Electricity Bill',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _totalKWhController,
              decoration: const InputDecoration(
                labelText: 'Total kWh Usage',
                hintText: 'Enter total kWh from TNB bill',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.electric_meter),
                suffixText: 'kWh',
                helperText: 'Total electricity usage from your TNB bill',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => _updateExpenseData(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _electricPriceController,
              decoration: const InputDecoration(
                labelText: 'Total Electricity Bill (RM)',
                hintText: 'Enter total amount from TNB bill',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt),
                prefixText: 'RM ',
                helperText: 'Total amount from your TNB bill (optional - will auto-calculate if empty)',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => _updateExpenseData(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.property.electricityProvider?.shortName ?? 'Unknown'} Calculation System',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getProviderDescription(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _loadPreviousElectricPrice,
                  icon: const Icon(Icons.history),
                  label: const Text('Use Previous Month'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _saveAsDefaultElectricPrice,
                  icon: const Icon(Icons.save),
                  label: const Text('Save as Default'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantACWattageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'AC Meter Readings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadPreviousACReadings,
                  icon: const Icon(Icons.history),
                  label: const Text('Load Previous'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter current AC meter readings for each tenant (usage will be calculated automatically)',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...widget.tenants.map((tenant) => _buildTenantWattInput(tenant)),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantWattInput(Tenant tenant) {
    final controller = _tenantWattControllers[tenant.id]!;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: '${tenant.name} - Current AC Reading (kWh)',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.electric_meter),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        onChanged: (_) => _updateExpenseData(),
      ),
    );
  }

  Widget _buildOtherExpensesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Other Expenses',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rentalFeeController,
              decoration: const InputDecoration(
                labelText: 'Total Rental Fee (RM)',
                hintText: 'Combined rent for all tenants',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
                prefixText: 'RM ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => _updateExpenseData(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _internetFeeController,
              decoration: const InputDecoration(
                labelText: 'Internet Fee (RM)',
                hintText: 'WiFi/Internet monthly cost',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
                prefixText: 'RM ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => _updateExpenseData(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _waterFeeController,
              decoration: const InputDecoration(
                labelText: 'Water Bill (RM)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.water_drop),
                prefixText: 'RM ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => _updateExpenseData(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _otherFeesController,
              decoration: const InputDecoration(
                labelText: 'Other Fees (RM)',
                hintText: 'Maintenance, cleaning, etc.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_long),
                prefixText: 'RM ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => _updateExpenseData(),
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
            Text(
              'Notes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                hintText: 'Any additional information about this month\'s expenses...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
              onChanged: (_) => _updateExpenseData(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPreviousElectricPrice() async {
    // TODO: Implement loading previous electric price
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loading previous electric price...')),
    );
  }

  Future<void> _saveAsDefaultElectricPrice() async {
    final price = double.tryParse(_electricPriceController.text);
    if (price != null) {
      // TODO: Implement save to preferences
      // await _preferencesService.setDefaultElectricPrice(price);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Electric price saved as default')),
        );
      }
    }
  }

  Future<void> _loadPreviousACReadings() async {
    // TODO: Implement loading previous AC readings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loading previous AC readings...')),
    );
  }

  String _getProviderDescription() {
    final provider = widget.property.electricityProvider;
    if (provider == null) return 'No electricity provider configured';

    switch (provider.shortName) {
      case 'TNB':
        return 'Uses Malaysia\'s new transparent electricity billing structure with:\n'
               '• Energy Charge: RM 0.2703/kWh (≤1500kWh)\n'
               '• Capacity Charge: RM 0.0455/kWh\n'
               '• Network Charge: RM 0.1285/kWh\n'
               '• Energy Efficiency Incentives\n'
               '• Automatic tax calculations (KWTBB, SST)';
      case 'SESB':
        return 'Sabah Electricity Sdn Bhd (SESB) rate structure:\n'
               '• 1-200 kWh: RM 0.21/kWh\n'
               '• 201-300 kWh: RM 0.33/kWh\n'
               '• 301-600 kWh: RM 0.52/kWh\n'
               '• Above 600 kWh: RM 0.54/kWh';
      case 'SEB':
        return 'Sarawak Energy Berhad (SEB) rate structure:\n'
               '• 1-200 kWh: RM 0.205/kWh\n'
               '• 201-400 kWh: RM 0.334/kWh\n'
               '• Above 400 kWh: RM 0.515/kWh';
      default:
        return 'Using ${provider.name} rate structure for accurate calculations';
    }
  }

  @override
  void dispose() {
    _electricPriceController.dispose();
    _totalKWhController.dispose();
    _waterFeeController.dispose();
    _otherFeesController.dispose();
    _rentalFeeController.dispose();
    _internetFeeController.dispose();
    _notesController.dispose();
    for (final controller in _tenantWattControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
