import 'package:intl/intl.dart';

final _idrFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
String formatCurrencyIDR(double value) => _idrFormatter.format(value);
