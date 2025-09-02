import 'package:flutter/material.dart';
import '../models/malaysian_currency.dart';
import '../models/calculation_result.dart';
import '../database/database_helper.dart';
import '../widgets/responsive_helper.dart';
import 'property_form_screen.dart';
import 'calculation_wizard_screen.dart';
import 'reports_screen.dart';

class PortfolioOverviewScreen extends StatefulWidget {
  const PortfolioOverviewScreen({super.key});

  @override
  State<PortfolioOverviewScreen> createState() => _PortfolioOverviewScreenState();
}

class _PortfolioOverviewScreenState extends State<PortfolioOverviewScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  Map<String, dynamic>? _portfolioSummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPortfolioData();
  }

  Future<void> _loadPortfolioData() async {
    setState(() => _isLoading = true);

    try {
      // Load portfolio summary from database
      final portfolioSummary = await _databaseHelper.getPropertyPortfolioSummary();

      // Load recent calculations for quick access
      final recentCalculations = await _databaseHelper.getCalculationResults();
      final recentExpenses = await _databaseHelper.getExpenses();

      // Add recent activity to portfolio summary
      portfolioSummary['recentCalculations'] = recentCalculations.take(5).toList();
      portfolioSummary['recentExpenses'] = recentExpenses.take(3).toList();

      // Calculate monthly trends
      final monthlyTrends = await _calculateMonthlyTrends(recentCalculations);
      portfolioSummary['monthlyTrends'] = monthlyTrends;

      setState(() {
        _portfolioSummary = portfolioSummary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading portfolio: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _calculateMonthlyTrends(List<CalculationResult> calculations) async {
    if (calculations.isEmpty) {
      return {
        'totalThisMonth': 0.0,
        'totalLastMonth': 0.0,
        'percentageChange': 0.0,
        'calculationsThisMonth': 0,
      };
    }

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);

    double totalThisMonth = 0.0;
    double totalLastMonth = 0.0;
    int calculationsThisMonth = 0;

    for (final calc in calculations) {
      final calcMonth = DateTime(calc.createdAt.year, calc.createdAt.month);

      if (calcMonth.isAtSameMomentAs(thisMonth)) {
        totalThisMonth += calc.totalAmount;
        calculationsThisMonth++;
      } else if (calcMonth.isAtSameMomentAs(lastMonth)) {
        totalLastMonth += calc.totalAmount;
      }
    }

    double percentageChange = 0.0;
    if (totalLastMonth > 0) {
      percentageChange = ((totalThisMonth - totalLastMonth) / totalLastMonth) * 100;
    }

    return {
      'totalThisMonth': totalThisMonth,
      'totalLastMonth': totalLastMonth,
      'percentageChange': percentageChange,
      'calculationsThisMonth': calculationsThisMonth,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Portfolio'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPortfolioData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPortfolioContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddProperty(),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPortfolioContent() {
    if (_portfolioSummary == null) {
      return const Center(child: Text('Unable to load portfolio data'));
    }

    return RefreshIndicator(
      onRefresh: _loadPortfolioData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            _buildSummaryCards(),
            const SizedBox(height: 24),
            _buildMonthlyTrendsCard(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildRecentActivitySection(),
            const SizedBox(height: 24),
            _buildStateDistribution(),
            const SizedBox(height: 24),
            _buildAttentionAlerts(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to RentSplit Malaysia',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your rental properties across Malaysia',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Portfolio Summary',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ResponsiveGridView(
          mobileColumns: 2,
          tabletColumns: 3,
          desktopColumns: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: ResponsiveHelper.getResponsiveAspectRatio(context, mobile: 1.3, tablet: 1.5, desktop: 1.8),
          children: [
            _buildSummaryCard(
              'Total Properties',
              '${_portfolioSummary!['totalProperties']}',
              Icons.home_work,
              Colors.blue,
            ),
            _buildSummaryCard(
              'Total Units',
              '${_portfolioSummary!['totalUnits']}',
              Icons.apartment,
              Colors.green,
            ),
            _buildSummaryCard(
              'Occupancy Rate',
              '${_portfolioSummary!['occupancyRate'].toStringAsFixed(1)}%',
              Icons.people,
              Colors.orange,
            ),
            _buildSummaryCard(
              'Monthly Income',
              MalaysianCurrency.format(_portfolioSummary!['totalMonthlyRent']),
              Icons.attach_money,
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ResponsiveGridView(
          mobileColumns: 2,
          tabletColumns: 3,
          desktopColumns: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: ResponsiveHelper.getResponsiveAspectRatio(context, mobile: 2.2, tablet: 2.5, desktop: 3.0),
          children: [
            _buildActionCard(
              'Add Property',
              Icons.add_home,
              Colors.blue,
              () => _navigateToAddProperty(),
            ),
            _buildActionCard(
              'Calculate Utilities',
              Icons.calculate,
              Colors.green,
              () => _navigateToCalculateUtilities(),
            ),
            _buildActionCard(
              'View Reports',
              Icons.analytics,
              Colors.orange,
              () => _navigateToReports(),
            ),
            _buildActionCard(
              'Manage Tenants',
              Icons.people_alt,
              Colors.purple,
              () => _navigateToTenants(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateDistribution() {
    final Map<String, int> unitsByState = Map<String, int>.from(_portfolioSummary!['unitsByState']);
    
    if (unitsByState.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const Text(
                'Property Distribution by State',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'No properties added yet',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _navigateToAddProperty(),
                child: const Text('Add Your First Property'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Property Distribution by State',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...unitsByState.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key),
                  Text('${entry.value} units', style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionAlerts() {
    final List<Map<String, dynamic>> alerts = List<Map<String, dynamic>>.from(_portfolioSummary!['propertiesNeedingAttention']);
    
    if (alerts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 12),
              Text(
                'All properties are in good standing',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Needs Attention',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...alerts.map((alert) => Card(
          child: ListTile(
            leading: const Icon(Icons.warning, color: Colors.orange),
            title: Text(alert['propertyName']),
            subtitle: Text(_buildAlertSubtitle(alert)),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _navigateToProperty(alert['propertyId']),
          ),
        )),
      ],
    );
  }

  String _buildAlertSubtitle(Map<String, dynamic> alert) {
    final List<String> issues = [];
    
    if (alert['expiringAgreements'] > 0) {
      issues.add('${alert['expiringAgreements']} expiring agreements');
    }
    if (alert['vacantUnits'] > 0) {
      issues.add('${alert['vacantUnits']} vacant units');
    }
    if (alert['maintenanceUnits'] > 0) {
      issues.add('${alert['maintenanceUnits']} maintenance units');
    }
    
    return issues.join(', ');
  }

  void _navigateToAddProperty() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PropertyFormScreen()),
    ).then((_) => _loadPortfolioData());
  }

  void _navigateToCalculateUtilities() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalculationWizardScreen()),
    );
  }

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReportsScreen()),
    );
  }

  void _navigateToTenants() {
    Navigator.pushNamed(context, '/tenants');
  }

  Widget _buildMonthlyTrendsCard() {
    final trends = _portfolioSummary?['monthlyTrends'] as Map<String, dynamic>? ?? {};
    final totalThisMonth = trends['totalThisMonth'] as double? ?? 0.0;
    final totalLastMonth = trends['totalLastMonth'] as double? ?? 0.0;
    final percentageChange = trends['percentageChange'] as double? ?? 0.0;
    final calculationsThisMonth = trends['calculationsThisMonth'] as int? ?? 0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Monthly Trends',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTrendItem(
                    'This Month',
                    MalaysianCurrency.format(totalThisMonth),
                    '$calculationsThisMonth calculations',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTrendItem(
                    'Last Month',
                    MalaysianCurrency.format(totalLastMonth),
                    'Comparison base',
                    Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTrendItem(
                    'Change',
                    '${percentageChange >= 0 ? '+' : ''}${percentageChange.toStringAsFixed(1)}%',
                    percentageChange >= 0 ? 'Increase' : 'Decrease',
                    percentageChange >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendItem(String title, String value, String subtitle, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    final recentCalculations = _portfolioSummary?['recentCalculations'] as List? ?? [];
    final recentExpenses = _portfolioSummary?['recentExpenses'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton(
              onPressed: _navigateToReports,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (recentCalculations.isNotEmpty) ...[
          _buildRecentCalculationsCard(recentCalculations),
          const SizedBox(height: 16),
        ],
        if (recentExpenses.isNotEmpty)
          _buildRecentExpensesCard(recentExpenses),
        if (recentCalculations.isEmpty && recentExpenses.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No recent activity',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start by adding properties and creating calculations',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentCalculationsCard(List recentCalculations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Calculations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            ...recentCalculations.take(3).map((calc) => _buildCalculationItem(calc)),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationItem(dynamic calc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: calc.calculationMethod == CalculationMethod.simpleAverage
                  ? Colors.blue
                  : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calculation ${calc.id.substring(0, 8)}...',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${calc.activeTenantsCount} tenants • ${MalaysianCurrency.format(calc.totalAmount)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            _formatRelativeTime(calc.createdAt),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentExpensesCard(List recentExpenses) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Expenses',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            ...recentExpenses.take(3).map((expense) => _buildExpenseItem(expense)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseItem(dynamic expense) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.receipt, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.periodDescription,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${expense.totalKWhUsage.toStringAsFixed(1)} kWh',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            _formatRelativeTime(expense.createdAt),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
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

  void _navigateToProperty(String propertyId) {
    // Navigate to specific property details screen (to be implemented)
  }
}