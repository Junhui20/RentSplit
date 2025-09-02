import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/preferences_service.dart';

class AppStateProvider extends ChangeNotifier {
  final PreferencesService _prefsService = PreferencesService();

  Currency _currency = Currency.defaultCurrency;
  double _acRate = 0.218;
  bool _isLoading = false;

  Currency get currency => _currency;
  double get acRate => _acRate;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currency = await _prefsService.getCurrency();
      _acRate = await _prefsService.getACRate();
    } catch (e) {
      // Use defaults if there's an error
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setCurrency(Currency currency) async {
    _currency = currency;
    await _prefsService.setCurrency(currency);
    notifyListeners();
  }

  Future<void> setACRate(double rate) async {
    _acRate = rate;
    await _prefsService.setACRate(rate);
    notifyListeners();
  }

  String formatAmount(double amount) {
    return _currency.formatAmount(amount);
  }
} 