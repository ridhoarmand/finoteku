// Screenshot tour of the main screens, for UI review (Linux desktop).
//
//   xvfb-run -s "-screen 0 1280x900x24" flutter test integration_test -d linux \
//     --dart-define-from-file=.env --dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=... \
//     --dart-define=THEME=dark --dart-define=SHOT_DIR=/tmp/shots
//
// Run with XDG_DATA_HOME pointing at a throwaway folder: the tour writes app prefs and a session.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:finoteku/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const email = String.fromEnvironment('TEST_EMAIL');
const password = String.fromEnvironment('TEST_PASSWORD');
const theme = String.fromEnvironment('THEME', defaultValue: 'light');
const shotDir = String.fromEnvironment('SHOT_DIR', defaultValue: '/tmp/finoteku-shots');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshot tour', (tester) async {
    expect(email, isNotEmpty, reason: 'pass --dart-define=TEST_EMAIL/TEST_PASSWORD');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_preference', 'id');
    await prefs.setString('app_locale_code', 'id');
    await prefs.setBool('hasSeenOnboarding', true);
    await prefs.setInt('theme_mode', theme == 'dark' ? 2 : 1);
    Directory(shotDir).createSync(recursive: true);

    // The app keeps animating (spinners, shimmer), so wait in fixed steps instead of pumpAndSettle.
    Future<void> wait([int ms = 1500]) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // Renders the app's own layer tree to PNG: independent of the X server / window manager.
    Future<void> shot(String name) async {
      await wait(1200);
      final view = tester.binding.renderViews.first;
      final layer = view.debugLayer! as OffsetLayer;
      final image = await tester.runAsync(() => layer.toImage(Offset.zero & view.size, pixelRatio: 1.5));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      File('$shotDir/${theme}_$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    Future<bool> tapText(String text) async {
      final f = find.text(text);
      if (f.evaluate().isEmpty) return false;
      await tester.tap(f.first);
      await wait();
      return true;
    }

    Future<void> back() async {
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.pop();
      await wait();
    }

    app.main();
    await wait(6000);

    if (find.byType(TextFormField).evaluate().length >= 2) {
      await tester.enterText(find.byType(TextFormField).at(0), email);
      await tester.enterText(find.byType(TextFormField).at(1), password);
      await tester.tap(find.byType(FilledButton).first);
      await wait(8000);
    }

    await shot('01_home');
    await tapText('Transaksi');
    await wait(3000);
    await shot('02_transactions');
    final fab = find.byType(FloatingActionButton);
    if (fab.evaluate().isNotEmpty) {
      await tester.tap(fab.first);
      await wait(2500);
      await shot('03_add_transaction');
      await back();
    }
    await tapText('Laporan');
    await wait(3000);
    await shot('04_report');
    if (await tapText('Semua Dompet')) {
      await wait(1000);
      await shot('04a_wallet_filter');
      final rows = find.byType(ListTile);
      if (rows.evaluate().length > 1) {
        await tester.tap(rows.at(1));
        await wait(2500);
        await shot('04a_report_one_wallet');
      }
    }
    if (await tapText('Anggaran')) {
      await wait(2500);
      await shot('04b_budget');
    }
    await tapText('Akun');
    await wait(2000);
    await shot('05_account');
    if (await tapText('Kelola Dompet')) {
      await wait(2000);
      await shot('06_wallets');
      // wallet logo picker (idn-finlogos)
      final add = find.descendant(of: find.byType(AppBar), matching: find.byType(IconButton));
      if (add.evaluate().isNotEmpty) {
        await tester.tap(add.last);
        await wait();
        if (await tapText('Pilih Ikon')) {
          await wait(2500);
          await shot('06b_wallet_logos');
          await back();
        }
        await back();
      }
      await back();
    }
    if (await tapText('Kelola Kategori')) {
      await wait(2000);
      await shot('07_categories');
      await back();
    }
    if (await tapText('Chat Bot')) {
      await wait(2500);
      await shot('08_bot');
      await back();
    }
    await tapText('Beranda');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
