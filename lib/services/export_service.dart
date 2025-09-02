import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/calculation_result.dart';
import '../models/expense.dart';
import '../models/tenant.dart';
import '../models/tenant_calculation.dart';
import '../models/property.dart';
import '../models/malaysian_currency.dart';

/// Export Service for generating PDF and Excel reports
class ExportService {
  
  /// Export calculation results to PDF
  static Future<String> exportCalculationToPDF({
    required CalculationResult calculationResult,
    required Expense expense,
    required List<Tenant> tenants,
    required Property property,
  }) async {
    try {
      // Create PDF document
      final pdf = pw.Document();

      // Add main calculation page
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              _buildPDFHeader(property, expense, calculationResult),
              pw.SizedBox(height: 20),
              _buildPDFSummary(calculationResult),
              pw.SizedBox(height: 20),
              _buildPDFTenantBreakdown(calculationResult),
              pw.SizedBox(height: 20),
              _buildPDFFooter(),
            ];
          },
        ),
      );

      // Save PDF to file
      final directory = await getTemporaryDirectory();
      final fileName = 'calculation_${expense.periodDescription.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      return file.path;
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  /// Export individual tenant receipt to PDF
  static Future<String> exportTenantReceiptToPDF({
    required TenantCalculation tenantCalculation,
    required Tenant tenant,
    required Expense expense,
    required Property property,
  }) async {
    try {
      // Create PDF document
      final pdf = pw.Document();

      // Add receipt page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return _buildTenantReceiptPDF(tenantCalculation, tenant, expense, property);
          },
        ),
      );

      // Save PDF to file
      final directory = await getTemporaryDirectory();
      final fileName = 'receipt_${tenant.name.replaceAll(' ', '_')}_${expense.periodDescription.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      return file.path;
    } catch (e) {
      throw Exception('Failed to export tenant receipt PDF: $e');
    }
  }

  /// Export calculation results to Excel (CSV format)
  static Future<String> exportCalculationToExcel({
    required CalculationResult calculationResult,
    required Expense expense,
    required List<Tenant> tenants,
    required Property property,
  }) async {
    try {
      // Generate CSV content
      final content = _generateCSVContent(calculationResult, expense, tenants, property);
      
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final fileName = 'calculation_${expense.periodDescription.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      
      // Write content to file
      await file.writeAsString(content);
      
      return file.path;
    } catch (e) {
      throw Exception('Failed to export Excel: $e');
    }
  }

  /// Export financial summary report
  static Future<String> exportFinancialSummary({
    required List<CalculationResult> calculationResults,
    required List<Expense> expenses,
    required List<Property> properties,
    String? propertyFilter,
    int? yearFilter,
  }) async {
    try {
      // Filter results
      var filteredResults = calculationResults;
      
      if (propertyFilter != null) {
        final propertyExpenseIds = expenses
            .where((e) => e.propertyId == propertyFilter)
            .map((e) => e.id)
            .toSet();
        filteredResults = filteredResults.where((r) => propertyExpenseIds.contains(r.expenseId)).toList();
      }
      
      if (yearFilter != null) {
        final yearExpenseIds = expenses
            .where((e) => e.year == yearFilter)
            .map((e) => e.id)
            .toSet();
        filteredResults = filteredResults.where((r) => yearExpenseIds.contains(r.expenseId)).toList();
      }

      // Generate summary content
      final content = _generateSummaryContent(filteredResults, expenses, properties);
      
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final fileName = 'financial_summary_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      
      // Write content to file
      await file.writeAsString(content);
      
      return file.path;
    } catch (e) {
      throw Exception('Failed to export financial summary: $e');
    }
  }

  /// Share exported file
  static Future<void> shareFile(String filePath, String title) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: title,
      );
    } catch (e) {
      throw Exception('Failed to share file: $e');
    }
  }

  /// Share text content
  static Future<void> shareText(String text, String title) async {
    try {
      await Share.share(
        text,
        subject: title,
      );
    } catch (e) {
      throw Exception('Failed to share text: $e');
    }
  }

  /// Build PDF header section
  static pw.Widget _buildPDFHeader(Property property, Expense expense, CalculationResult calculationResult) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RENT CALCULATION RESULTS',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Property: ${property.name}',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.Text(
                  'Period: ${expense.periodDescription}',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.Text(
                  'Method: ${calculationResult.calculationMethod.displayName}',
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Generated: ${_formatPDFDate(calculationResult.createdAt)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'RentSplit App',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Build PDF summary section
  static pw.Widget _buildPDFSummary(CalculationResult calculationResult) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUMMARY',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Amount:', style: const pw.TextStyle(fontSize: 14)),
              pw.Text(
                MalaysianCurrency.format(calculationResult.totalAmount),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Active Tenants:', style: const pw.TextStyle(fontSize: 14)),
              pw.Text(
                '${calculationResult.activeTenantsCount}',
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Average per Tenant:', style: const pw.TextStyle(fontSize: 14)),
              pw.Text(
                MalaysianCurrency.format(calculationResult.totalAmount / calculationResult.activeTenantsCount),
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build PDF tenant breakdown section
  static pw.Widget _buildPDFTenantBreakdown(CalculationResult calculationResult) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TENANT BREAKDOWN',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        ...calculationResult.tenantCalculations.map((calc) =>
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      calc.tenantName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      MalaysianCurrency.format(calc.totalAmount),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 8),
                if (calc.rentShare > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Rent Share:', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(MalaysianCurrency.format(calc.rentShare), style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                ],
                if (calc.internetShare > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Internet Share:', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(MalaysianCurrency.format(calc.internetShare), style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                ],
                if (calc.waterShare > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Water Share:', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(MalaysianCurrency.format(calc.waterShare), style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                ],
                if (calc.commonElectricityShare > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Common Electricity:', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(MalaysianCurrency.format(calc.commonElectricityShare), style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                ],
                if (calc.individualACCost > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('AC Usage (${calc.acUsageKWh.toStringAsFixed(1)} kWh):', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(MalaysianCurrency.format(calc.individualACCost), style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                ],
                if (calc.miscellaneousShare > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Other Fees:', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(MalaysianCurrency.format(calc.miscellaneousShare), style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build PDF footer
  static pw.Widget _buildPDFFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generated by RentSplit App - Professional Rent Calculation Solution',
          style: pw.TextStyle(
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey600,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  /// Build individual tenant receipt PDF
  static pw.Widget _buildTenantReceiptPDF(
    TenantCalculation tenantCalculation,
    Tenant tenant,
    Expense expense,
    Property property,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'RENT RECEIPT',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Property: ${property.name}',
                style: const pw.TextStyle(fontSize: 16),
              ),
              pw.Text(
                'Period: ${expense.periodDescription}',
                style: const pw.TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 24),

        // Tenant Info
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TENANT INFORMATION',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Name: ${tenantCalculation.tenantName}', style: const pw.TextStyle(fontSize: 14)),
              if (tenant.email != null) pw.Text('Email: ${tenant.email}', style: const pw.TextStyle(fontSize: 14)),
              if (tenant.phone != null) pw.Text('Phone: ${tenant.phone}', style: const pw.TextStyle(fontSize: 14)),
            ],
          ),
        ),

        pw.SizedBox(height: 24),

        // Breakdown
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'EXPENSE BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              if (tenantCalculation.rentShare > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Rent Share', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(MalaysianCurrency.format(tenantCalculation.rentShare), style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
              if (tenantCalculation.internetShare > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Internet Share', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(MalaysianCurrency.format(tenantCalculation.internetShare), style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
              if (tenantCalculation.waterShare > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Water Share', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(MalaysianCurrency.format(tenantCalculation.waterShare), style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
              if (tenantCalculation.commonElectricityShare > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Common Electricity', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(MalaysianCurrency.format(tenantCalculation.commonElectricityShare), style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
              if (tenantCalculation.individualACCost > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('AC Usage (${tenantCalculation.acUsageKWh.toStringAsFixed(1)} kWh)', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(MalaysianCurrency.format(tenantCalculation.individualACCost), style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
              if (tenantCalculation.miscellaneousShare > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Other Fees', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(MalaysianCurrency.format(tenantCalculation.miscellaneousShare), style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL AMOUNT',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    MalaysianCurrency.format(tenantCalculation.totalAmount),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.Spacer(),

        // Footer
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'Receipt generated on ${_formatPDFDate(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated by RentSplit App',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Format date for PDF
  static String _formatPDFDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Generate PDF content as formatted text (legacy method for compatibility)
  // ignore: unused_element
  static String _generatePDFContent(
    CalculationResult calculationResult,
    Expense expense,
    List<Tenant> tenants,
    Property property,
  ) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('RENT SPLIT CALCULATION REPORT');
    buffer.writeln('=' * 50);
    buffer.writeln();
    
    // Property and Period Info
    buffer.writeln('PROPERTY INFORMATION');
    buffer.writeln('-' * 30);
    buffer.writeln('Property: ${property.name}');
    buffer.writeln('Location: ${property.address}, ${property.state}');
    buffer.writeln('Period: ${expense.periodDescription}');
    buffer.writeln('Calculation Method: ${calculationResult.calculationMethod.displayName}');
    buffer.writeln('Active Tenants: ${calculationResult.activeTenantsCount}');
    buffer.writeln();
    
    // Summary
    buffer.writeln('CALCULATION SUMMARY');
    buffer.writeln('-' * 30);
    buffer.writeln('Total Amount: ${MalaysianCurrency.format(calculationResult.totalAmount)}');
    buffer.writeln('Average per Tenant: ${MalaysianCurrency.format(calculationResult.averageAmountPerTenant)}');
    buffer.writeln();
    
    // Expense Breakdown
    buffer.writeln('EXPENSE BREAKDOWN');
    buffer.writeln('-' * 30);
    buffer.writeln('Base Rent: ${MalaysianCurrency.format(expense.baseRent)}');
    buffer.writeln('Internet Fee: ${MalaysianCurrency.format(expense.internetFee)}');
    buffer.writeln('Water Bill: ${MalaysianCurrency.format(expense.waterBill)}');
    buffer.writeln('Electricity Usage: ${expense.totalKWhUsage.toStringAsFixed(1)} kWh');
    if (expense.miscellaneousExpenses > 0) {
      buffer.writeln('Miscellaneous: ${MalaysianCurrency.format(expense.miscellaneousExpenses)}');
    }
    buffer.writeln();
    
    // Individual Tenant Calculations
    buffer.writeln('INDIVIDUAL TENANT BREAKDOWN');
    buffer.writeln('-' * 30);
    
    for (final tenantCalc in calculationResult.tenantCalculations) {
      buffer.writeln();
      buffer.writeln('Tenant: ${tenantCalc.tenantName}');
      buffer.writeln('  Rent Share: ${MalaysianCurrency.format(tenantCalc.rentShare)}');
      buffer.writeln('  Internet Share: ${MalaysianCurrency.format(tenantCalc.internetShare)}');
      buffer.writeln('  Water Share: ${MalaysianCurrency.format(tenantCalc.waterShare)}');
      buffer.writeln('  Common Electricity: ${MalaysianCurrency.format(tenantCalc.commonElectricityShare)}');
      if (tenantCalc.individualACCost > 0) {
        buffer.writeln('  Individual AC Cost: ${MalaysianCurrency.format(tenantCalc.individualACCost)}');
        buffer.writeln('  AC Usage: ${tenantCalc.acUsageKWh.toStringAsFixed(1)} kWh');
      }
      if (tenantCalc.miscellaneousShare > 0) {
        buffer.writeln('  Miscellaneous Share: ${MalaysianCurrency.format(tenantCalc.miscellaneousShare)}');
      }
      buffer.writeln('  TOTAL: ${MalaysianCurrency.format(tenantCalc.totalAmount)}');
    }
    
    // Footer
    buffer.writeln();
    buffer.writeln('=' * 50);
    buffer.writeln('Generated on: ${DateTime.now().toString()}');
    buffer.writeln('RentSplit App - Malaysian Rent & Utility Calculator');
    
    return buffer.toString();
  }

  /// Generate CSV content for Excel
  static String _generateCSVContent(
    CalculationResult calculationResult,
    Expense expense,
    List<Tenant> tenants,
    Property property,
  ) {
    final buffer = StringBuffer();
    
    // Header row
    buffer.writeln('Tenant Name,Rent Share,Internet Share,Water Share,Common Electricity,Individual AC Cost,AC Usage (kWh),Miscellaneous Share,Total Amount');
    
    // Data rows
    for (final tenantCalc in calculationResult.tenantCalculations) {
      buffer.writeln([
        tenantCalc.tenantName,
        tenantCalc.rentShare.toStringAsFixed(2),
        tenantCalc.internetShare.toStringAsFixed(2),
        tenantCalc.waterShare.toStringAsFixed(2),
        tenantCalc.commonElectricityShare.toStringAsFixed(2),
        tenantCalc.individualACCost.toStringAsFixed(2),
        tenantCalc.acUsageKWh.toStringAsFixed(1),
        tenantCalc.miscellaneousShare.toStringAsFixed(2),
        tenantCalc.totalAmount.toStringAsFixed(2),
      ].join(','));
    }
    
    // Summary rows
    buffer.writeln();
    buffer.writeln('SUMMARY');
    buffer.writeln('Property,${property.name}');
    buffer.writeln('Period,${expense.periodDescription}');
    buffer.writeln('Method,${calculationResult.calculationMethod.displayName}');
    buffer.writeln('Total Amount,${calculationResult.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('Active Tenants,${calculationResult.activeTenantsCount}');
    
    return buffer.toString();
  }

  /// Export detailed financial report as PDF
  static Future<String> exportDetailedFinancialReport({
    required List<CalculationResult> calculationResults,
    required List<Expense> expenses,
    required List<Property> properties,
    required Map<String, dynamic> analytics,
    String? propertyFilter,
    int? yearFilter,
  }) async {
    try {
      // Create PDF document
      final pdf = pw.Document();

      // Add comprehensive report pages
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              _buildDetailedReportHeader(propertyFilter, yearFilter),
              pw.SizedBox(height: 20),
              _buildDetailedReportSummary(calculationResults),
              pw.SizedBox(height: 20),
              _buildDetailedPropertyAnalysis(calculationResults, expenses, properties),
              pw.SizedBox(height: 20),
              _buildDetailedMethodAnalysis(calculationResults),
              pw.SizedBox(height: 20),
              _buildPDFFooter(),
            ];
          },
        ),
      );

      // Save PDF to file
      final directory = await getTemporaryDirectory();
      final fileName = 'detailed_financial_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      return file.path;
    } catch (e) {
      throw Exception('Failed to export detailed financial report: $e');
    }
  }

  /// Export analytics data as CSV
  static Future<String> exportAnalyticsData({
    required List<CalculationResult> calculationResults,
    required List<Expense> expenses,
    required List<Property> properties,
    required Map<String, dynamic> analytics,
  }) async {
    try {
      // Generate analytics CSV content
      final content = _generateAnalyticsCSVContent(calculationResults, expenses, properties);

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final fileName = 'analytics_data_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');

      // Write content to file
      await file.writeAsString(content);

      return file.path;
    } catch (e) {
      throw Exception('Failed to export analytics data: $e');
    }
  }

  /// Build detailed report header
  static pw.Widget _buildDetailedReportHeader(String? propertyFilter, int? yearFilter) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DETAILED FINANCIAL REPORT',
          style: pw.TextStyle(
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generated: ${_formatPDFDate(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 14),
        ),
        if (propertyFilter != null) ...[
          pw.Text(
            'Property Filter: $propertyFilter',
            style: const pw.TextStyle(fontSize: 14),
          ),
        ],
        if (yearFilter != null) ...[
          pw.Text(
            'Year Filter: $yearFilter',
            style: const pw.TextStyle(fontSize: 14),
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Build detailed report summary
  static pw.Widget _buildDetailedReportSummary(List<CalculationResult> calculationResults) {
    final totalAmount = calculationResults.fold<double>(0.0, (sum, result) => sum + result.totalAmount);
    final avgAmount = calculationResults.isNotEmpty ? totalAmount / calculationResults.length : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'EXECUTIVE SUMMARY',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Calculations:', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('${calculationResults.length}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Amount:', style: const pw.TextStyle(fontSize: 14)),
              pw.Text(MalaysianCurrency.format(totalAmount), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Average Amount:', style: const pw.TextStyle(fontSize: 14)),
              pw.Text(MalaysianCurrency.format(avgAmount), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  /// Build detailed property analysis
  static pw.Widget _buildDetailedPropertyAnalysis(
    List<CalculationResult> calculationResults,
    List<Expense> expenses,
    List<Property> properties,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PROPERTY ANALYSIS',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Detailed breakdown by property performance and metrics.',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 8),
        // Add property analysis content here
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            'Property performance metrics and comparative analysis would be displayed here.',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Build detailed method analysis
  static pw.Widget _buildDetailedMethodAnalysis(List<CalculationResult> calculationResults) {
    final methodCounts = <CalculationMethod, int>{};
    for (final result in calculationResults) {
      methodCounts[result.calculationMethod] = (methodCounts[result.calculationMethod] ?? 0) + 1;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CALCULATION METHOD ANALYSIS',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        ...methodCounts.entries.map((entry) {
          final percentage = calculationResults.isNotEmpty
              ? (entry.value / calculationResults.length * 100).toStringAsFixed(1)
              : '0.0';
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(entry.key.displayName, style: const pw.TextStyle(fontSize: 12)),
                pw.Text('${entry.value} ($percentage%)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Generate analytics CSV content
  static String _generateAnalyticsCSVContent(
    List<CalculationResult> calculationResults,
    List<Expense> expenses,
    List<Property> properties,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Property,Period,Method,Total Amount,Active Tenants,Created Date,Tenant Name,Tenant Amount,AC Usage kWh,AC Cost');

    // Data rows with tenant details
    for (final result in calculationResults) {
      final expense = expenses.firstWhere((e) => e.id == result.expenseId);
      final property = properties.firstWhere((p) => p.id == expense.propertyId);

      for (final tenantCalc in result.tenantCalculations) {
        buffer.writeln([
          property.name,
          expense.periodDescription,
          result.calculationMethod.displayName,
          result.totalAmount.toStringAsFixed(2),
          result.activeTenantsCount,
          '${result.createdAt.day}/${result.createdAt.month}/${result.createdAt.year}',
          tenantCalc.tenantName,
          tenantCalc.totalAmount.toStringAsFixed(2),
          tenantCalc.acUsageKWh.toStringAsFixed(2),
          tenantCalc.individualACCost.toStringAsFixed(2),
        ].join(','));
      }
    }

    return buffer.toString();
  }

  /// Generate financial summary content
  static String _generateSummaryContent(
    List<CalculationResult> calculationResults,
    List<Expense> expenses,
    List<Property> properties,
  ) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Property,Period,Method,Total Amount,Active Tenants,Created Date');
    
    // Data rows
    for (final result in calculationResults) {
      final expense = expenses.firstWhere((e) => e.id == result.expenseId);
      final property = properties.firstWhere((p) => p.id == expense.propertyId);
      
      buffer.writeln([
        property.name,
        expense.periodDescription,
        result.calculationMethod.displayName,
        result.totalAmount.toStringAsFixed(2),
        result.activeTenantsCount,
        '${result.createdAt.day}/${result.createdAt.month}/${result.createdAt.year}',
      ].join(','));
    }
    
    // Summary statistics
    if (calculationResults.isNotEmpty) {
      final totalAmount = calculationResults.fold<double>(0.0, (sum, result) => sum + result.totalAmount);
      final avgAmount = totalAmount / calculationResults.length;
      
      buffer.writeln();
      buffer.writeln('SUMMARY STATISTICS');
      buffer.writeln('Total Calculations,${calculationResults.length}');
      buffer.writeln('Total Amount,${totalAmount.toStringAsFixed(2)}');
      buffer.writeln('Average Amount,${avgAmount.toStringAsFixed(2)}');
    }
    
    return buffer.toString();
  }
}
