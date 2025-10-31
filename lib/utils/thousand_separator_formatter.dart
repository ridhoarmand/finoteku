import 'package:flutter/services.dart';

/// A TextInputFormatter that formats numbers with thousand separators (dots)
/// Example: 1000 becomes 1.000, 1000000 becomes 1.000.000
class ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If the new value is empty, return it as is
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters
    final String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // If no digits, return empty
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Format with thousand separators
    final String formatted = _formatWithThousandSeparator(digitsOnly);

    // Calculate the new cursor position
    final int cursorOffset = _calculateCursorOffset(
      oldValue.text,
      newValue.text,
      formatted,
      newValue.selection.baseOffset,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  /// Formats a digit-only string with thousand separators (dots)
  String _formatWithThousandSeparator(String digitsOnly) {
    final buffer = StringBuffer();
    final int length = digitsOnly.length;

    for (int i = 0; i < length; i++) {
      // Add separator every 3 digits from the right
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digitsOnly[i]);
    }

    return buffer.toString();
  }

  /// Calculates the correct cursor position after formatting
  int _calculateCursorOffset(
    String oldText,
    String newText,
    String formattedText,
    int originalOffset,
  ) {
    // If cursor is at the end, keep it at the end
    if (originalOffset >= newText.length) {
      return formattedText.length;
    }

    // Count digits before cursor in the new text
    final String beforeCursor = newText.substring(0, originalOffset);
    final int digitsBefore = beforeCursor
        .replaceAll(RegExp(r'[^\d]'), '')
        .length;

    // Find position in formatted text that has the same number of digits before it
    int digitsCount = 0;
    for (int i = 0; i < formattedText.length; i++) {
      if (formattedText[i].contains(RegExp(r'\d'))) {
        digitsCount++;
      }
      if (digitsCount == digitsBefore) {
        return i + 1;
      }
    }

    return formattedText.length;
  }
}
