import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haka_comic/utils/ohos_reader.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/harmony_reader');
  late OhosReaderBridge bridge;

  setUp(() => bridge = OhosReaderBridge(channel: channel));
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<bool> configure(bool active) => bridge.configure(
    active: active,
    volumeKeys: true,
    keepScreenOn: true,
    brightness: -1,
  );

  test(
    'an exit waits for an in-flight activation and is the final state',
    () async {
      final activation = Completer<bool>();
      final calls = <bool>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        final active = (call.arguments as Map)['active'] as bool;
        calls.add(active);
        return active ? activation.future : false;
      });
      final enter = configure(true);
      final exit = configure(false);
      await Future<void>.delayed(Duration.zero);
      expect(calls, [true]);
      activation.complete(true);
      expect(await enter, isTrue);
      expect(await exit, isFalse);
      expect(calls, [true, false]);
    },
  );

  test('a native failure does not block a later cleanup request', () async {
    var count = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (++count == 1) throw PlatformException(code: 'no_window');
      return false;
    });
    expect(await configure(true), isFalse);
    expect(await configure(false), isFalse);
    expect(count, 2);
  });
}
