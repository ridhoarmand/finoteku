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

  static String formatCompact(double amount) {
    final absAmount = amount.abs();
    final sign = amount < 0 ? '-' : '';

    if (absAmount >= 1000000000) {
      return '${sign}Rp ${(absAmount / 1000000000).toStringAsFixed(1)}B';
    } else if (absAmount >= 1000000) {
      return '${sign}Rp ${(absAmount / 1000000).toStringAsFixed(1)}M';
    } else if (absAmount >= 1000) {
      return '${sign}Rp ${(absAmount / 1000).toStringAsFixed(0)}K';
    } else {
      return '${sign}Rp ${absAmount.toStringAsFixed(0)}';
    }
  }

  /// Parse formatted currency string back to double
  /// Handles Indonesian format where . is thousand separator
  static double? parse(String text) {
    if (text.isEmpty) return null;
    // Remove currency symbols and whitespace
    String cleanText = text.replaceAll(RegExp(r'[Rp\s]'), '');
    // Remove thousand separators (dots in Indonesian format)
    cleanText = cleanText.replaceAll('.', '');
    // Replace comma with dot for decimal (if any)
    cleanText = cleanText.replaceAll(',', '.');
    return double.tryParse(cleanText);
  }

  /// Format for input field display (with thousand separators)
  static String formatForInput(double amount, {bool withSymbol = false}) {
    final formatter = NumberFormat('#,###', 'id_ID');
    final formatted = formatter.format(amount.abs());
    final sign = amount < 0 ? '-' : '';
    return withSymbol ? 'Rp $sign$formatted' : '$sign$formatted';
  }
}
