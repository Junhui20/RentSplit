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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Active Filters:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              if (_selectedPropertyFilter != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        _propertiesMap[_selectedPropertyFilter]?.name ?? 'Unknown Property',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPropertyFilter = null;
                          });
                        },
                        child: Icon(Icons.close, size: 16, color: Colors.blue[700]),
                      ),
                    ],
                  ),
                ),
              if (_selectedYearFilter != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Year: $_selectedYearFilter',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedYearFilter = null;
                          });
                        },
                        child: Icon(Icons.close, size: 16, color: Colors.green[700]),
                      ),
                    ],
                  ),
                ),
            ],
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        elevation: 8,
        shadowColor: Colors.orange.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: InkWell(
          onTap: () => _navigateToEditExpense(expense),
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.orange.withValues(alpha: 0.1),
          highlightColor: Colors.orange.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  Colors.orange.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.08),
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
                          Colors.orange.withValues(alpha: 0.15),
                          Colors.orange.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: Colors.orange[700],
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.periodDescription,
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
                                property?.name ?? 'Unknown Property',
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
                                '${expense.totalKWhUsage.toStringAsFixed(0)} kWh',
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_money, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Total Shared Expenses:',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Text(
                          MalaysianCurrency.format(totalExpenses),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildExpenseDetailItem(
                            'Rent',
                            MalaysianCurrency.format(expense.baseRent),
                            Icons.home,
                            Colors.blue,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        Expanded(
                          child: _buildExpenseDetailItem(
                            'Internet',
                            MalaysianCurrency.format(expense.internetFee),
                            Icons.wifi,
                            Colors.purple,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        Expanded(
                          child: _buildExpenseDetailItem(
                            'Water',
                            MalaysianCurrency.format(expense.waterBill),
                            Icons.water_drop,
                            Colors.cyan,
                          ),
                        ),
                      ],
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

  Widget _buildExpenseDetailItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 3),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}