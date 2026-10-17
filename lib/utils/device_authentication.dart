// HarmonyOS port, 2026-10-16. GPL-3.0; see LICENSE.
import 'package:local_auth/local_auth.dart';
import 'package:haka_comic/utils/log.dart';

/// Only a successful system challenge grants access. Missing hardware or a
/// platform/plugin error must never unlock an application with its lock enabled.
Future<bool> authenticateDeviceAccess() async {
  try {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return false;
    return await auth.authenticate(localizedReason: '请验证身份以访问应用');
  } catch (error, stackTrace) {
    Log.w('Device authentication failed', error: error, stackTrace: stackTrace);
    return false;
  }
}
