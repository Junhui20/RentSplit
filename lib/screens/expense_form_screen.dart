import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/expense.dart';
import '../models/property.dart';
import '../models/tenant.dart';
import '../models/tnb_electricity_bill.dart';
import '../models/utility_provider.dart';
import '../database/database_helper.dart';
import '../widgets/responsive_helper.dart';

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense; // null for new expense, existing expense for edit
  final String? propertyId; // pre-selected property

  const ExpenseFormScreen({super.key, this.expense, this.propertyId});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baseRentController = TextEditingController();
  final _internetFeeController = TextEditingController();
  final _waterBillController = TextEditingController();
  final _miscellaneousController = TextEditingController();
  final _totalKWhController = TextEditingController();
  final _totalACKWhController = TextEditingController();
  final _notesController = TextEditingController();

  // TNB Bill Controllers
  final _energyChargeController = TextEditingController();
  final _capacityChargeController = TextEditingController();
  final _networkChargeController = TextEditingController();
  final _retailChargeController = TextEditingController();
  final _kwtbbTaxController = TextEditingController();
  final _sstTaxController = TextEditingController();
  final _totalElectricityBillController = TextEditingController();

  String? _selectedPropertyId;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _splitMiscellaneous = true;
  bool _isLoading = false;
  bool _showTNBDetails = false;

  List<Property> _availableProperties = [];
  List<Tenant> _propertyTenants = [];
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _selectedPropertyId = widget.propertyId;
    _initializeForm();
    _loadProperties();
  }

  void _initializeForm() {
    if (widget.expense != null) {
      // Editing existing expense
      final expense = widget.expense!;
      _selectedPropertyId = expense.propertyId;
      _selectedMonth = expense.month;
      _selectedYear = expense.year;
      _baseRentController.text = expense.baseRent.toString();
      _internetFeeController.text = expense.internetFee.toString();
      _waterBillController.text = expense.waterBill.toString();
      _miscellaneousController.text = expense.miscellaneousExpenses.toString();
      _totalKWhController.text = expense.totalKWhUsage.toString();
      _totalACKWhController.text = expense.totalACKWhUsage.toString();
      _notesController.text = expense.notes ?? '';
      _splitMiscellaneous = expense.splitMiscellaneous;
    } else {
      // New expense defaults
      _baseRentController.text = '0.00';
      _internetFeeController.text = '0.00';
      _waterBillController.text = '0.00';
      _miscellaneousController.text = '0.00';
      _totalKWhController.text = '0.0';
      _totalACKWhController.text = '0.0';
    }
  }

  Future<void> _loadProperties() async {
    try {
      final properties = await _databaseHelper.getProperties();
      setState(() {
        _availableProperties = properties.where((p) => p.isActive).toList();
      });
      
      // Load tenants for selected property
      if (_selectedPropertyId != null) {
        _loadTenantsForProperty(_selectedPropertyId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading properties: $e')),
        );
      }
    }
  }

  Future<void> _loadTenantsForProperty(String propertyId) async {
    try {
      final allTenants = await _databaseHelper.getTenants();
      final propertyTenants = allTenants.where((t) => 
        t.propertyId == propertyId && t.isActive
      ).toList();
      
      setState(() {
        _propertyTenants = propertyTenants;
      });
      
      // Auto-calculate total AC usage from tenants
      if (propertyTenants.isNotEmpty) {
        final totalACUsage = propertyTenants.fold<double>(
          0.0, (sum, tenant) => sum + tenant.acUsageKWh
        );
        _totalACKWhController.text = totalACUsage.toStringAsFixed(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tenants: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add Monthly Expense' : 'Edit Monthly Expense'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (widget.expense != null)
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
            _buildPropertyAndPeriodSection(),
            const SizedBox(height: 24),
            _buildBasicExpensesSection(),
            const SizedBox(height: 24),
            _buildElectricitySection(),
            const SizedBox(height: 24),
            _buildMiscellaneousSection(),
            if (_showTNBDetails) ...[
              const SizedBox(height: 24),
              _buildTNBDetailsSection(),
            ],
            const SizedBox(height: 24),
            _buildNotesSection(),
            const SizedBox(height: 100), // Space for bottom bar
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyAndPeriodSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Property & Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPropertyId,
              decoration: const InputDecoration(
                labelText: 'Property *',
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
                  _propertyTenants = [];
                });
                if (value != null) {
                  _loadTenantsForProperty(value);
                }
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a property';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month *',
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      const monthNames = [
                        'January', 'February', 'March', 'April', 'May', 'June',
                        'July', 'August', 'September', 'October', 'November', 'December'
                      ];
                      return DropdownMenuItem(
                        value: month,
                        child: Text(monthNames[index]),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedMonth = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year *',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: List.generate(5, (index) {
                      final year = DateTime.now().year - 2 + index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_propertyTenants.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Tenants: ${_propertyTenants.length}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _propertyTenants.map((t) => t.name).join(', '),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBasicExpensesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Monthly Expenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _baseRentController,
                    decoration: const InputDecoration(
                      labelText: 'Base Rent (RM)',
                      prefixIcon: Icon(Icons.home),
                      prefixText: 'RM ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount < 0) {
                        return 'Invalid amount';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _internetFeeController,
                    decoration: const InputDecoration(
                      labelText: 'Internet Fee (RM)',
                      prefixIcon: Icon(Icons.wifi),
                      prefixText: 'RM ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount < 0) {
                        return 'Invalid amount';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _waterBillController,
              decoration: const InputDecoration(
                labelText: 'Water Bill (RM)',
                prefixIcon: Icon(Icons.water_drop),
                prefixText: 'RM ',
                helperText: 'Total water bill for the property',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount < 0) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElectricitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Electricity Usage',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showTNBDetails = !_showTNBDetails;
                    });
                  },
                  icon: Icon(_showTNBDetails ? Icons.expand_less : Icons.expand_more),
                  label: Text(_showTNBDetails ? 'Hide TNB Details' : 'Show TNB Details'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ResponsiveRowColumn(
              children: [
                Flexible(
                  flex: 1,
                  child: TextFormField(
                    controller: _totalKWhController,
                    decoration: const InputDecoration(
                      labelText: 'Total kWh Usage',
                      prefixIcon: Icon(Icons.electric_meter),
                      suffixText: 'kWh',
                      helperText: 'From TNB bill',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final usage = double.tryParse(value);
                      if (usage == null || usage < 0) {
                        return 'Invalid usage';
                      }
                      return null;
                    },
                  ),
                ),
                Flexible(
                  flex: 1,
                  child: TextFormField(
                    controller: _totalACKWhController,
                    decoration: const InputDecoration(
                      labelText: 'Total AC kWh',
                      prefixIcon: Icon(Icons.ac_unit),
                      suffixText: 'kWh',
                      helperText: 'Sum of all AC meters',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final acUsage = double.tryParse(value);
                      final totalUsage = double.tryParse(_totalKWhController.text);

                      if (acUsage == null || acUsage < 0) {
                        return 'Invalid usage';
                      }
                      if (totalUsage != null && acUsage > totalUsage) {
                        return 'Cannot exceed total';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _totalElectricityBillController,
              decoration: const InputDecoration(
                labelText: 'Total Electricity Bill (RM)',
                prefixIcon: Icon(Icons.receipt),
                prefixText: 'RM ',
                helperText: 'Total amount from TNB bill',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount < 0) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiscellaneousSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Miscellaneous Expenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _miscellaneousController,
              decoration: const InputDecoration(
                labelText: 'Miscellaneous Amount (RM)',
                prefixIcon: Icon(Icons.receipt_long),
                prefixText: 'RM ',
                helperText: 'Other shared expenses (maintenance, cleaning, etc.)',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount < 0) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Split Among All Tenants'),
              subtitle: Text(_splitMiscellaneous
                ? 'Miscellaneous expenses will be divided equally among all tenants'
                : 'Miscellaneous expenses will not be included in tenant calculations'),
              value: _splitMiscellaneous,
              onChanged: (value) {
                setState(() {
                  _splitMiscellaneous = value;
                });
              },
              secondary: Icon(
                _splitMiscellaneous ? Icons.group : Icons.person,
                color: _splitMiscellaneous ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTNBDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TNB Bill Breakdown (Optional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter detailed TNB charges for more accurate calculations',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _totalElectricityBillController,
              decoration: const InputDecoration(
                labelText: 'Total Electricity Bill (RM)',
                prefixIcon: Icon(Icons.receipt),
                prefixText: 'RM ',
                helperText: 'Total amount from TNB bill',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
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
            const Text(
              'Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes (Optional)',
                prefixIcon: Icon(Icons.note),
                hintText: 'Any additional information about this month\'s expenses...',
              ),
              maxLines: 3,
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
              onPressed: _isLoading ? null : _saveExpense,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.expense == null ? 'Add Expense' : 'Update Expense'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final expense = Expense(
        id: widget.expense?.id,
        propertyId: _selectedPropertyId!,
        month: _selectedMonth,
        year: _selectedYear,
        baseRent: double.parse(_baseRentController.text),
        internetFee: double.parse(_internetFeeController.text),
        waterBill: double.parse(_waterBillController.text),
        miscellaneousExpenses: double.parse(_miscellaneousController.text),
        splitMiscellaneous: _splitMiscellaneous,
        totalKWhUsage: double.parse(_totalKWhController.text),
        totalACKWhUsage: double.parse(_totalACKWhController.text),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.expense?.createdAt,
      );

      if (widget.expense == null) {
        // Adding new expense
        await _databaseHelper.insertExpense(expense);

        // Create TNB bill if details provided
        if (_totalElectricityBillController.text.isNotEmpty) {
          final tnbBill = TNBElectricityBill(
            expenseId: expense.id,
            totalKWhUsage: expense.totalKWhUsage,
            totalAmount: double.parse(_totalElectricityBillController.text),
          );
          await _databaseHelper.insertTNBBill(tnbBill);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense added successfully')),
          );
        }
      } else {
        // Updating existing expense
        await _databaseHelper.updateExpense(expense);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense updated successfully')),
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
            content: Text('Error saving expense: $e'),
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
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete this expense for ${widget.expense!.periodDescription}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExpense();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense() async {
    setState(() => _isLoading = true);

    try {
      await _databaseHelper.deleteExpense(widget.expense!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting expense: $e'),
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
    _baseRentController.dispose();
    _internetFeeController.dispose();
    _waterBillController.dispose();
    _miscellaneousController.dispose();
    _totalKWhController.dispose();
    _totalACKWhController.dispose();
    _notesController.dispose();
    _energyChargeController.dispose();
    _capacityChargeController.dispose();
    _networkChargeController.dispose();
    _retailChargeController.dispose();
    _kwtbbTaxController.dispose();
    _sstTaxController.dispose();
    _totalElectricityBillController.dispose();
    super.dispose();
  }
}
