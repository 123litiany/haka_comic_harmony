<p align="center">
  <h1 align="center"> <code>local_auth</code> </h1>
</p>

本项目基于 [local_auth@3.0.1](https://pub.dev/packages/local_auth/versions/3.0.1) 开发。

## 简介

`local_auth` 是一个用于本地身份认证的 Flutter 插件。这个 OpenHarmony 适配实现提供设备能力检测、已注册生物特征查询、身份认证和取消认证能力，并支持自定义 OHOS 侧提示文案。

## 下载安装

进入工程目录并在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  local_auth:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_packages.git
      path: packages/local_auth/local_auth
      # ref: local_auth-v3.0.1-ohos-1.0.1
      ref: TAG  #   请根据下方TAG版本对应表选择TAG
```

执行命令

```bash
flutter pub get
```

**TAG 版本对应表**

| Flutter 框架版本 | TAG1 | TAG2 | 分支 |
| :--- | :--- | :--- | :--- |
| 3.41 | `-` | `local_auth-v3.0.1-ohos-1.0.0` | `br_local_auth-v3.0.1_ohos` |
| 3.35 | `local_auth-v3.0.0-ohos-1.0.0` | `local_auth-v3.0.0-ohos-1.0.1` | `br_local_auth-v3.0.0_ohos` |
| 3.27 | `local_auth-v2.3.0-ohos-1.0.0` | `local_auth-v2.3.0-ohos-1.0.1` | `br_local_auth-v2.3.0_ohos` |
| 3.22 | `local_auth-v2.3.0-ohos-1.0.0` | `local_auth-v2.3.0-ohos-1.0.1` | `br_local_auth-v2.3.0_ohos` |
| 3.7 | `local_auth-v2.1.6-ohos-1.0.0` | `local_auth-v2.1.6-ohos-1.0.1` | `master` |

## 约束与限制

### 兼容性

在以下版本中已验证通过：

1. Flutter: 3.41.10-ohos-0.0.1; SDK: 6.1.0(23); IDE: DevEco Studio: 6.1.0.830; ROM: 6.23.0.100 SP6;

### 权限要求

本插件需要申请 `ohos.permission.ACCESS_BIOMETRIC` 权限。

打开 `entry/src/main/module.json5`，添加：

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

打开 `entry/src/main/resources/base/element/string.json`，添加：

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

## 使用示例

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
  String _status = '未认证';

  Future<void> _authenticate() async {
    final bool authenticated = await _localAuth.authenticate(
      localizedReason: '请完成身份验证',
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
      _status = authenticated ? '认证成功' : '认证失败';
    });
  }

  Future<void> _cancelAuthentication() async {
    await _localAuth.stopAuthentication();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('local_auth 示例')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_status),
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text('开始认证'),
            ),
            ElevatedButton(
              onPressed: _cancelAuthentication,
              child: const Text('取消认证'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 使用说明

`deviceSupportsBiometrics()` 用于检查设备是否具备生物识别硬件；`isDeviceSupported()` 用于检查设备是否支持本地认证流程；`getEnrolledBiometrics()` 用于获取设备上已注册的生物识别类型。

`authenticate()` 需要传入非空的 `localizedReason`，建议同时传入 `OhosAuthMessages()`。当需要仅使用生物识别时，可以将 `AuthenticationOptions.biometricOnly` 设为 `true`；如需在应用切到后台后继续保持认证状态，可以将 `stickyAuth` 设为 `true`。

`stopAuthentication()` 可用于取消当前正在进行的认证。

> `getEnrolledBiometrics()` 在 OHOS 端当前仅返回 `face` 和 `fingerprint`。`PIN` 属于认证方式配置，不会作为生物识别类型返回。

如需自定义 OHOS 侧弹窗文案，可以使用 `OhosAuthMessages`，其中 `authType` 可取 `FACE`、`FINGERPRINT` 或 `PIN`。其他字段用于自定义提示语、按钮文案和设置引导文案。

## 接口说明

## API

> [!TIP] "ohos Support"列为 yes 表示 ohos 平台支持该属性，no 则表示不支持。使用方法跨平台一致，效果对标 IOS 或 Android 的效果。

| 名称                     | 类型     | 参数类型 | 返回值                      | OHOS 平台支持 | 描述                    |
| ------------------------ | -------- | -------- | --------------------------- | ------------- | ----------------------- |
| deviceSupportsBiometrics | 方法 | 无       | Future<bool>                | yes           | 检查是否支持生物识别硬件 |
| isDeviceSupported        | 方法 | 无       | Future<bool>                | yes           | 检查是否支持本地认证     |
| getEnrolledBiometrics    | 方法 | 无       | Future<List<BiometricType>> | yes           | 获取设备上已注册的生物识别类型 |
| authenticate             | 方法 | 无       | Future<bool>                | yes           | 执行身份验证             |
| stopAuthentication       | 方法 | 无       | Future<bool>                | yes           | 取消当前认证             |

### BiometricType

| 名称        | 类型 | 参数类型 | 返回值 | OHOS 平台支持 | 描述     |
| ----------- | ---- | -------- | ------ | ------------- | -------- |
| face        | 属性 | enum       | 无     | yes           | 面容识别 |
| fingerprint | 属性 | enum       | 无     | yes           | 指纹识别 |
| weak        | 属性 | enum       | 无     | yes           | 弱生物识别 |
| strong      | 属性 | enum       | 无     | yes           | 强生物识别 |

### AuthenticationOptions

| 名称            | 类型 | 参数类型 | 返回值 | OHOS 平台支持 | 描述                         |
| --------------- | ---- | -------- | ------ | ------------- | ---------------------------- |
| biometricOnly   | 属性 | bool       | 无     | yes           | 是否仅使用生物识别           |
| useErrorDialogs | 属性 | bool       | 无     | yes           | 是否使用默认错误提示对话框   |
| stickyAuth      | 属性 | bool       | 无     | yes           | 应用退后台后是否维持认证状态 |

## 遗留问题

无

## 其他

无

## 目录结构

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

## 贡献代码

欢迎通过 GitCode 仓库提交问题反馈或改进建议。提交代码前，请先确认改动不会改变上述公开 API 的行为，并保持中文、英文文档内容一致。

## 开源协议

本项目基于 [BSD 3-Clause License](LICENSE) 开源。
