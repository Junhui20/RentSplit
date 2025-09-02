import 'package:flutter/material.dart';
import '../models/property.dart';
import '../models/tenant.dart';
import '../models/calculation_result.dart';
import '../models/expense.dart';
import '../models/utility_bill.dart';

import '../database/database_helper.dart';
import '../services/multi_utility_calculation_service.dart';
import '../services/tnb_calculation_service.dart';
import 'calculation_wizard_steps/step1_property_selection.dart';
import 'calculation_wizard_steps/step2_tenant_overview.dart';
import 'calculation_wizard_steps/step3_expense_input.dart';
import 'calculation_wizard_steps/step4_method_selection.dart';
import 'calculation_results_screen.dart';

class CalculationWizardScreen extends StatefulWidget {
  const CalculationWizardScreen({super.key});

  @override
  State<CalculationWizardScreen> createState() => _CalculationWizardScreenState();
}

class _CalculationWizardScreenState extends State<CalculationWizardScreen> {
  final PageController _pageController = PageController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  int _currentStep = 0;
  final int _totalSteps = 4;
  
  // Wizard data
  Property? _selectedProperty;
  List<Tenant> _propertyTenants = [];
  Map<String, double> _previousACReadings = {};
  
  // Expense data
  double _electricPrice = 0.0; // Total electricity bill amount
  double _totalKWh = 0.0; // Total kWh usage
  Map<String, double> _tenantACWattUsage = {};
  double _waterFee = 0.0;
  double _otherFees = 0.0;
  double _rentalFee = 0.0;
  double _internetFee = 0.0;
  String _expenseNotes = '';
  
