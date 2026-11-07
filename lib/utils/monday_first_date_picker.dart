import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

Future<DateTime?> showMondayFirstDatePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialDate,
  DateTime? currentDate,
  Locale locale = const Locale('id'),
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    currentDate: currentDate,
    builder: (dialogContext, child) {
      return Localizations.override(
        context: context,
        locale: locale,
        delegates: const [_MondayFirstMaterialLocalizationsDelegate()],
        child: child,
      );
    },
  );
}

/// Date range picker with weeks starting on Monday (same localisation as above).
Future<DateTimeRange?> showMondayFirstDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
  Locale locale = const Locale('id'),
}) {
  return showDateRangePicker(
    context: context,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDateRange: initialDateRange,
    builder: (dialogContext, child) {
      return Localizations.override(
        context: context,
        locale: locale,
        delegates: const [_MondayFirstMaterialLocalizationsDelegate()],
        child: child,
      );
    },
  );
}

class _MondayFirstMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _MondayFirstMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'id';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    assert(isSupported(locale));

    final localeName = intl.Intl.canonicalizedLocale(locale.toString());

    intl.DateFormat fullYearFormat;
    intl.DateFormat compactDateFormat;
    intl.DateFormat shortDateFormat;
    intl.DateFormat mediumDateFormat;
    intl.DateFormat longDateFormat;
    intl.DateFormat yearMonthFormat;
    intl.DateFormat shortMonthDayFormat;
    if (intl.DateFormat.localeExists(localeName)) {
      fullYearFormat = intl.DateFormat.y(localeName);
      compactDateFormat = intl.DateFormat.yMd(localeName);
      shortDateFormat = intl.DateFormat.yMMMd(localeName);
      mediumDateFormat = intl.DateFormat.MMMEd(localeName);
      longDateFormat = intl.DateFormat.yMMMMEEEEd(localeName);
      yearMonthFormat = intl.DateFormat.yMMMM(localeName);
      shortMonthDayFormat = intl.DateFormat.MMMd(localeName);
    } else if (intl.DateFormat.localeExists(locale.languageCode)) {
      fullYearFormat = intl.DateFormat.y(locale.languageCode);
      compactDateFormat = intl.DateFormat.yMd(locale.languageCode);
      shortDateFormat = intl.DateFormat.yMMMd(locale.languageCode);
      mediumDateFormat = intl.DateFormat.MMMEd(locale.languageCode);
      longDateFormat = intl.DateFormat.yMMMMEEEEd(locale.languageCode);
      yearMonthFormat = intl.DateFormat.yMMMM(locale.languageCode);
      shortMonthDayFormat = intl.DateFormat.MMMd(locale.languageCode);
    } else {
      fullYearFormat = intl.DateFormat.y();
      compactDateFormat = intl.DateFormat.yMd();
      shortDateFormat = intl.DateFormat.yMMMd();
      mediumDateFormat = intl.DateFormat.MMMEd();
      longDateFormat = intl.DateFormat.yMMMMEEEEd();
      yearMonthFormat = intl.DateFormat.yMMMM();
      shortMonthDayFormat = intl.DateFormat.MMMd();
    }

    intl.NumberFormat decimalFormat;
    intl.NumberFormat twoDigitZeroPaddedFormat;
    if (intl.NumberFormat.localeExists(localeName)) {
      decimalFormat = intl.NumberFormat.decimalPattern(localeName);
      twoDigitZeroPaddedFormat = intl.NumberFormat('00', localeName);
    } else if (intl.NumberFormat.localeExists(locale.languageCode)) {
      decimalFormat = intl.NumberFormat.decimalPattern(locale.languageCode);
      twoDigitZeroPaddedFormat = intl.NumberFormat('00', locale.languageCode);
    } else {
      decimalFormat = intl.NumberFormat.decimalPattern();
      twoDigitZeroPaddedFormat = intl.NumberFormat('00');
    }

    return SynchronousFuture<MaterialLocalizations>(
      _MondayFirstMaterialLocalizationId(
        fullYearFormat: fullYearFormat,
        compactDateFormat: compactDateFormat,
        shortDateFormat: shortDateFormat,
        mediumDateFormat: mediumDateFormat,
        longDateFormat: longDateFormat,
        yearMonthFormat: yearMonthFormat,
        shortMonthDayFormat: shortMonthDayFormat,
        decimalFormat: decimalFormat,
        twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
      ),
    );
  }

  @override
  bool shouldReload(_MondayFirstMaterialLocalizationsDelegate old) => false;
}

class _MondayFirstMaterialLocalizationId extends MaterialLocalizationId {
  const _MondayFirstMaterialLocalizationId({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  int get firstDayOfWeekIndex => 1;
}
