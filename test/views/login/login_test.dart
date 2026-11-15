import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haka_comic/config/app_config.dart';
import 'package:haka_comic/utils/shared_preferences_util.dart';
import 'package:haka_comic/views/login/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _setPhoneSize();
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    SharedPreferencesUtil.prefsWithCache =
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(),
        );
    await AppConf.initialize();
  });

  testWidgets('settings entries open from the top-right overflow menu', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('API切换'), findsNothing);
    expect(find.text('代理设置'), findsNothing);

    final settingsMenu = find.byTooltip('设置');
    expect(settingsMenu, findsOneWidget);
    expect(tester.getTopRight(settingsMenu).dx, greaterThan(360));
    expect(tester.getTopLeft(settingsMenu).dy, lessThan(80));

    await tester.tap(settingsMenu);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(MenuItemButton, 'API切换'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '代理设置'), findsOneWidget);

    await tester.tap(find.widgetWithText(MenuItemButton, 'API切换'));
    await tester.pumpAndSettle();
    expect(find.text('API settings page'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(settingsMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '代理设置'));
    await tester.pumpAndSettle();
    expect(find.text('Proxy settings page'), findsOneWidget);
  });

  testWidgets('a registered account is filled back into the login form', (
    tester,
  ) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byType(TextFormField).at(0), 'oldAccount');
    await tester.enterText(find.byType(TextFormField).at(1), 'oldPassword');
    await tester.ensureVisible(find.widgetWithText(TextButton, '注册'));
    await tester.tap(find.widgetWithText(TextButton, '注册'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete registration'));
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields[0].controller!.text, 'newTestAccount');
    expect(fields[1].controller!.text, isEmpty);
  });
}

GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Login()),
      GoRoute(
        path: '/api_settings',
        builder: (_, _) => const Scaffold(body: Text('API settings page')),
      ),
      GoRoute(
        path: '/proxy_settings',
        builder: (_, _) => const Scaffold(body: Text('Proxy settings page')),
      ),
      GoRoute(
        path: '/register',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.pop('newTestAccount'),
            child: const Text('Complete registration'),
          ),
        ),
      ),
    ],
  );
}

void _setPhoneSize() {
  final binding = TestWidgetsFlutterBinding.instance;
  binding.platformDispatcher.views.single.physicalSize = const Size(400, 800);
  binding.platformDispatcher.views.single.devicePixelRatio = 1.0;
  addTearDown(() {
    binding.platformDispatcher.views.single.resetPhysicalSize();
    binding.platformDispatcher.views.single.resetDevicePixelRatio();
  });
}
