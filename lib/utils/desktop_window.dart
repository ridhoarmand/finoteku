import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

/// Configure desktop window size/position. No-op on mobile/web.
Future<void> configureDesktopWindow() async {
  try {
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
      // Apply size before showing to avoid visible resize/blink
      await windowManager.setSize(portraitSize);

      // Attempt to set window icon from bundled asset for Linux/Windows
      try {
        final data = await rootBundle.load('assets/icon_desktop.png');
        final tempDir = await getTemporaryDirectory();
        final iconPath = '${tempDir.path}/finoteku_icon.png';
        final iconFile = File(iconPath);
        await iconFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
        await windowManager.setIcon(iconPath);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Failed to set window icon: $e');
        }
      }

      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    if (kDebugMode) {
      debugPrint('⚠️ Desktop window initialization skipped: $e');
    }
    // Swallow errors to avoid crashing on unsupported/edge environments
    return;
  }
}
