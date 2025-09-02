import 'package:intl/intl.dart';

class MalaysianCurrency {
  static const String currencyCode = 'MYR';
  static const String currencySymbol = 'RM';
  static const String locale = 'ms_MY';

  // Number formatters for Malaysian Ringgit
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: locale,
    symbol: currencySymbol,
    decimalDigits: 2,
  );

  static final NumberFormat _compactCurrencyFormatter = NumberFormat.compactCurrency(
    locale: locale,
    symbol: currencySymbol,
    decimalDigits: 2,
  );

  static final NumberFormat _simpleCurrencyFormatter = NumberFormat.currency(
    locale: locale,
    symbol: '',
    decimalDigits: 2,
  );

  // Format amount as Malaysian Ringgit with symbol
  static String format(double amount) {
    return _currencyFormatter.format(amount);
  }

  // Format amount as compact currency (e.g., RM1.2K)
  static String formatCompact(double amount) {
    return _compactCurrencyFormatter.format(amount);
  }

  // Format amount without currency symbol
  static String formatWithoutSymbol(double amount) {
    return _simpleCurrencyFormatter.format(amount);
  }

  // Format amount with custom decimal places
  static String formatWithDecimals(double amount, int decimalPlaces) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: currencySymbol,
      decimalDigits: decimalPlaces,
    );
    return formatter.format(amount);
  }

  // Parse Malaysian currency string to double
  static double? parse(String currencyString) {
    try {
      // Remove currency symbol and clean the string
      String cleanString = currencyString
          .replaceAll(currencySymbol, '')
          .replaceAll(' ', '')
          .replaceAll(',', '');
      
      return double.tryParse(cleanString);
    } catch (e) {
      return null;
    }
  }

  // Validate if amount is valid for Malaysian currency
  static bool isValidAmount(double amount) {
    // Malaysian sen is the smallest unit (0.01)
    return (amount * 100).round() == (amount * 100);
  }

  // Round to nearest sen (0.01)
  static double roundToSen(double amount) {
    return (amount * 100).round() / 100;
  }

  // Convert amount to sen (cents)
  static int toSen(double amount) {
    return (amount * 100).round();
  }

  // Convert sen to ringgit
  static double fromSen(int sen) {
    return sen / 100.0;
  }

  // Format for display in forms (no symbol, 2 decimal places)
  static String formatForInput(double amount) {
    return amount.toStringAsFixed(2);
  }

  // Format for display in lists or summaries
  static String formatForDisplay(double amount) {
    if (amount == 0) return 'RM0.00';
    return format(amount);
  }

  // Format large amounts with thousand separators
  static String formatLarge(double amount) {
    if (amount >= 1000000) {
      return formatCompact(amount);
    }
    return format(amount);
  }

  // Get currency info
  static Map<String, String> get currencyInfo => {
    'code': currencyCode,
    'symbol': currencySymbol,
    'name': 'Malaysian Ringgit',
    'locale': locale,
  };

  // Common amount presets for Malaysian context
  static const List<double> commonAmounts = [
    50.0,   // RM50
    100.0,  // RM100
    200.0,  // RM200
    500.0,  // RM500
    1000.0, // RM1000
    1500.0, // RM1500
    2000.0, // RM2000
  ];

  // Utility methods for calculations
  static double add(double amount1, double amount2) {
    return roundToSen(amount1 + amount2);
  }

  static double subtract(double amount1, double amount2) {
    return roundToSen(amount1 - amount2);
  }

  static double multiply(double amount, double multiplier) {
    return roundToSen(amount * multiplier);
  }

  static double divide(double amount, double divisor) {
    if (divisor == 0) return 0.0;
    return roundToSen(amount / divisor);
  }

  // Split amount among number of people
  static List<double> splitEvenly(double totalAmount, int numberOfPeople) {
    if (numberOfPeople <= 0) return [];
    
    double baseAmount = divide(totalAmount, numberOfPeople.toDouble());
    List<double> amounts = List.filled(numberOfPeople, baseAmount);
    
    // Handle remainder by adding 1 sen to first few people
    double remainder = subtract(totalAmount, multiply(baseAmount, numberOfPeople.toDouble()));
    int remainderSen = toSen(remainder);
    
    for (int i = 0; i < remainderSen && i < numberOfPeople; i++) {
      amounts[i] = add(amounts[i], 0.01);
    }
    
    return amounts;
  }

  // Calculate percentage of total
  static double calculatePercentage(double amount, double total) {
    if (total == 0) return 0.0;
    return (amount / total) * 100;
  }

  // Format percentage
  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(1)}%';
  }
}