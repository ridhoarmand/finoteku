import 'package:flutter/services.dart';

/// A TextInputFormatter that formats numbers with thousand separators (dots)
/// Example: 1000 becomes 1.000, 1000000 becomes 1.000.000
class ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Preserve platform selection behavior when user only moves the cursor.
    if (oldValue.text == newValue.text) {
      return newValue;
    }

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

    // If formatter doesn't change text, keep original selection/composing state.
    if (formatted == newValue.text) {
      return newValue;
    }

    // Calculate the new cursor position
    final int cursorOffset = _calculateCursorOffset(
      oldValue.text,
      newValue.text,
      formatted,
      newValue.selection.baseOffset,
    );

    final clampedOffset = cursorOffset.clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: clampedOffset),
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
    // Extract digit-only versions to determine what changed
    final String oldDigits = oldText.replaceAll(RegExp(r'[^\d]'), '');
    final String newDigits = newText.replaceAll(RegExp(r'[^\d]'), '');

    // Detect if this is a deletion (text got shorter) or insertion (text got longer)
    final bool isDeletion = oldDigits.length > newDigits.length;

    // If cursor is at the end, keep it at the end
    if (originalOffset >= newText.length) {
      return formattedText.length;
    }

    // Count digits before cursor in the new text
    final String beforeCursor = newText.substring(0, originalOffset);
    final int digitsBefore = beforeCursor
        .replaceAll(RegExp(r'[^\d]'), '')
        .length;

    // Special handling for deletion at the start
    if (isDeletion && digitsBefore == 0) {
      // Keep cursor at the very beginning
      return 0;
    }

    // Find position in formatted text that has the same number of digits before it
    int digitsCount = 0;
    for (int i = 0; i < formattedText.length; i++) {
      if (formattedText[i].contains(RegExp(r'\d'))) {
        digitsCount++;
        // After counting the target number of digits, position after this digit
        if (digitsCount == digitsBefore) {
          return i + 1;
        }
      }
    }

    // Fallback: return position based on digits
    return digitsBefore == 0 ? 0 : formattedText.length;
  }
}
