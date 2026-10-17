// HarmonyOS port, 2026-10-17. GPL-3.0; see LICENSE.
import 'package:flutter/services.dart';
import 'package:haka_comic/utils/native_folder_picker.dart';

class OhosFolderPicker {
  static const _channel = MethodChannel('haka_comic/ohos_files');

  static Future<bool> isSupported() async =>
      await _channel.invokeMethod<bool>('supportsFolderSelection') ?? false;

  static Future<PickedFolderSnapshot?> pickSnapshot() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'pickFolderSnapshot',
    );
    return result == null ? null : PickedFolderSnapshot.fromMap(result);
  }
}
