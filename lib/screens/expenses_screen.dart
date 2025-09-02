import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/property.dart';
import '../models/malaysian_currency.dart';
import '../database/database_helper.dart';
import 'expense_form_screen.dart';
import 'calculation_wizard_screen.dart';

class ExpensesScreen extends StatefulWidget {
  final String? propertyId; // Optional property filter

  const ExpensesScreen({super.key, this.propertyId});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Expense> _expenses = [];
  Map<String, Property> _propertiesMap = {};
  bool _isLoading = true;
  String? _selectedPropertyFilter;
  int? _selectedYearFilter;

  @override
  void initState() {
    super.initState();
    _selectedPropertyFilter = widget.propertyId;
    _selectedYearFilter = DateTime.now().year;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load expenses
      final expenses = await _databaseHelper.getExpenses();

      // Load properties for reference
      final properties = await _databaseHelper.getProperties();
      final propertiesMap = <String, Property>{};
      for (final property in properties) {
        propertiesMap[property.id] = property;
      }

      setState(() {
        _expenses = expenses;
        _propertiesMap = propertiesMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expenses: $e')),
        );
      }
    }
  }

  List<Expense> get _filteredExpenses {
    var filtered = _expenses;

    if (_selectedPropertyFilter != null) {
      filtered = filtered.where((e) => e.propertyId == _selectedPropertyFilter).toList();
    }

    if (_selectedYearFilter != null) {
      filtered = filtered.where((e) => e.year == _selectedYearFilter).toList();
    }

    // Sort by year and month descending
    filtered.sort((a, b) {
      final yearCompare = b.year.compareTo(a.year);
      if (yearCompare != 0) return yearCompare;
      return b.month.compareTo(a.month);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Expenses'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExpenses.isEmpty
                    ? _buildEmptyState()
                    : _buildExpensesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddExpense(),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChips() {
    if (_selectedPropertyFilter == null && _selectedYearFilter == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 8.0,
        children: [
          if (_selectedPropertyFilter != null)
            FilterChip(
              label: Text(_propertiesMap[_selectedPropertyFilter]?.name ?? 'Unknown Property'),
              onSelected: (selected) {},
              onDeleted: () {
                setState(() {
                  _selectedPropertyFilter = null;
                });
              },
            ),
          if (_selectedYearFilter != null)
            FilterChip(
              label: Text('Year: $_selectedYearFilter'),
              onSelected: (selected) {},
              onDeleted: () {
                setState(() {
                  _selectedYearFilter = null;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Expenses Yet',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first monthly expense to get started',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddExpense(),
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
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

  Widget _buildExpensesList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _filteredExpenses.length,
        itemBuilder: (context, index) {
          final expense = _filteredExpenses[index];
          return _buildExpenseCard(expense);
        },
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final property = _propertiesMap[expense.propertyId];
    final totalExpenses = expense.baseRent + expense.internetFee + expense.waterBill +
                         (expense.splitMiscellaneous ? expense.miscellaneousExpenses : 0.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 3,
      child: InkWell(
        onTap: () => _navigateToEditExpense(expense),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.periodDescription,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          property?.name ?? 'Unknown Property',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleExpenseAction(value, expense),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit Expense'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'calculate',
                        child: ListTile(
                          leading: Icon(Icons.calculate),
                          title: Text('Calculate Split'),
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

              const SizedBox(height: 16),

              // Total and status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Shared Expenses:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      MalaysianCurrency.format(totalExpenses),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Usage info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.electric_meter, size: 20, color: Colors.orange),
                      const SizedBox(height: 4),
                      Text('${expense.totalKWhUsage.toStringAsFixed(1)} kWh'),
                      const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.ac_unit, size: 20, color: Colors.purple),
                      const SizedBox(height: 4),
                      Text('${expense.totalACKWhUsage.toStringAsFixed(1)} kWh'),
                      const Text('AC Usage', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.home, size: 20, color: Colors.green),
                      const SizedBox(height: 4),
                      Text('${expense.commonKWhUsage.toStringAsFixed(1)} kWh'),
                      const Text('Common', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleExpenseAction(String action, Expense expense) {
    switch (action) {
      case 'edit':
        _navigateToEditExpense(expense);
        break;
      case 'calculate':
        _navigateToCalculateExpense(expense);
        break;
      case 'delete':
        _showDeleteConfirmation(expense);
        break;
    }
  }

  void _navigateToAddExpense() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseFormScreen(propertyId: _selectedPropertyFilter),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToEditExpense(Expense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ExpenseFormScreen(expense: expense)),
    ).then((_) => _loadData());
  }

  void _navigateToCalculateExpense(Expense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalculationWizardScreen()),
    );
  }

  void _showDeleteConfirmation(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete the expense for ${expense.periodDescription}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExpense(expense);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    try {
      await _databaseHelper.deleteExpense(expense.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted')),
        );
        _loadData();
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
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Expenses'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedPropertyFilter,
              decoration: const InputDecoration(labelText: 'Property'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Properties')),
                ..._propertiesMap.values.map((property) => DropdownMenuItem(
                  value: property.id,
                  child: Text(property.name),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPropertyFilter = value;
                });
              },
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
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}