import '../../../models/ledger_entry.dart';

/// Helper class untuk item dalam transaction list
class TxListItem {
  final bool isHeader;
  final DateTime? date;
  final LedgerEntry? entry;
  final bool isTransfer;
  final LedgerEntry? counterpart;

  TxListItem._(
    this.isHeader,
    this.date,
    this.entry,
    this.isTransfer,
    this.counterpart,
  );

  factory TxListItem.header(DateTime date) =>
      TxListItem._(true, date, null, false, null);

  factory TxListItem.entry(LedgerEntry e) =>
      TxListItem._(false, null, e, false, null);

  factory TxListItem.transfer(LedgerEntry a, LedgerEntry? b) =>
      TxListItem._(false, null, a, true, b);
}

/// Helper functions untuk transaction screen
class TransactionScreenHelpers {
  /// Check if two dates are the same day
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Format date with localization support
  static String formatDate(DateTime date, String Function(String) tr) {
    final now = DateTime.now();
    if (isSameDay(date, now)) {
      return tr('day_today');
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (isSameDay(date, yesterday)) {
      return tr('day_yesterday');
    }

    final weekdayKeys = [
      'weekday_monday',
      'weekday_tuesday',
      'weekday_wednesday',
      'weekday_thursday',
      'weekday_friday',
      'weekday_saturday',
      'weekday_sunday',
    ];
    final monthKeys = [
      'month_january',
      'month_february',
      'month_march',
      'month_april',
      'month_may',
      'month_june',
      'month_july',
      'month_august',
      'month_september',
      'month_october',
      'month_november',
      'month_december',
    ];
    final weekdayName = tr(weekdayKeys[date.weekday - 1]);
    final monthName = tr(monthKeys[date.month - 1]);
    return '$weekdayName, ${date.day} $monthName ${date.year}';
  }
}
