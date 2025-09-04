import 'package:flutter/material.dart';
import '../models/malaysian_currency.dart';
import '../models/calculation_result.dart';
import '../database/database_helper.dart';
import '../widgets/responsive_helper.dart';
import '../theme/app_theme.dart';
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
    final totalProperties = _portfolioSummary?['totalProperties'] ?? 0;
    final totalUnits = _portfolioSummary?['totalUnits'] ?? 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: 12,
        shadowColor: Theme.of(context).primaryColor.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: AppTheme.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                blurRadius: 25,
                offset: const Offset(0, 12),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: 5,
              ),
            ],
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.home_work,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RentSplit Malaysia',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        totalProperties > 0
                          ? 'Managing $totalProperties properties • $totalUnits units'
                          : 'Your property management solution',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.95),
                          letterSpacing: 0.3,
                          shadows: const [
                            Shadow(
                              color: Colors.black12,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (totalProperties == 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Start by adding your first property to begin managing your rental portfolio',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
              AppTheme.primaryBlue,
            ),
            _buildSummaryCard(
              'Total Units',
              '${_portfolioSummary!['totalUnits']}',
              Icons.apartment,
              AppTheme.secondaryTeal,
            ),
            _buildSummaryCard(
              'Occupancy Rate',
              '${_portfolioSummary!['occupancyRate'].toStringAsFixed(1)}%',
              Icons.people,
              AppTheme.accentOrange,
            ),
            _buildSummaryCard(
              'Monthly Income',
              MalaysianCurrency.format(_portfolioSummary!['totalMonthlyRent']),
              Icons.attach_money,
              AppTheme.accentAmber,
            ),
          ],
        ),
      ],
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
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
                    textAlign: TextAlign.center,
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
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: ResponsiveHelper.getResponsiveAspectRatio(context, mobile: 1.4, tablet: 1.5, desktop: 1.6),
          children: [
            _buildActionCard(
              'Add Property',
              Icons.add_home,
              AppTheme.primaryBlue,
              () => _navigateToAddProperty(),
            ),
            _buildActionCard(
              'Calculate Utilities',
              Icons.calculate,
              AppTheme.secondaryTeal,
              () => _navigateToCalculateUtilities(),
            ),
            _buildActionCard(
              'View Reports',
              Icons.analytics,
              AppTheme.accentOrange,
              () => _navigateToReports(),
            ),
            _buildActionCard(
              'Manage Tenants',
              Icons.people_alt,
              AppTheme.accentAmber,
              () => _navigateToTenants(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Card(
        elevation: 6,
        shadowColor: color.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: color.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  color.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.15),
                          color.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                            color: color.withValues(alpha: 0.2),
                            offset: const Offset(0, 0.5),
                            blurRadius: 1,
                          ),
                        ],
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