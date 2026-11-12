import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:haka_comic/utils/log.dart';

/// Window-scoped HarmonyOS reader controls. Calls are serialized so a delayed
/// activation cannot overtake an exit/background request.
class OhosReaderBridge {
  OhosReaderBridge({
    this.channel = const MethodChannel('haka_comic/ohos_reader'),
  }) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeKey' &&
          (call.arguments == 'up' || call.arguments == 'down')) {
        _keys.add(call.arguments as String);
      }
    });
  }

  static final instance = OhosReaderBridge();
  static final preferencesRevision = ValueNotifier(0);

  static void refreshPreferences() => preferencesRevision.value++;

  final MethodChannel channel;
  final _keys = StreamController<String>.broadcast(sync: true);
  Future<void>? _pending;

  Stream<String> get volumeKeys => _keys.stream;

  Future<bool> configure({
    required bool active,
    required bool volumeKeys,
    required bool keepScreenOn,
    required double brightness,
  }) {
    final result = Completer<bool>();
    _pending = (_pending ?? Future<void>.value()).then((_) async {
      try {
        final listening = await channel.invokeMethod<bool>('configure', {
          'active': active,
          'volumeKeys': volumeKeys,
          'keepScreenOn': keepScreenOn,
          'brightness': brightness,
        });
        result.complete(listening ?? false);
      } catch (error, stackTrace) {
        Log.e(
          'HarmonyOS reader controls',
          error: error,
          stackTrace: stackTrace,
        );
        result.complete(false);
      }
    });
    return result.future;
  }
}
