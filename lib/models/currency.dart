class Currency {
  final String code;
  final String symbol;
  final String name;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  // Predefined currencies
  static const List<Currency> availableCurrencies = [
    Currency(code: 'USD', symbol: '\$', name: 'US Dollar'),
    Currency(code: 'EUR', symbol: '€', name: 'Euro'),
    Currency(code: 'GBP', symbol: '£', name: 'British Pound'),
    Currency(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
    Currency(code: 'CNY', symbol: '¥', name: 'Chinese Yuan'),
    Currency(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    Currency(code: 'CAD', symbol: '\$', name: 'Canadian Dollar'),
    Currency(code: 'AUD', symbol: '\$', name: 'Australian Dollar'),
    Currency(code: 'SGD', symbol: '\$', name: 'Singapore Dollar'),
    Currency(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit'),
    Currency(code: 'THB', symbol: '฿', name: 'Thai Baht'),
    Currency(code: 'KRW', symbol: '₩', name: 'South Korean Won'),
    Currency(code: 'PHP', symbol: '₱', name: 'Philippine Peso'),
    Currency(code: 'VND', symbol: '₫', name: 'Vietnamese Dong'),
    Currency(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah'),
    Currency(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real'),
    Currency(code: 'MXN', symbol: '\$', name: 'Mexican Peso'),
    Currency(code: 'RUB', symbol: '₽', name: 'Russian Ruble'),
    Currency(code: 'ZAR', symbol: 'R', name: 'South African Rand'),
    Currency(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
    Currency(code: 'SAR', symbol: 'ر.س', name: 'Saudi Riyal'),
  ];

  // Default currency (USD)
  static const Currency defaultCurrency = Currency(
    code: 'USD', 
    symbol: '\$', 
    name: 'US Dollar'
  );

  // Format amount with currency symbol
  String formatAmount(double amount, {bool showSymbol = true}) {
    final formattedAmount = amount.toStringAsFixed(2);
    return showSymbol ? '$symbol$formattedAmount' : formattedAmount;
  }

  // Get currency by code
  static Currency? getByCode(String code) {
    try {
      return availableCurrencies.firstWhere(
        (currency) => currency.code.toLowerCase() == code.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'symbol': symbol,
      'name': name,
    };
  }

  // Create from Map
  factory Currency.fromMap(Map<String, dynamic> map) {
    return Currency(
      code: map['code'] ?? 'USD',
      symbol: map['symbol'] ?? '\$',
      name: map['name'] ?? 'US Dollar',
    );
  }

  @override
  String toString() => '$name ($symbol)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Currency && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;
} 