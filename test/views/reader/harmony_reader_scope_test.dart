import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haka_comic/config/app_config.dart';
import 'package:haka_comic/router/route_observer.dart';
import 'package:haka_comic/utils/ohos_reader.dart';
import 'package:haka_comic/utils/shared_preferences_util.dart';
import 'package:haka_comic/views/reader/widgets/harmony_reader_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/harmony_scope');
  late OhosReaderBridge bridge;
  late List<Map<dynamic, dynamic>> calls;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    SharedPreferencesUtil.prefsWithCache =
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(),
        );
    AppConf().enableVolume = true;
    AppConf().readerKeepScreenOn = true;
    AppConf().readerBrightness = 0.4;
    bridge = OhosReaderBridge(channel: channel);
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.arguments as Map);
      return true;
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> key(String direction) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('volumeKey', direction),
      ),
      (_) {},
    );
  }

  testWidgets('keys and window controls follow route and app visibility', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    var previous = 0;
    var next = 0;
    final activity = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [routeObserver],
        home: HarmonyReaderScope(
          bridge: bridge,
          onPrevious: () => previous++,
          onNext: () => next++,
          onActivityChanged: activity.add,
          child: const Scaffold(body: Text('Reader')),
        ),
      ),
    );
    await tester.pump();
    expect(calls.last['active'], isTrue);
    expect(calls.last['brightness'], 0.4);
    await key('up');
    await key('down');
    expect([previous, next], [1, 1]);

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Settings')),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls.last['active'], isFalse);
    await key('down');
    expect(next, 1);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(calls.last['active'], isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(calls.last['active'], isFalse);
    await key('down');
    expect(next, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await key('down');
    expect(next, 2);

    AppConf().enableVolume = false;
    OhosReaderBridge.refreshPreferences();
    await tester.pump();
    expect(calls.last['volumeKeys'], isFalse);
    await key('down');
    expect(next, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(calls.last['active'], isFalse);
    expect(activity, containsAllInOrder([true, false, true, false, true]));
  });
}
