import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../core/logging/logger.dart';
import '../models/ledger_entry.dart';
import '../models/wallet.dart';
import '../utils/currency_formatter.dart';

/// What the home-screen widget shows. A record, so equal snapshots compare equal.
typedef WidgetSnapshot = ({double balance, double todayExpense, DateTime? lastEntry});

/// Balance over visible wallets (same total as Beranda), today's spending there,
/// and the date of the newest entry in [entries] (any wallet: recording is recording).
WidgetSnapshot widgetSnapshot(List<LedgerEntry> entries, List<Wallet> wallets, DateTime now) {
  final visible = {for (final w in wallets) if (!w.isHidden) w.id};
  DateTime? last;
  var spent = 0.0;
  for (final e in entries) {
    if (last == null || e.date.isAfter(last)) last = e.date;
    final today = e.date.year == now.year && e.date.month == now.month && e.date.day == now.day;
    if (today && e.transferId == null && e.signedAmount < 0 && visible.contains(e.walletId)) spent += e.amount;
  }
  final balance = wallets.where((w) => !w.isHidden).fold<double>(0, (s, w) => s + w.balance);
  return (balance: balance, todayExpense: spent, lastEntry: last);
}

/// Bridge to the Android widget (android/.../FinotekuWidget.kt). No-op elsewhere.
class HomeWidgetService {
  static const _provider = 'id.ridhoarmand.finoteku.FinotekuWidget';
  static const addUri = 'finoteku://add';
  static final _day = DateFormat('yyyy-MM-dd');
  static Object? _lastPushed;
  static StreamSubscription<Uri?>? _clicks;

  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// [labels]: already translated texts, keyed as the widget reads them.
  static Future<void> push(WidgetSnapshot s, {required bool hidden, required Map<String, String> labels}) async {
    if (!_android) return;
    final key = (s, hidden, labels.values.join('|'));
    if (key == _lastPushed) return;
    _lastPushed = key;
    final now = DateTime.now();
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<bool>('signed_in', true),
        HomeWidget.saveWidgetData<String>('balance', hidden ? 'Rp ••••••' : CurrencyFormatter.format(s.balance, 'IDR')),
        HomeWidget.saveWidgetData<String>('today_expense', CurrencyFormatter.format(s.todayExpense, 'IDR')),
        HomeWidget.saveWidgetData<String>('snapshot_day', _day.format(now)),
        HomeWidget.saveWidgetData<String>('last_entry_day', s.lastEntry == null ? '' : _day.format(s.lastEntry!)),
        for (final l in labels.entries) HomeWidget.saveWidgetData<String>(l.key, l.value),
      ]);
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (e, st) {
      _lastPushed = null;
      AppLogger.e('home widget update failed', error: e, stackTrace: st);
    }
  }

  /// After sign-out: the widget asks to sign in instead of showing old numbers.
  static Future<void> clear() async {
    if (!_android) return;
    _lastPushed = null;
    try {
      await HomeWidget.saveWidgetData<bool>('signed_in', false);
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (e, st) {
      AppLogger.e('home widget clear failed', error: e, stackTrace: st);
    }
  }

  /// Calls [openAdd] when the widget's "+ Catat" started or resumed the app. Once per process.
  static void listenForAdd(void Function() openAdd) {
    if (!_android || _clicks != null) return;
    void handle(Uri? uri) {
      if (uri?.toString() == addUri) openAdd();
    }

    _clicks = HomeWidget.widgetClicked.listen(handle);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(handle).catchError((Object e) {
      AppLogger.e('home widget launch check failed', error: e);
    });
  }
}
