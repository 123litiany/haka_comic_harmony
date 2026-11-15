# 鸿蒙安装与侧载

## 当前可用性

本项目尚在开发。当前 1.0.2 Preview 3 已通过 HarmonyOS 7 / API 26 x64 模拟器覆盖安装及启动验证；本版 ARM64 release 包仍需真机签名安装与注册复测。既有版本的真机反馈见各自 Release，不能替代本版验证。

发布页：[123litiany/haka_comic_harmony Releases](https://github.com/123litiany/haka_comic_harmony/releases)。预览版附件包含 HAP、SHA256 校验文件、对应源码标签和该版测试范围。不要下载上游的 APK 作为鸿蒙安装包。

## 如何选择安装包

| 文件标识 | 用途 |
| --- | --- |
| arm64 | 鸿蒙手机架构；实际兼容系统以该 Release 说明为准 |
| x64 | 仅用于电脑上的鸿蒙模拟器 |
| unsigned | 未签名，需要为自己的设备配置有效签名 |
| debug / prerelease | 调试或预览版，不是稳定发行版 |
| release | 优化后的编译模式；不代表已签名或已成为稳定发行版 |

当前手机包为 `haka-ohos-arm64-release-unsigned.hap`，约 34 MB；电脑模拟器使用 `haka-ohos-x64-release-unsigned.hap`。当前没有合并两种架构的新版通用包，旧 Preview 1 的通用调试包不含 1.0.1 新功能。

## 签名与安装流程

1. 从本仓库 Release 的 Assets 下载匹配手机架构的 HAP，核对 SHA256。
2. 按华为开发者文档注册调试设备、配置有效的调试证书和 Profile；包名是 `io.github.litiany123.haka_comic`。不要把证书、密码或设备标识提交到公开 Issue。
3. 可使用 DevEco Studio 签名与安装；使用第三方工具时，按照工具官方说明完成设备连接、签名和安装。一个人的调试签名不等于适用于所有人的安装签名。
4. 首次打开登录自己的账号。升级前备份本地数据；更换包名或签名可能无法覆盖安装，不要为升级直接卸载而丢失数据。

用户指定的[小白调试助手](https://github.com/likuai2010/auto-installer)项目说明支持 HAP、自定义证书及 HarmonyOS NEXT 版本；其鸿蒙版本需要先由其他平台安装。本项目尚未验证它在目标手机上的具体流程，不捆绑该工具、共享证书或任何绕过系统验签的材料。

参考：[华为调试 Profile 文档](https://developer.huawei.com/consumer/cn/doc/doccenter-getting-started/agc-help-debug-profile-0000002248181278)。工具、签名规则及系统兼容性可能变化，以对应版本的官方文档和实际安装结果为准。

## 报告安装问题

请提供手机型号、完整系统版本、HAP 文件名及校验值、侧载工具名称和版本、错误代码。请遮盖账号、密码、令牌、私钥和设备标识。模拟器结果、真机结果、签名错误与应用运行错误应分别记录。
