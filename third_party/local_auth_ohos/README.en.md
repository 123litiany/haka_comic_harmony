<p align="center">
  <h1 align="center"> <code>local_auth</code> </h1>
</p>

This project is developed based on [local_auth@3.0.1](https://pub.dev/packages/local_auth/versions/3.0.1).

## Introduction

`local_auth` is a Flutter plugin for local authentication. This OpenHarmony adaptation provides device capability checks, enrolled biometric queries, authentication, cancellation, and custom OHOS-side prompt messages.

## Installation

Enter the project directory and add the following dependency in `pubspec.yaml`:

```yaml
dependencies:
  local_auth:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_packages.git
      path: packages/local_auth/local_auth
      # ref: local_auth-v3.0.1-ohos-1.0.1
      ref: TAG  #   Please select the TAG according to the TAG version table below
```

Execute command:

```bash
flutter pub get
```

**TAG Version Table**

| Flutter Version | TAG1 | TAG2 | Branch |
| :--- | :--- | :--- | :--- |
| 3.41 | `-` | `local_auth-v3.0.1-ohos-1.0.0` | `br_local_auth-v3.0.1_ohos` |
| 3.35 | `local_auth-v3.0.0-ohos-1.0.0` | `local_auth-v3.0.0-ohos-1.0.1` | `br_local_auth-v3.0.0_ohos` |
| 3.27 | `local_auth-v2.3.0-ohos-1.0.0` | `local_auth-v2.3.0-ohos-1.0.1` | `br_local_auth-v2.3.0_ohos` |
| 3.22 | `local_auth-v2.3.0-ohos-1.0.0` | `local_auth-v2.3.0-ohos-1.0.1` | `br_local_auth-v2.3.0_ohos` |
| 3.7 | `local_auth-v2.1.6-ohos-1.0.0` | `local_auth-v2.1.6-ohos-1.0.1` | `master` |

## Constraints and Limitations

### Compatibility

Verified with the following versions:

1. Flutter: 3.41.10-ohos-0.0.1; SDK: 6.1.0(23); IDE: DevEco Studio: 6.1.0.830; ROM: 6.23.0.100 SP6;

### Permission Requirements

This plugin requires the `ohos.permission.ACCESS_BIOMETRIC` permission.

Open `entry/src/main/module.json5` and add the following information:

```json
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.ACCESS_BIOMETRIC",
        "reason": "$string:EntryAbility_accessBiometricReason",
        "usedScene": {
          "abilities": [
            "EntryAbility"
          ],
          "when": "inuse"
        }
      }
    ]
  }
}
```

Open `entry/src/main/resources/base/element/string.json` and add the following information:

```json
{
  "string": [
    {
      "name": "EntryAbility_accessBiometricReason",
      "value": "Verify User"
    }
  ]
}
```

## Usage Example

```dart
import 'package:flutter/material.dart';
import 'package:local_auth_ohos/local_auth_ohos.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

void main() {
  runApp(const LocalAuthDemoApp());
}

class LocalAuthDemoApp extends StatelessWidget {
  const LocalAuthDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: LocalAuthDemoPage());
  }
}

class LocalAuthDemoPage extends StatefulWidget {
  const LocalAuthDemoPage({super.key});

  @override
  State<LocalAuthDemoPage> createState() => _LocalAuthDemoPageState();
}

class _LocalAuthDemoPageState extends State<LocalAuthDemoPage> {
  final LocalAuthPlatform _localAuth = LocalAuthPlatform.instance;
  String _status = 'Not authenticated';

  Future<void> _authenticate() async {
    final bool authenticated = await _localAuth.authenticate(
      localizedReason: 'Please complete identity verification',
      authMessages: <AuthMessages>[
        const OhosAuthMessages(),
      ],
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
        sensitiveTransaction: true,
      ),
    );

    setState(() {
      _status = authenticated ? 'Authenticated' : 'Authentication failed';
    });
  }

  Future<void> _cancelAuthentication() async {
    await _localAuth.stopAuthentication();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('local_auth example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_status),
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text('Authenticate'),
            ),
            ElevatedButton(
              onPressed: _cancelAuthentication,
              child: const Text('Cancel authentication'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Usage Notes

`deviceSupportsBiometrics()` checks whether the device has biometric hardware; `isDeviceSupported()` checks whether local authentication is available; `getEnrolledBiometrics()` returns the biometric types enrolled on the device.

`authenticate()` requires a non-empty `localizedReason`, and `OhosAuthMessages()` is recommended. Set `AuthenticationOptions.biometricOnly` to `true` when you want biometrics only; set `stickyAuth` to `true` when you want the authentication state to survive app backgrounding.

`stopAuthentication()` cancels the authentication flow in progress.

> `getEnrolledBiometrics()` currently returns only `face` and `fingerprint` on OHOS. `PIN` is an authentication mode configuration and is not returned as a biometric type.

If you need to customize OHOS dialog strings, use `OhosAuthMessages`. The `authType` field can be set to `FACE`, `FINGERPRINT`, or `PIN`. The other fields customize hints, button labels, and settings guidance text.

## API Reference

### API

> [!TIP] If the value in the **OHOS Platform Support** column is **yes**, it means that the OHOS platform supports this API or property; **no** means it is not supported; The usage is consistent across platforms, and the behavior matches iOS or Android.

| Name                     | Type     | Parameter Type | Return Value                | OHOS Platform Support | Description                                      |
| ------------------------ | -------- | -------------- | --------------------------- | --------------------- | ------------------------------------------------ |
| deviceSupportsBiometrics | function | None           | Future<bool>                | yes                   | Check whether biometric hardware is supported    |
| isDeviceSupported        | function | None           | Future<bool>                | yes                   | Check whether local authentication is supported  |
| getEnrolledBiometrics    | function | None           | Future<List<BiometricType>> | yes                   | Get the biometrics enrolled on the device        |
| authenticate             | function | None           | Future<bool>                | yes                   | Perform authentication                            |
| stopAuthentication       | function | None           | Future<bool>                | yes                   | Cancel the current authentication                 |

### BiometricType

| Name        | Type  | Parameter Type | Return Value | OHOS Platform Support | Description         |
| ----------- | ----- | -------------- | ------------ | --------------------- | ------------------- |
| face        | property | enum           | None         | yes                   | Face recognition    |
| fingerprint | property | enum           | None         | yes                   | Fingerprint recognition |
| weak        | property | enum           | None         | yes                   | Weak biometric      |
| strong      | property | enum           | None         | yes                   | Strong biometric    |

### AuthenticationOptions

| Name            | Type      | Parameter Type | Return Value | OHOS Platform Support | Description                                           |
| --------------- | --------- | -------------- | ------------ | --------------------- | ----------------------------------------------------- |
| biometricOnly   | property  | bool           | None         | yes                   | Whether to use biometrics only                        |
| useErrorDialogs | property  | bool           | None         | yes                   | Whether to use the default error dialog boxes         |
| stickyAuth      | property  | bool           | None         | yes                   | Whether to maintain the auth state after the app is backgrounded |

## Known Issues

None

## Others

None

## Directory Structure

```text
local_auth_ohos/
├─ lib/
│  ├─ local_auth_ohos.dart
│  └─ types/
│     ├─ auth_messages_ohos.dart
│     └─ ohos_auth_error_code.dart
├─ ohos/
│  ├─ index.ets
│  └─ src/main/ets/io/flutter/plugins/localauth/
├─ example/
│  ├─ lib/main.dart
│  └─ ohos/
├─ test/
│  └─ local_auth_test.dart
├─ README_CN.md
├─ README.md
└─ pubspec.yaml
```

## Contributing

Contributions, bug reports, and improvement suggestions are welcome through the GitCode repository. Before submitting code, please make sure the change does not alter the behavior of the public APIs above and keeps the Chinese and English documentation in sync.

## License

This project is licensed under [BSD 3-Clause License](LICENSE).
