import 'package:flutter/material.dart';
import '../../models/property.dart';
import '../../models/tenant.dart';
import '../../models/malaysian_currency.dart';
import '../../models/calculation_result.dart';
import '../../models/utility_bill.dart';
import '../../services/tnb_calculation_service.dart';

class Step4MethodSelection extends StatefulWidget {
  final Property property;
  final List<Tenant> tenants;
  final double electricPrice;
  final double totalKWh;
  final Map<String, double> tenantACWattUsage;
  final double waterFee;
  final double otherFees;
  final CalculationMethod selectedMethod;
  final Function(CalculationMethod) onMethodSelected;
  final VoidCallback onCalculate;
  final bool isCalculating;

  const Step4MethodSelection({
    super.key,
    required this.property,
    required this.tenants,
    required this.electricPrice,
    required this.totalKWh,
    required this.tenantACWattUsage,
    required this.waterFee,
    required this.otherFees,
    required this.selectedMethod,
    required this.onMethodSelected,
    required this.onCalculate,
    required this.isCalculating,
  });

  @override
  State<Step4MethodSelection> createState() => _Step4MethodSelectionState();
}

class _Step4MethodSelectionState extends State<Step4MethodSelection> {
  double get _totalElectricCost {
    // Use provided total bill amount if available
    if (widget.electricPrice > 0) {
      return widget.electricPrice;
    }

    // Calculate using provider-specific rates if only kWh is provided
    if (widget.totalKWh > 0) {
      final electricityProvider = widget.property.electricityProvider;
      if (electricityProvider != null) {
        if (electricityProvider.shortName == 'TNB') {
          // Use full TNB bill calculation instead of marginal cost
          final bill = TNBCalculationService.calculateTNBBill(
            expenseId: 'preview',
            totalKWhUsage: widget.totalKWh,
          );
          return bill.totalAmount;
        } else {
          // Use UtilityBill calculation for SESB/SEB
          final bill = UtilityBill.calculateFromUsage(
            expenseId: 'preview',
            provider: electricityProvider,
            totalUsage: widget.totalKWh,
            billingPeriodStart: DateTime.now().subtract(const Duration(days: 30)),
            billingPeriodEnd: DateTime.now(),
            dueDate: DateTime.now().add(const Duration(days: 14)),
          );
          return bill.totalAmount;
        }
      }
    }

    return 0.0;
  }

  double get _totalExpenses {
    return _totalElectricCost + widget.waterFee + widget.otherFees;
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
                  _buildExpenseSummary(),
                  const SizedBox(height: 24),
                  _buildMethodSelection(),
                  const SizedBox(height: 24),
                  _buildCalculationPreview(),
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
              Icons.calculate,
              color: Theme.of(context).primaryColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text(
              'Calculation Method',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choose how to split the expenses among tenants',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildExpenseRow('Electric Cost', _totalElectricCost),
            _buildExpenseRow('Water Bill', widget.waterFee),
            _buildExpenseRow('Other Fees', widget.otherFees),
            const Divider(),
            _buildExpenseRow('Total Expenses', _totalExpenses, isTotal: true),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.property.electricityProvider?.shortName ?? 'Unknown'} Calculation Details',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.totalKWh > 0) ...[
                    Text(
                      'Total Usage: ${widget.totalKWh.toStringAsFixed(1)} kWh',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    widget.electricPrice > 0
                        ? 'Total Bill: ${MalaysianCurrency.format(widget.electricPrice)}'
                        : 'Using ${widget.property.electricityProvider?.shortName ?? 'provider'} rate structure (auto-calculated)',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
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

  Widget _buildExpenseRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            MalaysianCurrency.format(amount),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calculation Methods',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildMethodCard(CalculationMethod.simpleAverage),
        const SizedBox(height: 12),
        _buildMethodCard(CalculationMethod.layeredPrecise),
      ],
    );
  }

  Widget _buildMethodCard(CalculationMethod method) {
    final isSelected = widget.selectedMethod == method;
    
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: () => widget.onMethodSelected(method),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Radio<CalculationMethod>(
                value: method,
                groupValue: widget.selectedMethod,
                onChanged: (value) => widget.onMethodSelected(value!),
                activeColor: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Theme.of(context).primaryColor : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      method.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculationPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.selectedMethod == CalculationMethod.simpleAverage)
              _buildSimpleAveragePreview()
            else
              _buildLayeredCalculationPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleAveragePreview() {
    final costPerTenant = _totalExpenses / widget.tenants.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Each tenant pays: ${MalaysianCurrency.format(costPerTenant)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'All expenses are split equally among ${widget.tenants.length} tenants',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildLayeredCalculationPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Individual AC usage calculation:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...widget.tenants.take(3).map((tenant) {
          final wattage = widget.tenantACWattUsage[tenant.id] ?? 0;

          // Calculate AC cost using property's electricity provider
          double acCost = 0.0;
          if (wattage > 0) {
            final electricityProvider = widget.property.electricityProvider;
            if (electricityProvider != null) {
              if (electricityProvider.shortName == 'TNB') {
                // If electric price is provided, use proportional calculation
                if (widget.electricPrice > 0 && widget.totalKWh > 0) {
                  final averageCostPerKWh = widget.electricPrice / widget.totalKWh;
                  acCost = wattage * averageCostPerKWh;
                } else {
                  acCost = TNBCalculationService.calculateCostForUsage(wattage);
                }
              } else {
                final bill = UtilityBill.calculateFromUsage(
                  expenseId: 'preview_${tenant.id}',
                  provider: electricityProvider,
                  totalUsage: wattage,
                  billingPeriodStart: DateTime.now().subtract(const Duration(days: 30)),
                  billingPeriodEnd: DateTime.now(),
                  dueDate: DateTime.now().add(const Duration(days: 14)),
                );
                acCost = bill.totalAmount;
              }
            }
          }

          final sharedCost = (widget.waterFee + widget.otherFees) / widget.tenants.length;
          final totalCost = acCost + sharedCost;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${tenant.name}: ${MalaysianCurrency.format(totalCost)} (${wattage.toStringAsFixed(1)} kWh)',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }),
        if (widget.tenants.length > 3)
          Text(
            '... and ${widget.tenants.length - 3} more tenants',
            style: TextStyle(color: Colors.grey[500]),
          ),
      ],
    );
  }
}
