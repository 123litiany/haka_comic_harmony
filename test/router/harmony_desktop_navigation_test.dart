import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haka_comic/config/app_config.dart';
import 'package:haka_comic/config/setup_config.dart';
import 'package:haka_comic/database/images_helper.dart';
import 'package:haka_comic/main.dart';
import 'package:haka_comic/providers/search_provider.dart';
import 'package:haka_comic/providers/theme_color_provider.dart';
import 'package:haka_comic/providers/theme_mode_provider.dart';
import 'package:haka_comic/router/app_router.dart';
import 'package:haka_comic/utils/common.dart' as platform;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a desktop launch waits for login and avoids duplicate pages',
    (tester) async {
      final wasOhos = platform.isOhos;
      final wasWindows = platform.isWindows;
      final wasMacOS = platform.isMacOS;
      final wasLinux = platform.isLinux;
      platform.isOhos = true;
      platform.isWindows = false;
      platform.isMacOS = false;
      platform.isLinux = false;
      addTearDown(() {
        platform.isOhos = wasOhos;
        platform.isWindows = wasWindows;
        platform.isMacOS = wasMacOS;
        platform.isLinux = wasLinux;
      });

      final temp = Directory.systemTemp.createTempSync('haka-desktop-test-');
      SetupConf.dataPath = temp.path;
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      await AppConf.initialize();
      await tester.runAsync(ImagesHelper().initialize);
      addTearDown(() async {
        await ImagesHelper().db.close();
        await temp.delete(recursive: true);
      });

      const channel = MethodChannel('haka_comic/ohos_desktop');
      final messenger = tester.binding.defaultBinaryMessenger;
      String? pending = 'search';
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'takeAction');
        final action = pending;
        pending = null;
        return action;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeModeProvider()),
            ChangeNotifierProvider(create: (_) => ThemeColorProvider()),
            ChangeNotifierProvider(create: (_) => SearchProvider()),
          ],
          child: const App(),
        ),
      );
      await tester.pump();
      expect(appRouter.state.matchedLocation, '/login');

      AppConf().token = 'test-session';
      appRouter.go('/api_settings');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(appRouter.state.matchedLocation, '/search');

      Future<void> sendDesktopAction(String action) async {
        pending = action;
        final response = messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(const MethodCall('actionAvailable')),
          null,
        );
        await tester.pump();
        await response;
        await tester.pump();
      }

      await sendDesktopAction('search');
      appRouter.pop();
      await tester.pump();
      expect(appRouter.state.matchedLocation, '/api_settings');

      for (final action in ['favorites', 'rank']) {
        await sendDesktopAction(action);
        expect(appRouter.state.matchedLocation, '/$action');
        appRouter.pop();
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pumpWidget(const SizedBox.shrink());

      // Let the real SQLite worker finish the trim scheduled by App.initState.
      var databaseIdle = false;
      unawaited(
        ImagesHelper().db.writeLock((_) async {}).then((_) {
          databaseIdle = true;
        }),
      );
      for (var attempt = 0; !databaseIdle && attempt < 25; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(databaseIdle, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );
}
