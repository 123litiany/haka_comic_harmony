// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

import 'types/auth_messages_ohos.dart';
import 'types/ohos_auth_error_code.dart';

export 'package:local_auth_ohos/types/auth_messages_ohos.dart';
export 'package:local_auth_platform_interface/types/auth_messages.dart';
export 'package:local_auth_platform_interface/types/auth_options.dart';
export 'package:local_auth_platform_interface/types/biometric_type.dart';

const MethodChannel _channel =
    MethodChannel('plugins.flutter.io/local_auth_ohos');

/// The implementation of [LocalAuthPlatform] for Ohos.
class LocalAuthOhos extends LocalAuthPlatform {
  /// Registers this class as the default instance of [LocalAuthPlatform].
  static void registerWith() {
    LocalAuthPlatform.instance = LocalAuthOhos();
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    assert(localizedReason.isNotEmpty);
    final Map<String, Object> args = <String, Object>{
      'localizedReason': localizedReason,
      'stickyAuth': options.stickyAuth,
      'sensitiveTransaction': options.sensitiveTransaction,
      'biometricOnly': options.biometricOnly,
    };
    args.addAll(const OhosAuthMessages().args);
    for (final AuthMessages messages in authMessages) {
      if (messages is OhosAuthMessages) {
        args.addAll(messages.args);
      }
    }

    try {
      return (await _channel.invokeMethod<bool>('authenticate', args)) ?? false;
    } on PlatformException catch (e) {
      throw _mapPlatformExceptionToLocalAuthException(e);
    }
  }

  @override
  Future<bool> deviceSupportsBiometrics() async {
    return (await _channel.invokeMethod<bool>('deviceSupportsBiometrics')) ??
        false;
  }

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async {
    final List<String> result = (await _channel.invokeListMethod<String>(
          'getEnrolledBiometrics',
        )) ??
        <String>[];
    final List<BiometricType> biometrics = <BiometricType>[];
    for (final String value in result) {
      switch (value) {
        case 'face':
          biometrics.add(BiometricType.face);
          break;
        case 'fingerprint':
          biometrics.add(BiometricType.fingerprint);
          break;
      }
    }
    return biometrics;
  }

  @override
  Future<bool> isDeviceSupported() async =>
      (await _channel.invokeMethod<bool>('isDeviceSupported')) ?? false;

  @override
  Future<bool> stopAuthentication() async =>
      await _channel.invokeMethod<bool>('stopAuthentication') ?? false;

  /// Maps OHOS error codes to LocalAuthException
  LocalAuthException _mapPlatformExceptionToLocalAuthException(PlatformException e) {
    switch (e.code) {
      case OhosAuthErrorCode.canceled:
        return const LocalAuthException(code: LocalAuthExceptionCode.userCanceled);
      case OhosAuthErrorCode.timeout:
        return const LocalAuthException(code: LocalAuthExceptionCode.timeout);
      case OhosAuthErrorCode.generalError:
        return LocalAuthException(
          code: LocalAuthExceptionCode.unknownError,
          description: e.message,
        );
      case OhosAuthErrorCode.typeNotSupport:
        return const LocalAuthException(code: LocalAuthExceptionCode.noBiometricHardware);
      case OhosAuthErrorCode.trustLevelNotSupport:
        return const LocalAuthException(code: LocalAuthExceptionCode.noBiometricHardware);
      case OhosAuthErrorCode.busy:
        return const LocalAuthException(code: LocalAuthExceptionCode.authInProgress);
      case OhosAuthErrorCode.locked:
        return const LocalAuthException(code: LocalAuthExceptionCode.temporaryLockout);
      case OhosAuthErrorCode.notEnrolled:
        return const LocalAuthException(code: LocalAuthExceptionCode.noBiometricsEnrolled);
      case OhosAuthErrorCode.canceledFromWidget:
        return const LocalAuthException(code: LocalAuthExceptionCode.userCanceled);
      case OhosAuthErrorCode.authInProgress:
        return const LocalAuthException(code: LocalAuthExceptionCode.authInProgress);
      case OhosAuthErrorCode.noAbility:
        return const LocalAuthException(
          code: LocalAuthExceptionCode.uiUnavailable,
          description: 'No Ability available',
        );
      case OhosAuthErrorCode.notAvailable:
        return const LocalAuthException(
          code: LocalAuthExceptionCode.noBiometricHardware,
          description: 'Required security features not enabled',
        );
      default:
        return LocalAuthException(
          code: LocalAuthExceptionCode.unknownError,
          description: e.message ?? 'Unknown error: ${e.code}',
        );
    }
  }
}
