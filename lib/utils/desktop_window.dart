import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Configure desktop window size/position. No-op on mobile/web.
Future<void> configureDesktopWindow() async {
  if (kIsWeb) return;
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

  await windowManager.ensureInitialized();

  const portraitSize = Size(560, 960); // phone-ish portrait
  const minPortraitSize = Size(480, 800);

  final windowOptions = WindowOptions(
    size: portraitSize,
    minimumSize: minPortraitSize,
    center: true,
    title: 'Finoteku',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
