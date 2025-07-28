import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final Map<String, NumberFormat> _formatters = {};

  static String format(double amount, String currency) {
    final formatter = _getFormatter(currency);
    return formatter.format(amount);
  }

  static NumberFormat _getFormatter(String currency) {
    if (_formatters.containsKey(currency)) {
      return _formatters[currency]!;
    }

    late NumberFormat formatter;
    
    switch (currency) {
      case 'IDR':
        formatter = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        );
        break;
      case 'USD':
        formatter = NumberFormat.currency(
          locale: 'en_US',
          symbol: '\$',
          decimalDigits: 2,
        );
        break;
      case 'EUR':
        formatter = NumberFormat.currency(
          locale: 'de_DE',
          symbol: '€',
          decimalDigits: 2,
        );
        break;
      case 'GBP':
        formatter = NumberFormat.currency(
          locale: 'en_GB',
          symbol: '£',
          decimalDigits: 2,
        );
        break;
      case 'JPY':
        formatter = NumberFormat.currency(
          locale: 'ja_JP',
          symbol: '¥',
          decimalDigits: 0,
        );
        break;
      case 'SGD':
        formatter = NumberFormat.currency(
          locale: 'en_SG',
          symbol: 'S\$',
          decimalDigits: 2,
        );
        break;
      case 'MYR':
        formatter = NumberFormat.currency(
          locale: 'ms_MY',
          symbol: 'RM',
          decimalDigits: 2,
        );
        break;
      default:
        formatter = NumberFormat.currency(
          symbol: '$currency ',
          decimalDigits: 2,
        );
    }

    _formatters[currency] = formatter;
    return formatter;
  }

  static String formatSimple(double amount, String currency) {
    final absAmount = amount.abs();
    final sign = amount < 0 ? '-' : '';
    
    if (absAmount >= 1000000000) {
      return '$sign${(absAmount / 1000000000).toStringAsFixed(1)}B $currency';
    } else if (absAmount >= 1000000) {
      return '$sign${(absAmount / 1000000).toStringAsFixed(1)}M $currency';
    } else if (absAmount >= 1000) {
      return '$sign${(absAmount / 1000).toStringAsFixed(1)}K $currency';
    } else {
      return '$sign${absAmount.toStringAsFixed(currency == 'IDR' || currency == 'JPY' ? 0 : 2)} $currency';
    }
  }
}
