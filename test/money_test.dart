import 'package:finoteku/utils/currency_formatter.dart';
import 'package:finoteku/utils/thousand_separator_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _type(String old, String typed) =>
    ThousandSeparatorFormatter().formatEditUpdate(
      TextEditingValue(text: old),
      TextEditingValue(
        text: typed,
        selection: TextSelection.collapsed(offset: typed.length),
      ),
    );

void main() {
  group('CurrencyFormatter.parse', () {
    test('Indonesian thousands and decimals', () {
      expect(CurrencyFormatter.parse('Rp 1.500.000'), 1500000);
      expect(CurrencyFormatter.parse('1.500.000,50'), 1500000.5);
      expect(CurrencyFormatter.parse('0'), 0);
    });

    test('empty or garbage gives null', () {
      expect(CurrencyFormatter.parse(''), isNull);
      expect(CurrencyFormatter.parse('abc'), isNull);
    });

    test('round-trips formatForInput', () {
      for (final v in [0.0, 999.0, 1000.0, 1234567.0]) {
        expect(CurrencyFormatter.parse(CurrencyFormatter.formatForInput(v)), v);
      }
    });
  });

  group('ThousandSeparatorFormatter', () {
    test('groups digits with dots, cursor at end', () {
      final v = _type('100.000', '100.0000');
      expect(v.text, '1.000.000');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('strips non-digits and handles clear', () {
      expect(_type('', '12a3').text, '123');
      expect(_type('1', '').text, '');
    });
  });
}
