import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haka_comic/config/setup_config.dart';
import 'package:haka_comic/network/api_exception.dart';
import 'package:haka_comic/network/models.dart';
import 'package:haka_comic/views/login/register.dart';

void main() {
  testWidgets(
    'form trims names, keeps the password, and blocks repeated submit',
    (tester) async {
      final pending = Completer<void>();
      final requests = <RegisterPayload>[];
      await _open(tester, (payload) {
        requests.add(payload);
        return pending.future;
      });
      await _fill(tester);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      button.onPressed!();
      button.onPressed!();
      expect(requests, hasLength(1));
      expect(requests.single.name, '我的测试昵称');
      expect(requests.single.email, 'testAccount');
      expect(requests.single.password, ' password123 ');
      expect(requests.single.birthday, matches(RegExp(r'^\d{4}-01-01$')));
      pending.completeError(
        const ApiException(message: 'name is already exist'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('昵称已存在，请修改上方'), findsOneWidget);
      expect(find.byType(Register), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('random generation changes only the chosen field', (
    tester,
  ) async {
    await _open(tester, (_) async {});
    await _fill(tester);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    await tester.tap(find.byTooltip('生成随机昵称'));
    expect(fields[0].controller!.text, matches(RegExp(r'^[a-z]{16}$')));
    expect(fields[1].controller!.text, ' testAccount ');
    await tester.tap(find.byTooltip('生成随机登录账号'));
    expect(fields[1].controller!.text, matches(RegExp(r'^[a-z]{16}$')));
    expect(fields[2].controller!.text, ' password123 ');
  });

  testWidgets('success returns to login', (tester) async {
    final pending = Completer<void>();
    await _open(tester, (_) => pending.future);
    await _fill(tester);
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Login page'), findsOneWidget);
    expect(find.byType(Register), findsNothing);
  });

  testWidgets('a late error after leaving is harmless', (tester) async {
    final lateError = Completer<void>();
    final secondRouter = await _open(tester, (_) => lateError.future);
    await _fill(tester);
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
    secondRouter.pop();
    await tester.pumpAndSettle();
    lateError.completeError(
      const ApiException(message: 'name is already exist'),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Login page'), findsOneWidget);
  });
}

Future<GoRouter> _open(
  WidgetTester tester,
  Future<void> Function(RegisterPayload) request,
) async {
  tester.view.physicalSize = const Size(480, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    navigatorKey: navigatorKey,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Login page')),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => Register(registerRequest: request),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
    ),
  );
  unawaited(router.push('/register'));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _fill(WidgetTester tester) async {
  final fields = find.byType(TextField);
  for (final (index, text) in [
    ' 我的测试昵称 ',
    ' testAccount ',
    ' password123 ',
    ' password123 ',
  ].indexed) {
    await tester.enterText(fields.at(index), text);
  }
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.pump();
}
