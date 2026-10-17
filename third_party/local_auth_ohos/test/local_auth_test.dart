// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_ohos/local_auth_ohos.dart';
import 'package:local_auth_ohos/types/ohos_auth_error_code.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

const MethodChannel _channel = MethodChannel(
  'plugins.flutter.io/local_auth_ohos',
);

class _UnsupportedAuthMessages extends AuthMessages {
  const _UnsupportedAuthMessages();

  @override
  Map<String, String> get args => <String, String>{'ignored': 'ignored'};
}

void _setMockHandler(Future<dynamic> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

void _clearMockHandler() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalAuthOhos plugin;

  setUp(() {
    plugin = LocalAuthOhos();
    _clearMockHandler();
    addTearDown(_clearMockHandler);
  });

  test('registers instance', () {
    final LocalAuthPlatform original = LocalAuthPlatform.instance;
    addTearDown(() => LocalAuthPlatform.instance = original);

    LocalAuthOhos.registerWith();

    expect(LocalAuthPlatform.instance, isA<LocalAuthOhos>());
  });

  group('deviceSupportsBiometrics', () {
    test('returns true', () async {
      _setMockHandler((MethodCall call) async {
        expect(call.method, 'deviceSupportsBiometrics');
        return true;
      });

      expect(await plugin.deviceSupportsBiometrics(), isTrue);
    });

    test('returns false when the channel returns null', () async {
      _setMockHandler((MethodCall call) async {
        expect(call.method, 'deviceSupportsBiometrics');
        return null;
      });

      expect(await plugin.deviceSupportsBiometrics(), isFalse);
    });
  });

  group('isDeviceSupported', () {
    test('returns true', () async {
      _setMockHandler((MethodCall call) async {
        expect(call.method, 'isDeviceSupported');
        return true;
      });

      expect(await plugin.isDeviceSupported(), isTrue);
    });

    test('returns false', () async {
      _setMockHandler((MethodCall call) async {
        expect(call.method, 'isDeviceSupported');
        return false;
      });

      expect(await plugin.isDeviceSupported(), isFalse);
    });
  });

  group('stopAuthentication', () {
    test('returns true', () async {
      _setMockHandler((MethodCall call) async {
        expect(call.method, 'stopAuthentication');
        return true;
      });

      expect(await plugin.stopAuthentication(), isTrue);
    });

    test('returns false', () async {
      _setMockHandler((MethodCall call) async {
        expect(call.method, 'stopAuthentication');
        return false;
      });

      expect(await plugin.stopAuthentication(), isFalse);
    });
  });

  group('getEnrolledBiometrics', () {
    test('maps known values and ignores unknown values', () async {
      _setMockHandler((MethodCall call) async {
        expect(call.method, 'getEnrolledBiometrics');
        return <String>['face', 'fingerprint', 'unknown'];
      });

      expect(await plugin.getEnrolledBiometrics(), <BiometricType>[
        BiometricType.face,
        BiometricType.fingerprint,
      ]);
    });

    test('returns an empty list when the channel returns null', () async {
      _setMockHandler((MethodCall call) async {
        expect(call.method, 'getEnrolledBiometrics');
        return null;
      });

      expect(await plugin.getEnrolledBiometrics(), isEmpty);
    });
  });

  group('authenticate', () {
    Future<Map<dynamic, dynamic>> captureAuthenticateArguments({
      required Iterable<AuthMessages> authMessages,
      AuthenticationOptions options = const AuthenticationOptions(),
      String localizedReason = 'reason',
    }) async {
      final List<MethodCall> calls = <MethodCall>[];
      _setMockHandler((MethodCall call) async {
        calls.add(call);
        return true;
      });

      expect(
        await plugin.authenticate(
          localizedReason: localizedReason,
          authMessages: authMessages,
          options: options,
        ),
        isTrue,
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'authenticate');
      return calls.single.arguments as Map<dynamic, dynamic>;
    }

    Future<void> expectAuthenticateException({
      required String code,
      String? message,
      required LocalAuthExceptionCode expectedCode,
      String? expectedDescription,
    }) async {
      _setMockHandler((MethodCall call) async {
        expect(call.method, 'authenticate');
        throw PlatformException(code: code, message: message);
      });

      await expectLater(
        plugin.authenticate(
          localizedReason: 'reason',
          authMessages: <AuthMessages>[],
        ),
        throwsA(
          isA<LocalAuthException>()
              .having((LocalAuthException e) => e.code, 'code', expectedCode)
              .having(
                (LocalAuthException e) => e.description,
                'description',
                expectedDescription,
              ),
        ),
      );
    }

    test('passes default Ohos values when no messages are provided', () async {
      final Map<dynamic, dynamic> args = await captureAuthenticateArguments(
        authMessages: <AuthMessages>[],
      );

      expect(args['localizedReason'], 'reason');
      expect(args['stickyAuth'], isFalse);
      expect(args['sensitiveTransaction'], isTrue);
      expect(args['biometricOnly'], isFalse);
      expect(args['biometricHint'], ohosBiometricHint);
      expect(args['biometricNotRecognized'], ohosBiometricNotRecognized);
      expect(args['biometricSuccess'], ohosBiometricSuccess);
      expect(args['biometricRequired'], ohosBiometricRequiredTitle);
      expect(args['cancelButton'], ohosCancelButton);
      expect(
        args['deviceCredentialsRequired'],
        ohosDeviceCredentialsRequiredTitle,
      );
      expect(
        args['deviceCredentialsSetupDescription'],
        ohosDeviceCredentialsSetupDescription,
      );
      expect(args['goToSetting'], goToSettings);
      expect(args['goToSettingDescription'], ohosGoToSettingsDescription);
      expect(args['signInTitle'], ohosSignInTitle);
      expect(args['authType'], '');
    });

    test(
      'passes provided Ohos values and ignores unsupported messages',
      () async {
        final Map<dynamic, dynamic> args = await captureAuthenticateArguments(
          localizedReason: 'custom reason',
          authMessages: <AuthMessages>[
            const OhosAuthMessages(
              biometricHint: 'Hint',
              cancelButton: 'Cancel',
              signInTitle: 'Sign in',
              authType: 'FACE',
            ),
            const _UnsupportedAuthMessages(),
          ],
          options: const AuthenticationOptions(
            biometricOnly: true,
            sensitiveTransaction: false,
            stickyAuth: true,
          ),
        );

        expect(args['localizedReason'], 'custom reason');
        expect(args['biometricHint'], 'Hint');
        expect(args['cancelButton'], 'Cancel');
        expect(args['signInTitle'], 'Sign in');
        expect(args['authType'], 'FACE');
        expect(args['biometricSuccess'], ohosBiometricSuccess);
        expect(args['stickyAuth'], isTrue);
        expect(args['sensitiveTransaction'], isFalse);
        expect(args['biometricOnly'], isTrue);
        expect(args.containsKey('ignored'), isFalse);
      },
    );

    test('returns false when the channel returns false', () async {
      _setMockHandler((MethodCall call) async {
        expect(call.method, 'authenticate');
        return false;
      });

      expect(
        await plugin.authenticate(
          localizedReason: 'reason',
          authMessages: <AuthMessages>[],
        ),
        isFalse,
      );
    });

    test('maps canceled to userCanceled', () async {
      await expectAuthenticateException(
        code: OhosAuthErrorCode.canceled,
        expectedCode: LocalAuthExceptionCode.userCanceled,
      );
    });

    test('maps canceledFromWidget to userCanceled', () async {
      await expectAuthenticateException(
        code: OhosAuthErrorCode.canceledFromWidget,
        expectedCode: LocalAuthExceptionCode.userCanceled,
      );
    });

    test('maps timeout to timeout', () async {
      await expectAuthenticateException(
        code: OhosAuthErrorCode.timeout,
        expectedCode: LocalAuthExceptionCode.timeout,
      );
    });

    test(
      'maps generalError to unknownError with the platform message',
      () async {
        await expectAuthenticateException(
          code: OhosAuthErrorCode.generalError,
          message: 'boom',
          expectedCode: LocalAuthExceptionCode.unknownError,
          expectedDescription: 'boom',
        );
      },
    );

    test('maps typeNotSupport to noBiometricHardware', () async {
      await expectAuthenticateException(
        code: OhosAuthErrorCode.typeNotSupport,
        expectedCode: LocalAuthExceptionCode.noBiometricHardware,
      );
    });

    test('maps trustLevelNotSupport to noBiometricHardware', () async {
      await expectAuthenticateException(
        code: OhosAuthErrorCode.trustLevelNotSupport,
        expectedCode: LocalAuthExceptionCode.noBiometricHardware,
      );
    });

    test('maps busy to authInProgress', () async {
      await expectAuthenticateException(
        code: OhosAuthErrorCode.busy,
        expectedCode: LocalAuthExceptionCode.authInProgress,
      );
    });

    test('maps locked to temporaryLockout', () async {
      await expectAuthenticateException(
        code: OhosAuthErrorCode.locked,
        expectedCode: LocalAuthExceptionCode.temporaryLockout,
      );
    });

    test('maps notEnrolled to noBiometricsEnrolled', () async {
      await expectAuthenticateException(
        code: OhosAuthErrorCode.notEnrolled,
        expectedCode: LocalAuthExceptionCode.noBiometricsEnrolled,
      );
    });

    test('maps authInProgress to authInProgress', () async {
      await expectAuthenticateException(
        code: OhosAuthErrorCode.authInProgress,
        expectedCode: LocalAuthExceptionCode.authInProgress,
      );
    });

    test('maps noAbility to uiUnavailable', () async {
      await expectAuthenticateException(
        code: OhosAuthErrorCode.noAbility,
        expectedCode: LocalAuthExceptionCode.uiUnavailable,
        expectedDescription: 'No Ability available',
      );
    });

    test('maps notAvailable to noBiometricHardware', () async {
      await expectAuthenticateException(
        code: OhosAuthErrorCode.notAvailable,
        expectedCode: LocalAuthExceptionCode.noBiometricHardware,
        expectedDescription: 'Required security features not enabled',
      );
    });

    test('maps unknown errors to unknownError', () async {
      await expectAuthenticateException(
        code: 'unexpected',
        expectedCode: LocalAuthExceptionCode.unknownError,
        expectedDescription: 'Unknown error: unexpected',
      );
    });
  });
}
