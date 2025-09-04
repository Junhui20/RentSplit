import 'package:flutter/material.dart';
import '../models/calculation_result.dart';
import '../models/expense.dart';
import '../models/property.dart';
import '../models/tenant.dart';
import '../models/malaysian_currency.dart';
import '../database/database_helper.dart';
import '../services/export_service.dart';
import 'calculation_results_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  List<CalculationResult> _reports = [];
  List<Expense> _expenses = [];
  List<Property> _properties = [];
  List<Tenant> _tenants = [];

  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedPropertyFilter;
  int? _selectedYearFilter;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final reports = await _databaseHelper.getCalculationResults();
      final expenses = await _databaseHelper.getExpenses();
      final properties = await _databaseHelper.getProperties();
      final tenants = await _databaseHelper.getTenants();

      setState(() {
        _reports = reports;
        _expenses = expenses;
        _properties = properties;
        _tenants = tenants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    }
  }

  List<CalculationResult> get _filteredReports {
    var filtered = _reports;

    // Apply property filter
    if (_selectedPropertyFilter != null) {
      final propertyExpenseIds = _expenses
          .where((e) => e.propertyId == _selectedPropertyFilter)
          .map((e) => e.id)
          .toSet();
      filtered = filtered.where((r) => propertyExpenseIds.contains(r.expenseId)).toList();
    }

    // Apply year filter
    if (_selectedYearFilter != null) {
      final yearExpenseIds = _expenses
          .where((e) => e.year == _selectedYearFilter)
          .map((e) => e.id)
          .toSet();
      filtered = filtered.where((r) => yearExpenseIds.contains(r.expenseId)).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((report) {
        final expense = _expenses.firstWhere((e) => e.id == report.expenseId);
        final property = _properties.firstWhere((p) => p.id == expense.propertyId);

        return property.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               expense.periodDescription.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               report.calculationMethod.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Sort by creation date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareAllReports,
            tooltip: 'Share All Reports',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchAndFilters(),
                _buildSummaryCards(),
                Expanded(child: _buildReportsList()),
              ],
            ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.withValues(alpha: 0.1),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search reports...',
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
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),

          const SizedBox(height: 12),

          // Filter Row
          Row(
            children: [
              // Property Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPropertyFilter,
                  decoration: InputDecoration(
                    labelText: 'Property',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Properties'),
                    ),
                    ..._properties.map((property) => DropdownMenuItem<String>(
                      value: property.id,
                      child: Text(property.name),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedPropertyFilter = value);
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Year Filter
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedYearFilter,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('All Years'),
                    ),
                    ...{..._expenses.map((e) => e.year)}.map((year) => DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedYearFilter = value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final filteredReports = _filteredReports;
    final totalAmount = filteredReports.fold<double>(0, (sum, report) => sum + report.totalAmount);
    final avgAmount = filteredReports.isNotEmpty ? totalAmount / filteredReports.length : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Reports',
              '${filteredReports.length}',
              Icons.description,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Total Amount',
              MalaysianCurrency.format(totalAmount),
              Icons.attach_money,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Average',
              MalaysianCurrency.format(avgAmount),
              Icons.trending_up,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Card(
        elevation: 8,
        shadowColor: color.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                color.withValues(alpha: 0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 10,
                offset: const Offset(0, -2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                      shadows: [
                        Shadow(
                          color: color.withValues(alpha: 0.3),
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    final filteredReports = _filteredReports;

    if (filteredReports.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredReports.length,
      itemBuilder: (context, index) {
        final report = filteredReports[index];
        return _buildReportCard(report);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Reports Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedPropertyFilter != null || _selectedYearFilter != null
                ? 'Try adjusting your filters'
                : 'No reports available',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(CalculationResult report) {
    final expense = _expenses.firstWhere((e) => e.id == report.expenseId);
    final property = _properties.firstWhere((p) => p.id == expense.propertyId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 6,
        shadowColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => _viewReport(report),
          borderRadius: BorderRadius.circular(16),
          splashColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          highlightColor: Theme.of(context).primaryColor.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  Theme.of(context).primaryColor.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 8,
                  offset: const Offset(0, -1),
                  spreadRadius: 0,
                ),
              ],
            ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          expense.periodDescription,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      MalaysianCurrency.format(report.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Details Row
              Row(
                children: [
                  _buildDetailChip(
                    Icons.people,
                    '${report.activeTenantsCount} tenants',
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildDetailChip(
                    Icons.calculate,
                    report.calculationMethod.displayName,
                    Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  _buildDetailChip(
                    Icons.access_time,
                    _formatTimeAgo(report.createdAt),
                    Colors.grey,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewReport(report),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareReport(report),
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteReport(report),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
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

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // CRUD Operations
  void _viewReport(CalculationResult report) async {
    try {
      final expense = _expenses.firstWhere((e) => e.id == report.expenseId);
      final tenants = _tenants.where((t) =>
        report.tenantCalculations.any((tc) => tc.tenantId == t.id)
      ).toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalculationResultsScreen(
            calculationResult: report,
            expense: expense,
            tenants: tenants,
          ),
        ),
      ).then((_) {
        _loadData(); // Refresh data when returning
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error viewing report: $e')),
      );
    }
  }

  void _shareReport(CalculationResult report) async {
    try {
      final expense = _expenses.firstWhere((e) => e.id == report.expenseId);
      final property = _properties.firstWhere((p) => p.id == expense.propertyId);
      final tenants = _tenants.where((t) =>
        report.tenantCalculations.any((tc) => tc.tenantId == t.id)
      ).toList();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.share, color: Colors.blue),
              SizedBox(width: 8),
              Text('Share Report'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('PDF Report'),
                subtitle: const Text('Complete calculation breakdown'),
                onTap: () async {
                  Navigator.pop(context);
                  await _shareAsPDF(report, expense, property, tenants);
                },
              ),
              ListTile(
                leading: const Icon(Icons.message, color: Colors.green),
                title: const Text('Text Summary'),
                subtitle: const Text('Quick text format'),
                onTap: () async {
                  Navigator.pop(context);
                  await _shareAsText(report, expense, property);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing report: $e')),
      );
    }
  }

  void _deleteReport(CalculationResult report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Report'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this report? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDelete(report);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(CalculationResult report) async {
    try {
      await _databaseHelper.deleteCalculationResult(report.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareAsPDF(CalculationResult report, Expense expense, Property property, List<Tenant> tenants) async {
    try {
      final filePath = await ExportService.exportCalculationToPDF(
        calculationResult: report,
        expense: expense,
        tenants: tenants,
        property: property,
      );

      await ExportService.shareFile(filePath, 'Report - ${property.name} ${expense.periodDescription}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report shared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing PDF: $e')),
        );
      }
    }
  }

  Future<void> _shareAsText(CalculationResult report, Expense expense, Property property) async {
    try {
      final textSummary = _generateTextSummary(report, expense, property);

      await ExportService.shareText(
        textSummary,
        'Report - ${property.name} ${expense.periodDescription}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text summary shared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing text: $e')),
        );
      }
    }
  }

  void _shareAllReports() async {
    if (_filteredReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No reports to share')),
      );
      return;
    }

    try {
      final filePath = await ExportService.exportFinancialSummary(
        calculationResults: _filteredReports,
        expenses: _expenses,
        properties: _properties,
        propertyFilter: _selectedPropertyFilter,
        yearFilter: _selectedYearFilter,
      );

      await ExportService.shareFile(filePath, 'Financial Summary Report');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Financial summary shared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing reports: $e')),
        );
      }
    }
  }

  String _generateTextSummary(CalculationResult report, Expense expense, Property property) {
    final buffer = StringBuffer();

    buffer.writeln('📊 CALCULATION REPORT');
    buffer.writeln('');
    buffer.writeln('Property: ${property.name}');
    buffer.writeln('Period: ${expense.periodDescription}');
    buffer.writeln('Method: ${report.calculationMethod.displayName}');
    buffer.writeln('Total Amount: ${MalaysianCurrency.format(report.totalAmount)}');
    buffer.writeln('Active Tenants: ${report.activeTenantsCount}');
    buffer.writeln('');
    buffer.writeln('TENANT BREAKDOWN:');

    for (final calc in report.tenantCalculations) {
      buffer.writeln('');
      buffer.writeln('${calc.tenantName}:');
      buffer.writeln('  Total: ${MalaysianCurrency.format(calc.totalAmount)}');
      if (calc.rentShare > 0) {
        buffer.writeln('  Rent: ${MalaysianCurrency.format(calc.rentShare)}');
      }
      if (calc.internetShare > 0) {
        buffer.writeln('  Internet: ${MalaysianCurrency.format(calc.internetShare)}');
      }
      if (calc.waterShare > 0) {
        buffer.writeln('  Water: ${MalaysianCurrency.format(calc.waterShare)}');
      }
      if (calc.commonElectricityShare > 0) {
        buffer.writeln('  Electricity: ${MalaysianCurrency.format(calc.commonElectricityShare)}');
      }
      if (calc.individualACCost > 0) {
        buffer.writeln('  AC Usage: ${MalaysianCurrency.format(calc.individualACCost)}');
      }
      if (calc.miscellaneousShare > 0) {
        buffer.writeln('  Other: ${MalaysianCurrency.format(calc.miscellaneousShare)}');
      }
    }

    buffer.writeln('');
    buffer.writeln('Generated by RentSplit App');

    return buffer.toString();
  }
}
