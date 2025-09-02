import 'package:flutter/material.dart';
import '../models/calculation_result.dart';
import '../models/expense.dart';
import '../models/tenant.dart';
import '../models/tenant_calculation.dart';
import '../models/property.dart';
import '../models/malaysian_currency.dart';
import '../models/utility_bill.dart';
import '../services/cost_splitting_service.dart';
import '../services/export_service.dart';
import '../services/tnb_calculation_service.dart';
import '../database/database_helper.dart';

class CalculationResultsScreen extends StatefulWidget {
  final CalculationResult calculationResult;
  final Expense expense;
  final List<Tenant> tenants;

  const CalculationResultsScreen({
    super.key,
    required this.calculationResult,
    required this.expense,
    required this.tenants,
  });

  @override
  State<CalculationResultsScreen> createState() => _CalculationResultsScreenState();
}

class _CalculationResultsScreenState extends State<CalculationResultsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  Property? _property;
  bool _isLoading = true;
  Map<String, double> _tenantWattUsage = {};

  @override
  void initState() {
    super.initState();
    _loadProperty();
    _loadTenantWattUsage();
  }

  Future<void> _loadProperty() async {
    try {
      final properties = await _databaseHelper.getProperties();
      final property = properties.firstWhere((p) => p.id == widget.expense.propertyId);
      setState(() {
        _property = property;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTenantWattUsage() async {
    try {
      final wattUsage = await _databaseHelper.getTenantACWattUsageByExpense(widget.expense.id);
      setState(() {
        _tenantWattUsage = wattUsage;
      });
    } catch (e) {
      // If loading fails, just use empty map
      setState(() {
        _tenantWattUsage = {};
      });
    }
  }

  double _calculateTotalElectricCost() {
    if (_property?.electricityProvider == null) {
      return widget.expense.totalKWhUsage * 0.45; // Fallback estimate
    }

    final provider = _property!.electricityProvider!;

    if (provider.shortName == 'TNB') {
      // Use full TNB bill calculation instead of marginal cost
      final bill = TNBCalculationService.calculateTNBBill(
        expenseId: 'display_${widget.expense.id}',
        totalKWhUsage: widget.expense.totalKWhUsage,
      );
      return bill.totalAmount;
    } else {
      // Use UtilityBill calculation for SESB/SEB
      final bill = UtilityBill.calculateFromUsage(
        expenseId: 'display_${widget.expense.id}',
        provider: provider,
        totalUsage: widget.expense.totalKWhUsage,
        billingPeriodStart: DateTime.now().subtract(const Duration(days: 30)),
        billingPeriodEnd: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 14)),
      );
      return bill.totalAmount;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _property == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Calculation Results'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculation Results'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareResults(context),
            tooltip: 'Share All Results',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildMethodInfoCard(),
            const SizedBox(height: 24),
            _buildTenantBreakdownSection(),
            const SizedBox(height: 24),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Calculation Summary',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Period:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(widget.expense.periodDescription),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Method:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(widget.calculationResult.calculationMethod.displayName),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Active Tenants:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text('${widget.calculationResult.activeTenantsCount}'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        MalaysianCurrency.format(widget.calculationResult.totalAmount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Electricity Provider:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(_property?.electricityProvider?.shortName ?? 'Unknown'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Electric Usage:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text('${widget.expense.totalKWhUsage.toStringAsFixed(1)} kWh'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Electric Cost:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        MalaysianCurrency.format(_calculateTotalElectricCost()),
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  'Calculation Method',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.calculationResult.calculationMethod.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.calculationResult.calculationMethod.description),
                  const SizedBox(height: 8),
                  Text(
                    'Provider: ${_property?.electricityProvider?.shortName ?? 'Unknown'} (${_property?.electricityProvider?.name ?? 'Unknown Provider'})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue),
                  ),
                  const SizedBox(height: 4),
                  if (widget.calculationResult.calculationMethod == CalculationMethod.layeredPrecise) ...[
                    const Text(
                      '• Individual AC costs calculated using provider-specific rates\n'
                      '• Common area electricity shared equally\n'
                      '• More accurate for properties with varying AC usage',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else ...[
                    const Text(
                      '• All costs divided equally among tenants\n'
                      '• Simple and straightforward approach\n'
                      '• Best for properties with similar usage patterns',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantBreakdownSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, color: Colors.green[700]),
            const SizedBox(width: 8),
            const Text(
              'Individual Tenant Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...widget.calculationResult.tenantCalculations.map((tenantCalc) =>
          _buildTenantCard(tenantCalc)
        ),
      ],
    );
  }

  Widget _buildTenantCard(dynamic tenantCalc) {
    // Get detailed breakdown
    final breakdown = CostSplittingService.getTenantCostBreakdown(tenantCalc);
    final costBreakdown = breakdown['cost_breakdown'] as Map<String, dynamic>;
    final usageDetails = breakdown['usage_details'] as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tenant Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    tenantCalc.tenantName.isNotEmpty 
                        ? tenantCalc.tenantName[0].toUpperCase() 
                        : 'T',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenantCalc.tenantName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'AC Usage: ${usageDetails['ac_usage_kwh'].toStringAsFixed(1)} kWh',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      if (_tenantWattUsage.containsKey(tenantCalc.tenantId))
                        Text(
                          'AC Watt Usage: ${_tenantWattUsage[tenantCalc.tenantId]!.toStringAsFixed(0)}W',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        MalaysianCurrency.format(tenantCalc.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _sendIndividualReceipt(context, tenantCalc),
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Send', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Cost Breakdown
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _buildCostRow('Rent Share', costBreakdown['rent']),
                  _buildCostRow('Internet Share', costBreakdown['internet']),
                  _buildCostRow('Water Share', costBreakdown['water']),
                  if (widget.calculationResult.calculationMethod == CalculationMethod.layeredPrecise) ...[
                    _buildCostRow('Common Electricity', costBreakdown['common_electricity']),
                    _buildDetailedACCostRow(tenantCalc, costBreakdown['individual_ac_cost']),
                  ] else ...[
                    _buildCostRow('Electricity Share', costBreakdown['common_electricity']),
                    if (tenantCalc.acUsageKWh > 0)
                      _buildDetailedACCostRow(tenantCalc, costBreakdown['individual_ac_cost']),
                  ],
                  if (costBreakdown['miscellaneous'] > 0)
                    _buildCostRow('Miscellaneous Share', costBreakdown['miscellaneous']),
                  const Divider(),
                  _buildCostRow(
                    'Total Amount',
                    tenantCalc.totalAmount,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 14 : 13,
            ),
          ),
          Text(
            MalaysianCurrency.format(amount),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 14 : 13,
              color: isTotal ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedACCostRow(dynamic tenantCalc, double acCost) {
    final acUsage = tenantCalc.acUsageKWh;
    final wattUsage = _tenantWattUsage[tenantCalc.tenantId] ?? 0.0;
    final providerName = _property?.electricityProvider?.shortName ?? 'Unknown';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Individual AC Cost',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                MalaysianCurrency.format(acCost),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${acUsage.toStringAsFixed(1)} kWh using $providerName rates',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (wattUsage > 0)
                Text(
                  '(${wattUsage.toStringAsFixed(0)}W)',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Primary Actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _saveAndFinish(context),
                icon: const Icon(Icons.save),
                label: const Text('Save Results'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _shareResults(context),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Secondary Actions
        OutlinedButton.icon(
          onPressed: () => _compareWithOtherMethod(context),
          icon: const Icon(Icons.compare_arrows),
          label: const Text('Compare Methods'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  void _shareResults(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.share, color: Colors.blue),
            SizedBox(width: 8),
            Text('Share All Results'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose format to share all tenant receipts and fees:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF Report'),
              subtitle: const Text('Complete calculation breakdown for all tenants'),
              onTap: () {
                Navigator.pop(context);
                _shareAsPDF(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.green),
              title: const Text('Text Summary'),
              subtitle: const Text('All tenant fees in text format'),
              onTap: () {
                Navigator.pop(context);
                _shareAsText(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.orange),
              title: const Text('Excel/CSV'),
              subtitle: const Text('Spreadsheet format for easy viewing'),
              onTap: () {
                Navigator.pop(context);
                _shareAsExcel(context);
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
  }

  void _shareAsPDF(BuildContext context) async {
    try {
      final filePath = await ExportService.exportCalculationToPDF(
        calculationResult: widget.calculationResult,
        expense: widget.expense,
        tenants: widget.tenants,
        property: _property!,
      );

      await ExportService.shareFile(
        filePath,
        'Calculation Results - ${widget.expense.periodDescription}',
      );

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF shared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing PDF: $e')),
        );
      }
    }
  }

  void _shareAsText(BuildContext context) async {
    try {
      final textSummary = _generateTextSummary();

      // Use the share package to share text
      await ExportService.shareText(
        textSummary,
        'Calculation Results - ${widget.expense.periodDescription}',
      );

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text summary shared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing text: $e')),
        );
      }
    }
  }

  void _shareAsExcel(BuildContext context) async {
    try {
      final filePath = await ExportService.exportCalculationToExcel(
        calculationResult: widget.calculationResult,
        expense: widget.expense,
        tenants: widget.tenants,
        property: _property!,
      );

      if (filePath.isNotEmpty) {
        await ExportService.shareFile(filePath, 'Calculation Results.xlsx');

        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel file shared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing Excel: $e')),
        );
      }
    }
  }



  String _generateTextSummary() {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('🏠 RENT CALCULATION RESULTS');
    buffer.writeln('Property: ${_property?.name ?? 'Unknown'}');
    buffer.writeln('Period: ${widget.expense.periodDescription}');
    buffer.writeln('Method: ${widget.calculationResult.calculationMethod.displayName}');
    buffer.writeln('Date: ${_formatDate(widget.calculationResult.createdAt)}');
    buffer.writeln('');

    // Summary
    buffer.writeln('📊 SUMMARY');
    buffer.writeln('Total Amount: ${MalaysianCurrency.format(widget.calculationResult.totalAmount)}');
    buffer.writeln('Active Tenants: ${widget.calculationResult.activeTenantsCount}');
    buffer.writeln('');

    // Individual breakdowns
    buffer.writeln('👥 INDIVIDUAL BREAKDOWN');
    for (final calc in widget.calculationResult.tenantCalculations) {
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
        buffer.writeln('  Common Electricity: ${MalaysianCurrency.format(calc.commonElectricityShare)}');
      }
      if (calc.individualACCost > 0) {
        buffer.writeln('  AC Usage: ${MalaysianCurrency.format(calc.individualACCost)} (${calc.acUsageKWh.toStringAsFixed(1)} kWh)');
      }
      if (calc.miscellaneousShare > 0) {
        buffer.writeln('  Other Fees: ${MalaysianCurrency.format(calc.miscellaneousShare)}');
      }
    }

    buffer.writeln('');
    buffer.writeln('Generated by RentSplit App');

    return buffer.toString();
  }



  String _generateIndividualWhatsAppText(dynamic tenantCalc, Tenant tenant) {
    final buffer = StringBuffer();

    buffer.writeln('🧾 *RENT RECEIPT*');
    buffer.writeln('');
    buffer.writeln('*Tenant:* ${tenantCalc.tenantName}');
    buffer.writeln('*Property:* ${_property?.name ?? 'Unknown'}');
    buffer.writeln('*Period:* ${widget.expense.periodDescription}');
    buffer.writeln('');
    buffer.writeln('*BREAKDOWN:*');

    if (tenantCalc.rentShare > 0) {
      buffer.writeln('• Rent: ${MalaysianCurrency.format(tenantCalc.rentShare)}');
    }
    if (tenantCalc.internetShare > 0) {
      buffer.writeln('• Internet: ${MalaysianCurrency.format(tenantCalc.internetShare)}');
    }
    if (tenantCalc.waterShare > 0) {
      buffer.writeln('• Water: ${MalaysianCurrency.format(tenantCalc.waterShare)}');
    }
    if (tenantCalc.commonElectricityShare > 0) {
      buffer.writeln('• Common Electricity: ${MalaysianCurrency.format(tenantCalc.commonElectricityShare)}');
    }
    if (tenantCalc.individualACCost > 0) {
      buffer.writeln('• AC Usage: ${MalaysianCurrency.format(tenantCalc.individualACCost)}');
      buffer.writeln('  _(${tenantCalc.acUsageKWh.toStringAsFixed(1)} kWh)_');
    }
    if (tenantCalc.miscellaneousShare > 0) {
      buffer.writeln('• Other Fees: ${MalaysianCurrency.format(tenantCalc.miscellaneousShare)}');
    }

    buffer.writeln('');
    buffer.writeln('💰 *TOTAL: ${MalaysianCurrency.format(tenantCalc.totalAmount)}*');
    buffer.writeln('');
    buffer.writeln('_Generated by RentSplit App_');

    return buffer.toString();
  }

  String _generateIndividualReceiptText(TenantCalculation calc, Tenant tenant) {
    final buffer = StringBuffer();

    buffer.writeln('🧾 RENT RECEIPT');
    buffer.writeln('');
    buffer.writeln('Tenant: ${calc.tenantName}');
    buffer.writeln('Property: ${_property?.name ?? 'Unknown'}');
    buffer.writeln('Period: ${widget.expense.periodDescription}');
    buffer.writeln('');
    buffer.writeln('BREAKDOWN:');

    if (calc.rentShare > 0) {
      buffer.writeln('Rent: ${MalaysianCurrency.format(calc.rentShare)}');
    }
    if (calc.internetShare > 0) {
      buffer.writeln('Internet: ${MalaysianCurrency.format(calc.internetShare)}');
    }
    if (calc.waterShare > 0) {
      buffer.writeln('Water: ${MalaysianCurrency.format(calc.waterShare)}');
    }
    if (calc.commonElectricityShare > 0) {
      buffer.writeln('Common Electricity: ${MalaysianCurrency.format(calc.commonElectricityShare)}');
    }
    if (calc.individualACCost > 0) {
      buffer.writeln('AC Usage: ${MalaysianCurrency.format(calc.individualACCost)}');
      buffer.writeln('  (${calc.acUsageKWh.toStringAsFixed(1)} kWh)');
    }
    if (calc.miscellaneousShare > 0) {
      buffer.writeln('Other Fees: ${MalaysianCurrency.format(calc.miscellaneousShare)}');
    }

    buffer.writeln('');
    buffer.writeln('TOTAL: ${MalaysianCurrency.format(calc.totalAmount)}');
    buffer.writeln('');
    buffer.writeln('Generated by RentSplit App');

    return buffer.toString();
  }

  String _generateSMSReceiptText(TenantCalculation calc, Tenant tenant) {
    return 'Rent Receipt - ${calc.tenantName}: '
           'Total ${MalaysianCurrency.format(calc.totalAmount)} '
           'for ${widget.expense.periodDescription}. '
           'Breakdown: Rent ${MalaysianCurrency.format(calc.rentShare)}, '
           'Utilities ${MalaysianCurrency.format(calc.totalElectricityCost + calc.waterShare + calc.internetShare)}. '
           'Generated by RentSplit App.';
  }







  void _compareWithOtherMethod(BuildContext context) async {
    try {
      // Get the other calculation method
      final otherMethod = widget.calculationResult.calculationMethod == CalculationMethod.simpleAverage
          ? CalculationMethod.layeredPrecise
          : CalculationMethod.simpleAverage;

      // Get required data for calculation
      final databaseHelper = DatabaseHelper();
      final tenants = widget.tenants; // Use existing tenants from widget
      final tnbBill = await databaseHelper.getTNBBillByExpenseId(widget.expense.id);
      final property = await databaseHelper.getProperty(widget.expense.propertyId);

      if (tnbBill == null) {
        throw Exception('TNB bill not found');
      }

      // Calculate using the other method
      final otherResult = TNBCalculationService.calculateRentSplit(
        expense: widget.expense,
        tnbBill: tnbBill,
        activeTenants: tenants,
        method: otherMethod,
        property: property,
      );

      // ignore: unnecessary_null_comparison
      if (otherResult != null && mounted && context.mounted) {
        _showMethodComparisonDialog(context, otherResult);
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error comparing methods: $e')),
        );
      }
    }
  }

  void _showMethodComparisonDialog(BuildContext context, CalculationResult otherResult) {
    final currentMethod = widget.calculationResult.calculationMethod;
    final otherMethod = otherResult.calculationMethod;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Method Comparison',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Method headers
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.calculate, color: Colors.blue.shade700),
                          const SizedBox(height: 4),
                          Text(
                            currentMethod.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'Current Method',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.compare_arrows, color: Colors.green.shade700),
                          const SizedBox(height: 4),
                          Text(
                            otherMethod.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'Alternative Method',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Total comparison
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Text(
                          MalaysianCurrency.format(widget.calculationResult.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text(' vs '),
                        Text(
                          MalaysianCurrency.format(otherResult.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tenant comparison
              Expanded(
                child: ListView.builder(
                  itemCount: widget.calculationResult.tenantCalculations.length,
                  itemBuilder: (context, index) {
                    final currentCalc = widget.calculationResult.tenantCalculations[index];
                    final otherCalc = otherResult.tenantCalculations[index];
                    final difference = otherCalc.totalAmount - currentCalc.totalAmount;
                    final percentageChange = currentCalc.totalAmount > 0
                        ? (difference / currentCalc.totalAmount) * 100
                        : 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentCalc.tenantName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        MalaysianCurrency.format(currentCalc.totalAmount),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      if (currentCalc.acUsageKWh > 0)
                                        Text(
                                          'AC: ${currentCalc.acUsageKWh.toStringAsFixed(1)} kWh',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward, color: Colors.grey),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        MalaysianCurrency.format(otherCalc.totalAmount),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      if (otherCalc.acUsageKWh > 0)
                                        Text(
                                          'AC: ${otherCalc.acUsageKWh.toStringAsFixed(1)} kWh',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: difference >= 0 ? Colors.red.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    difference >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                    size: 16,
                                    color: difference >= 0 ? Colors.red : Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${difference >= 0 ? '+' : ''}${MalaysianCurrency.format(difference.abs())} (${percentageChange.toStringAsFixed(1)}%)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: difference >= 0 ? Colors.red : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _switchToOtherMethod(context, otherResult);
                      },
                      child: Text('Use ${otherMethod.displayName}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _switchToOtherMethod(BuildContext context, CalculationResult otherResult) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Calculation Method'),
        content: Text(
          'Do you want to switch to ${otherResult.calculationMethod.displayName} method? '
          'This will replace the current calculation results.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate back with the new result
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CalculationResultsScreen(
                    calculationResult: otherResult,
                    expense: widget.expense,
                    tenants: widget.tenants,
                  ),
                ),
              );
            },
            child: const Text('Switch Method'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndFinish(BuildContext context) async {
    try {
      final databaseHelper = DatabaseHelper();

      // Save the expense to database
      await databaseHelper.insertExpense(widget.expense);

      // Save the calculation result to database
      await databaseHelper.insertCalculationResult(widget.calculationResult);

      // Save individual tenant calculations
      for (final tenantCalc in widget.calculationResult.tenantCalculations) {
        final updatedTenantCalc = tenantCalc.copyWith(
          calculationResultId: widget.calculationResult.id,
        );
        await databaseHelper.insertTenantCalculation(updatedTenantCalc);
      }

      if (mounted && context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calculation results saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving results: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendIndividualReceipt(BuildContext context, dynamic tenantCalc) {
    final tenant = widget.tenants.firstWhere((t) => t.id == tenantCalc.tenantId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.send, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Send to ${tenantCalc.tenantName}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email, color: Colors.red),
              title: const Text('Email'),
              subtitle: Text(tenant.email ?? 'No email available'),
              onTap: tenant.email != null ? () {
                Navigator.pop(context);
                _sendIndividualReceiptViaEmail(context, tenantCalc, tenant);
              } : null,
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.green),
              title: const Text('WhatsApp'),
              subtitle: Text(tenant.phone ?? 'No phone available'),
              onTap: tenant.phone != null ? () {
                Navigator.pop(context);
                _sendIndividualReceiptViaWhatsApp(context, tenantCalc, tenant);
              } : null,
            ),
            ListTile(
              leading: const Icon(Icons.sms, color: Colors.blue),
              title: const Text('SMS'),
              subtitle: Text(tenant.phone ?? 'No phone available'),
              onTap: tenant.phone != null ? () {
                Navigator.pop(context);
                _sendIndividualReceiptViaSMS(context, tenantCalc, tenant);
              } : null,
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
  }

  void _sendReceipts(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.send, color: Colors.blue),
            SizedBox(width: 8),
            Text('Send Receipts'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send individual receipts to tenants via:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.red),
              title: const Text('Email'),
              subtitle: const Text('Send detailed receipt via email'),
              onTap: () {
                Navigator.pop(context);
                _sendReceiptsViaEmail(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.green),
              title: const Text('WhatsApp'),
              subtitle: const Text('Send receipt summary via WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _sendReceiptsViaWhatsApp(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms, color: Colors.blue),
              title: const Text('SMS'),
              subtitle: const Text('Send receipt summary via SMS'),
              onTap: () {
                Navigator.pop(context);
                _sendReceiptsViaSMS(context);
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
  }

  void _sendIndividualReceiptViaEmail(BuildContext context, dynamic tenantCalc, Tenant tenant) async {
    try {
      final receiptText = _generateIndividualReceiptText(tenantCalc, tenant);
      await ExportService.shareText(
        receiptText,
        'Receipt for ${tenant.name} - ${widget.expense.periodDescription}',
      );

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Receipt shared for ${tenant.name}')),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing receipt: $e')),
        );
      }
    }
  }

  void _sendIndividualReceiptViaWhatsApp(BuildContext context, dynamic tenantCalc, Tenant tenant) async {
    try {
      final receiptText = _generateIndividualWhatsAppText(tenantCalc, tenant);
      await ExportService.shareText(
        receiptText,
        'Receipt for ${tenant.name}',
      );

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Receipt shared for ${tenant.name}')),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing receipt: $e')),
        );
      }
    }
  }

  void _sendIndividualReceiptViaSMS(BuildContext context, dynamic tenantCalc, Tenant tenant) async {
    try {
      final receiptText = _generateIndividualReceiptText(tenantCalc, tenant);
      await ExportService.shareText(
        receiptText,
        'Receipt for ${tenant.name}',
      );

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Receipt shared for ${tenant.name}')),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing receipt: $e')),
        );
      }
    }
  }

  void _sendReceiptsViaEmail(BuildContext context) {
    _showSendingDialog(context, 'Email', () async {
      try {
        for (final calc in widget.calculationResult.tenantCalculations) {
          final tenant = widget.tenants.firstWhere((t) => t.id == calc.tenantId);

          // Generate individual PDF receipt
          final pdfPath = await ExportService.exportTenantReceiptToPDF(
            tenantCalculation: calc,
            tenant: tenant,
            expense: widget.expense,
            property: _property!,
          );

          // In a real implementation, you would use email packages like mailer
          // For now, we'll share the PDF which can be sent via email
          await ExportService.shareFile(
            pdfPath,
            'Rent Receipt - ${calc.tenantName} - ${widget.expense.periodDescription}',
          );

          // Small delay between sends
          await Future.delayed(const Duration(milliseconds: 500));
        }
        return true;
      } catch (e) {
        debugPrint('Error sending email receipts: $e');
        return false;
      }
    });
  }

  void _sendReceiptsViaWhatsApp(BuildContext context) {
    _showSendingDialog(context, 'WhatsApp', () async {
      try {
        for (final calc in widget.calculationResult.tenantCalculations) {
          final tenant = widget.tenants.firstWhere((t) => t.id == calc.tenantId);

          // Generate WhatsApp-friendly text receipt
          final receiptText = _generateWhatsAppReceiptText(calc, tenant);

          // In a real implementation, you would use url_launcher to open WhatsApp
          // For now, we'll share the text which can be sent via WhatsApp
          await ExportService.shareText(
            receiptText,
            'Rent Receipt - ${calc.tenantName}',
          );

          // Small delay between sends
          await Future.delayed(const Duration(milliseconds: 500));
        }
        return true;
      } catch (e) {
        debugPrint('Error sending WhatsApp receipts: $e');
        return false;
      }
    });
  }

  void _sendReceiptsViaSMS(BuildContext context) {
    _showSendingDialog(context, 'SMS', () async {
      try {
        for (final calc in widget.calculationResult.tenantCalculations) {
          final tenant = widget.tenants.firstWhere((t) => t.id == calc.tenantId);

          // Generate SMS-friendly short receipt
          final smsText = _generateSMSReceiptText(calc, tenant);

          // In a real implementation, you would use url_launcher to send SMS
          // For now, we'll share the text which can be sent via SMS
          await ExportService.shareText(
            smsText,
            'Rent Receipt SMS - ${calc.tenantName}',
          );

          // Small delay between sends
          await Future.delayed(const Duration(milliseconds: 500));
        }
        return true;
      } catch (e) {
        debugPrint('Error sending SMS receipts: $e');
        return false;
      }
    });
  }

  String _generateWhatsAppReceiptText(TenantCalculation calc, Tenant tenant) {
    final buffer = StringBuffer();

    buffer.writeln('🏠 *RENT RECEIPT*');
    buffer.writeln('');
    buffer.writeln('*Tenant:* ${calc.tenantName}');
    buffer.writeln('*Property:* ${_property?.name ?? 'Unknown'}');
    buffer.writeln('*Period:* ${widget.expense.periodDescription}');
    buffer.writeln('*Date:* ${_formatDate(widget.calculationResult.createdAt)}');
    buffer.writeln('');
    buffer.writeln('📊 *BREAKDOWN:*');

    if (calc.rentShare > 0) {
      buffer.writeln('• Rent: ${MalaysianCurrency.format(calc.rentShare)}');
    }
    if (calc.internetShare > 0) {
      buffer.writeln('• Internet: ${MalaysianCurrency.format(calc.internetShare)}');
    }
    if (calc.waterShare > 0) {
      buffer.writeln('• Water: ${MalaysianCurrency.format(calc.waterShare)}');
    }
    if (calc.commonElectricityShare > 0) {
      buffer.writeln('• Common Electricity: ${MalaysianCurrency.format(calc.commonElectricityShare)}');
    }
    if (calc.individualACCost > 0) {
      buffer.writeln('• AC Usage: ${MalaysianCurrency.format(calc.individualACCost)}');
      buffer.writeln('  _(${calc.acUsageKWh.toStringAsFixed(1)} kWh)_');
    }
    if (calc.miscellaneousShare > 0) {
      buffer.writeln('• Other Fees: ${MalaysianCurrency.format(calc.miscellaneousShare)}');
    }

    buffer.writeln('');
    buffer.writeln('💰 *TOTAL: ${MalaysianCurrency.format(calc.totalAmount)}*');
    buffer.writeln('');
    buffer.writeln('_Generated by RentSplit App_');

    return buffer.toString();
  }

  void _showSendingDialog(BuildContext context, String method, Future<bool> Function() sendFunction) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Sending receipts via $method...'),
            const SizedBox(height: 8),
            Text(
              'Preparing ${widget.tenants.length} individual receipts',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );

    // Store context reference before async operation
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    sendFunction().then((success) {
      if (mounted) {
        navigator.pop(); // Close loading dialog

        if (success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Receipts sent successfully via $method to ${widget.tenants.length} tenants'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'View Details',
                onPressed: () => _showSentReceiptsDetails(context, method),
              ),
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to send receipts via $method'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _sendReceipts(context),
              ),
            ),
          );
        }
      }
    }).catchError((error) {
      if (mounted) {
        navigator.pop(); // Close loading dialog
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error sending receipts: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _showSentReceiptsDetails(BuildContext context, String method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Receipts Sent via $method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully sent to ${widget.tenants.length} tenants:'),
            const SizedBox(height: 12),
            ...widget.tenants.map((tenant) {
              final tenantCalc = widget.calculationResult.tenantCalculations
                  .firstWhere((tc) => tc.tenantId == tenant.id);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${tenant.name} - ${MalaysianCurrency.format(tenantCalc.totalAmount)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
