# HarmonyOS 修改与许可说明

维护者：123litiany。修改日期：2026-10-15 至 2026-10-17。

本仓库由 raoxwup/haka_comic 的 `fad9333b626ae7fadd22af7d5cde6b980c3a8f2b` 派生；保留其 Git 历史、LICENSE、版权和 README 声明。HaKa 的衍生代码继续按 GPLv3 分发。第三方代码保留各自许可证，不因纳入此仓库而被重新授权。

## 本次修改

- 新增 `ohos/` 原生工程和文档保存桥接；文件夹桥接为实验代码，正常应用使用 ZIP 文件导入。
- `pubspec.yaml`、锁文件及 `.metadata` 注册鸿蒙插件和本地依赖；新增 `third_party/` 对应源代码及原始许可证，精确来源和修改见 `third_party/UPSTREAM.md`。
- `lib/startup_prepare.dart` 显式加载鸿蒙 Rust 动态库；`lib/utils/common.dart` 新增平台识别。
- `lib/utils/comic_exporter.dart` 使用原生文件复制保存 ZIP/PDF，处理取消与临时目录清理；新增文件保存桥接 Dart 接口。
- `lib/views/download/local_comic_importer.dart` 与 `downloads_ui.dart` 增加鸿蒙 ZIP/CBZ 导入。
- `lib/main.dart`、`lib/views/settings/auth.dart` 与认证工具修复未通过系统验证时仍解锁的问题；新增回归测试。
- `lib/network/http.dart`、`lib/main.dart` 和 `lib/views/about/about.dart` 停用上游 APK 更新提示，提供本移植仓库及 HAP 发布页入口。
- 设置页明确鸿蒙内部下载存储及尚不支持的音量键翻页。
- 新增 `script/harmony-*.ps1` 构建脚本、离线设备测试入口、安装文档、测试截图和本说明；`.gitignore` 排除构建缓存及私有签名材料。

## 对应源码和构建

每个 Release 标签对应该版源码；GitHub 自动提供 Source code 下载。构建步骤见 `HARMONYOS.md`，Dart 和 Rust 依赖版本分别固定在 `pubspec.lock`、`rust/Cargo.lock` 及 vendored package 锁文件中。

Flutter OHOS 工具链来源：[CPF-Flutter/flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter)，标签 `3.44.9+ohos-0.0.1-canary1`，提交 `39285df71a97ffe0c23241dcc459d997a9d8b7c6`。本项目对打包流程的必要修补完整包含于 `script/harmony-toolchain.ps1`。原生库由仓库内 SQLite、连接池 Rust 和应用 Rust 源码编译；第三方版本、来源与许可见 `third_party/UPSTREAM.md`。

安装包中的 Flutter `NOTICES.Z` 保存构建工具生成的依赖许可文本。系统 SDK 和工具链需从各自官方渠道获取。许可证不授予漫画内容、账号、商标或服务访问权。

上游 README 含非商业用途表述，与标准 GPLv3 有歧义。本仓库保留原文，不声称已取得额外授权或作者澄清。