  // Calculation data
  CalculationMethod _selectedMethod = CalculationMethod.simpleAverage;
  
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calculate Expenses - Step ${_currentStep + 1} of $_totalSteps'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: [
                Step1PropertySelection(
                  onPropertySelected: _onPropertySelected,
                  selectedProperty: _selectedProperty,
                ),
                if (_selectedProperty != null) Step2TenantOverview(
                  property: _selectedProperty!,
                  tenants: _propertyTenants,
                  previousACReadings: _previousACReadings,
                  onACReadingsUpdated: _onACReadingsUpdated,
                ),
                if (_selectedProperty != null) Step3ExpenseInput(
                  property: _selectedProperty!,
                  tenants: _propertyTenants,
                  previousACReadings: _previousACReadings,
                  electricPrice: _electricPrice,
                  totalKWh: _totalKWh,
                  tenantACWattUsage: _tenantACWattUsage,
                  waterFee: _waterFee,
                  otherFees: _otherFees,
                  rentalFee: _rentalFee,
                  internetFee: _internetFee,
                  notes: _expenseNotes,
                  onExpenseDataUpdated: _onExpenseDataUpdated,
                ),
                if (_selectedProperty != null) Step4MethodSelection(
                  property: _selectedProperty!,
                  tenants: _propertyTenants,
                  electricPrice: _electricPrice,
                  totalKWh: _totalKWh,
                  tenantACWattUsage: _tenantACWattUsage,
                  waterFee: _waterFee,
                  otherFees: _otherFees,
                  selectedMethod: _selectedMethod,
                  onMethodSelected: _onMethodSelected,
                  onCalculate: _onCalculate,
                  isCalculating: _isLoading,
                ),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? Theme.of(context).primaryColor
                          : Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < _totalSteps - 1) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _previousStep,
                child: const Text('Previous'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _getNextButtonAction(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_getNextButtonText()),
            ),
          ),
        ],
      ),
    );
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 0:
        return 'Next';
      case 1:
        return 'Next';
      case 2:
        return 'Next';
      case 3:
        return 'Calculate';
      default:
        return 'Next';
    }
  }

  VoidCallback? _getNextButtonAction() {
    switch (_currentStep) {
      case 0:
        return _selectedProperty != null ? _nextStep : null;
      case 1:
        return _nextStep;
      case 2:
        return _nextStep;
      case 3:
        return _onCalculate;
      default:
        return null;
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Callback handlers
  void _onPropertySelected(Property property) async {
    setState(() {
      _selectedProperty = property;
      _isLoading = true;
    });
    
    try {
      // Load tenants for this property
      final tenants = await _databaseHelper.getTenantsByProperty(property.id);
      setState(() {
        _propertyTenants = tenants.where((t) => t.isActive).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tenants: $e')),
        );
      }
    }
  }

  void _onACReadingsUpdated(Map<String, double> readings) {
    setState(() {
      _previousACReadings = readings;
    });
  }

  void _onExpenseDataUpdated({
    required double electricPrice,
    required double totalKWh,
    required Map<String, double> tenantACWattUsage,
    required double waterFee,
    required double otherFees,
    required double rentalFee,
    required double internetFee,
    required String notes,
  }) {
    setState(() {
      _electricPrice = electricPrice;
      _totalKWh = totalKWh;
      _tenantACWattUsage = tenantACWattUsage;
      _waterFee = waterFee;
      _otherFees = otherFees;
      _rentalFee = rentalFee;
      _internetFee = internetFee;
      _expenseNotes = notes;
    });
  }

  void _onMethodSelected(CalculationMethod method) {
    setState(() {
      _selectedMethod = method;
    });
  }

  void _onCalculate() async {
    if (_selectedProperty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a property first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get active tenants and update their AC readings
      final activeTenants = _propertyTenants.where((t) => t.isActive).toList();
      if (activeTenants.isEmpty) {
        throw Exception('No active tenants found');
      }

      // Update tenant AC readings with the calculated usage
      final updatedTenants = <Tenant>[];
      for (final tenant in activeTenants) {
        final acUsage = _tenantACWattUsage[tenant.id] ?? 0.0;
        final currentReading = _previousACReadings[tenant.id] ?? tenant.currentACReading;
        final newCurrentReading = currentReading + acUsage;

        final updatedTenant = tenant.copyWith(
          previousACReading: currentReading,
          currentACReading: newCurrentReading,
        );
        updatedTenants.add(updatedTenant);

        // Update tenant in database
        await _databaseHelper.updateTenant(updatedTenant);

        // Record AC usage history
        await _databaseHelper.insertACUsageHistory(
          tenant.id,
          DateTime.now(),
          newCurrentReading,
          acUsage,
        );
      }

      // Create expense record
      final expense = Expense(
        propertyId: _selectedProperty!.id,
        month: DateTime.now().month,
        year: DateTime.now().year,
        baseRent: _rentalFee, // Use the rental fee input
        internetFee: _internetFee, // Use the internet fee input
        waterBill: _waterFee,
        miscellaneousExpenses: _otherFees, // Other fees go to miscellaneous
        splitMiscellaneous: true,
        totalKWhUsage: _totalKWh,
        totalACKWhUsage: _tenantACWattUsage.values.fold(0.0, (sum, usage) => sum + usage),
        notes: _expenseNotes.isEmpty ? null : _expenseNotes,
      );

      // Get property's electricity provider
      final electricityProvider = _selectedProperty!.electricityProvider;
      if (electricityProvider == null) {
        throw Exception('Property has no electricity provider configured');
      }

      CalculationResult result;

      // Use appropriate calculation service based on provider
      if (electricityProvider.shortName == 'TNB') {
        // Use TNB-specific calculation service
        final tnbBill = TNBCalculationService.calculateTNBBill(
          expenseId: expense.id,
          totalKWhUsage: _totalKWh,
          providedTotalAmount: _electricPrice > 0 ? _electricPrice : null,
        );

        result = TNBCalculationService.calculateRentSplit(
          expense: expense,
          tnbBill: tnbBill,
          activeTenants: updatedTenants,
          method: _selectedMethod,
        );
      } else {
        // Use multi-utility calculation service for SESB/SEB
        var electricityBill = UtilityBill.calculateFromUsage(
          expenseId: expense.id,
          provider: electricityProvider,
          totalUsage: _totalKWh,
          billingPeriodStart: DateTime.now().subtract(const Duration(days: 30)),
          billingPeriodEnd: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 14)),
        );

        // Override total amount if user provided it
        if (_electricPrice > 0) {
          electricityBill = UtilityBill(
            id: electricityBill.id,
            expenseId: electricityBill.expenseId,
            providerId: electricityBill.providerId,
            utilityType: electricityBill.utilityType,
            totalUsage: electricityBill.totalUsage,
            usageUnit: electricityBill.usageUnit,
            totalAmount: _electricPrice,
            billingPeriodStart: electricityBill.billingPeriodStart,
            billingPeriodEnd: electricityBill.billingPeriodEnd,
            dueDate: electricityBill.dueDate,
            charges: electricityBill.charges,
            additionalData: electricityBill.additionalData,
            createdAt: electricityBill.createdAt,
          );
        }

        final utilityBills = [electricityBill];

        result = MultiUtilityCalculationService.calculateRentSplit(
          expense: expense,
          utilityBills: utilityBills,
          activeTenants: updatedTenants,
          method: _selectedMethod,
          userState: _selectedProperty!.state,
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);

        // Navigate to results screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CalculationResultsScreen(
              calculationResult: result,
              expense: expense,
              tenants: updatedTenants,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calculation error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}


