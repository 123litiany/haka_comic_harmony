import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haka_comic/utils/device_authentication.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

class _AuthPlatform extends LocalAuthPlatform {
  bool supported = true;
  bool accepted = false;
  bool failSupportCheck = false;
  bool failChallenge = false;
  int challenges = 0;

  @override
  Future<bool> isDeviceSupported() async {
    if (failSupportCheck) throw MissingPluginException('Test missing backend');
    return supported;
  }

  @override
  Future<bool> authenticate({required String localizedReason,
      required Iterable<AuthMessages> authMessages,
      AuthenticationOptions options = const AuthenticationOptions()}) async {
    challenges++;
    if (failChallenge) throw PlatformException(code: 'locked');
    return accepted;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalAuthPlatform previous;
  late _AuthPlatform platform;
  setUp(() {
    previous = LocalAuthPlatform.instance;
    platform = _AuthPlatform();
    LocalAuthPlatform.instance = platform;
  });
  tearDown(() => LocalAuthPlatform.instance = previous);

  test('an unsupported device never unlocks or starts a challenge', () async {
    platform.supported = false;
    expect(await authenticateDeviceAccess(), isFalse);
    expect(platform.challenges, 0);
  });
  test('missing platform support fails closed', () async {
    platform.failSupportCheck = true;
    expect(await authenticateDeviceAccess(), isFalse);
  });
  test('a failed or canceled challenge never unlocks', () async {
    expect(await authenticateDeviceAccess(), isFalse);
    platform.failChallenge = true;
    expect(await authenticateDeviceAccess(), isFalse);
  });
  test('a successful system challenge unlocks', () async {
    platform.accepted = true;
    expect(await authenticateDeviceAccess(), isTrue);
    expect(platform.challenges, 1);
  });
}
