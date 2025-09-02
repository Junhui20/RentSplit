import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _currencyCodeKey = 'currency_code';
  static const String _acRateKey = 'ac_rate_per_unit';
  static const String _firstLaunchKey = 'first_launch';

  // Currency settings
  Future<void> setCurrency(Currency currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyCodeKey, currency.code);
  }

  Future<Currency> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final currencyCode = prefs.getString(_currencyCodeKey);
    
    if (currencyCode != null) {
      final currency = Currency.getByCode(currencyCode);
      if (currency != null) {
        return currency;
      }
    }
    
    return Currency.defaultCurrency;
  }

  // AC rate settings
  Future<void> setACRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_acRateKey, rate);
  }

  Future<double> getACRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_acRateKey) ?? 0.218; // Default rate
  }

  // First launch flag
  Future<void> setFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }

  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstLaunchKey) ?? true;
  }

  // Clear all preferences
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Get all settings as a map for debugging/backup
  Future<Map<String, dynamic>> getAllSettings() async {
    final currency = await getCurrency();
    final acRate = await getACRate();
    final isFirst = await isFirstLaunch();

    return {
      'currency': currency.toMap(),
      'acRate': acRate,
      'isFirstLaunch': isFirst,
    };
  }
} 