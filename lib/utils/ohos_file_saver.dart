// HarmonyOS port, 2026-10-16. GPL-3.0; see LICENSE.
import 'package:flutter/services.dart';

class OhosFileSaver {
  static const _channel = MethodChannel('haka_comic/ohos_files');

  /// Returns the saved document URI, or null when the user cancels.
  static Future<String?> save({
    required String sourcePath,
    required String fileName,
  }) {
    return _channel.invokeMethod<String>('saveFilePath', {
      'sourcePath': sourcePath,
      'fileName': fileName,
    });
  }
}
