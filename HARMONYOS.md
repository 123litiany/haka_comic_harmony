# HarmonyOS 移植工作区

维护目标账号：[123litiany](https://github.com/123litiany)。本分支是独立的非官方移植工作，不代表上游或漫画平台。

上游：[raoxwup/haka_comic](https://github.com/raoxwup/haka_comic)

基线提交：`fad9333b626ae7fadd22af7d5cde6b980c3a8f2b`。

## 当前状态

2026-10-17：已在 HarmonyOS 7 模拟器通过登录、本地 ZIP 导入与阅读、离线原生功能实测。完整功能、真机和分发签名仍未验证；不可把本分支标为完整鸿蒙移植版。

- DevEco Studio 26.0.0.851，SDK API 26。
- 工具链候选：CPF-Flutter/flutter_flutter，标签 `3.44.9+ohos-0.0.1-canary1`，提交 `39285df71a97ffe0c23241dcc459d997a9d8b7c6`。这是测试标签，不是稳定版。
- 工程配置要求 Flutter >=3.44.8、Dart >=3.12.0；上游 README 的较旧版本说明不作为此次构建依据。
- 使用相邻的 `harmony_smoke` 工程隔离验证环境，不将验证工程称为 HaKa 移植结果。

## Windows 环境

Hvigor 实测拒绝中文项目路径。实际构建工作区为 `D:\HarmonyDev`，原 `D:\鸿蒙` 文件保留。其他开发者可使用任意符合工具要求的英文路径。

先将所需 Flutter SDK 放在项目同级的 `flutter-ohos` 中，或设置 `FLUTTER_OHOS_ROOT`。设置 `DEVECO_ROOT` 可覆盖 DevEco 路径。

```powershell
. .\script\harmony-env.ps1
flutter --version
```

脚本仅改变当前进程的环境变量，不改写系统设置。缓存位于项目父目录，不提交到仓库。

原生库需要 Rust 的 `aarch64-unknown-linux-ohos` 和 `x86_64-unknown-linux-ohos` targets。本地验证使用 Rust 1.99.1（Windows GNU host），`cargo` 和 `rustup` 目录位于项目父目录。首次联网执行 `flutter pub get` 下载依赖，然后运行：

```powershell
# 手机架构；x64 为模拟器架构
.\script\harmony-build.ps1 -Architecture arm64
.\script\harmony-build.ps1 -Architecture x64
```

脚本清理旧架构的生成文件，编译 SQLite、连接池和 HaKa Rust 模块，再打包并核对 HAP 中的库。结果是未签名 debug 预览包，不是稳定发行版。Flutter 可能因未配置签名返回非零状态；脚本会明确报告，并独立检查生成的压缩包。不要仅凭存在 HAP 就判断移植成功。

### 已完成的验证

- arm64 和 x64 的三个原生库均已交叉编译，动态依赖检查未发现 `libc.so.6` 或 `ld-linux`。
- 应用、测试及生物认证插件 Dart 静态检查：无 error/warning，22 条 info（现有命名风格和 print）。
- `flutter test --no-pub test/network test/router test/utils`：9 项通过。这些测试不代表鸿蒙原生功能通过。
- 新增 `ohos_file_picker_contract_test.dart`：3 项通过，覆盖 v11 文件保存参数、取消/错误结果及图片元数据；使用模拟通道，不代表系统文件选择界面已通过实测。
- HarmonyOS 7.0.0 / API 26 模拟器 `HaKa_HarmonyOS7` 已成功启动（系统版本 7.0.0.107，x86_64）。设置 hypervisor 开机加载并再次重启后生效。调试连接为 `127.0.0.1:5555`；未签名 HAP 已被该模拟器接受安装，这不代表真实手机支持同样的安装方式。
- 首次启动发现 FRB 2.12 的默认加载器不识别 `ohos`；现改为在鸿蒙显式打开 `librust_lib_haka_comic.so`，第二次运行已越过该故障。
- 第二次启动发现数据库 native-assets 索引未打包。`script/harmony-toolchain.ps1` 修补固定 canary 的 `OhosAssetBundle`，按 Android 同类构建步骤加入 `NativeAssetsManifest.json`，并重新生成 Flutter 工具缓存。构建脚本会自动调用此修补；其他版本需重新核对。
- 修补后在模拟器实测 `integration_test/harmony_runtime_smoke.dart`：应用初始化、SharedPreferences 写入/重新加载、sqlite_async 写入/关闭/重开读取、Rust ZIP 压缩/解压内容比对均 PASS。该测试使用自建临时数据，不依赖漫画服务账号，结束后清理测试文件。
- 2026-10-17：重新构建普通 `lib/main.dart` 入口，x64 包通过原生库和 native-assets 索引检查，模拟器安装后显示正常登录页，未出现上游 APK 更新提示。包 SHA256 为 `72E79D77EB25E7606FDB81829C56F2AB5DB3613F019E045432F313C5123706BE`。这是未签名调试包，不能当作面向手机用户的正式发行包；登录后的功能尚待账号验证。
- 同日由用户自行登录后，分类和个人页接口返回数据，设置页正常显示。选择 Dark 后强制停止并重开应用，登录态和主题均保留；随后恢复 System 主题。此项不代表在线阅读、下载或所有账号功能已经通过测试。
- 同日扩展离线测试并在模拟器实测通过：Flutter 生成三张 120×180 PNG，按 `page1/page2/page10` 自然排序，解码尺寸正确；Rust 生成三页 PDF，通过 PDF 文件头、结尾与 `/Count 3` 检查。尚未进行 PDF 渲染比对、大文件压力测试或完整阅读界面测试。测试结束自动删除自身临时数据，再覆盖安装普通应用包，保留用户登录数据。

离线实测构建命令（测试入口不能作为发行包）：

```powershell
flutter build hap --debug --target-platform ohos-x64 --no-pub --target integration_test/harmony_runtime_smoke.dart
# 验证后必须切回正常应用入口
flutter build hap --debug --target-platform ohos-x64 --no-pub --target lib/main.dart
```

## 待验证的主要依赖

| 模块 | 待办 |
| --- | --- |
| Flutter 引擎 | 完整应用已在 x64 模拟器安装并显示登录页；arm64 真机待测 |
| SQLite | 模拟器已验证 sqlite_async 数据库写入/重开；完整下载事务及真机待测 |
| Rust | 模拟器已验证动态库加载、ZIP 往返、三页 PDF 导出结构；PDF 渲染、大文件、WebDAV 完整流程及真机待测 |
| 设置和存储 | 模拟器已验证 shared_preferences 持久化调用及 path_provider 临时目录；目录授权另需适配 |
| 文件操作 | 原生文档保存成功/取消已在模拟器验证；内容比对、图片选择、目录授权、持久访问和本地文件夹导入待验证或适配 |
| 设备功能 | local_auth 鸿蒙实现已通过编译，待运行验证；权限、音量键、刷新率、动态图标仍待适配 |
| 发布更新 | 关于页可打开本移植仓库 Releases；自动检查更新暂不提供 |

不得用空实现冒充功能适配成功，尤其是认证、持久化和文件保存。

当前鸿蒙导出通过应用内 `HarmonyFilePlugin` 打开系统文档保存窗口，以原生文件描述符复制临时 ZIP/PDF，避免把完整漫画文件载入 Dart 和通道消息。每次处理一个文件，取消后停止后续保存，并清理本次独立临时目录。2026-10-16 在模拟器保存测试文本返回 PASS，取消返回 CANCELED；尚未读取目标文件比对内容，也未验证大漫画的内存峰值及完整 PDF 导出。文件夹选择器返回的授权 URI 还不能直接交给 Dart Directory 使用。

鸿蒙测试版已暂停上游 APK 更新提示；关于页的检查更新按钮现打开本移植仓库的 Releases；自动更新暂不提供。应用锁改为仅在系统验证成功时解锁，开启前先验证设备能力；新增 4 项回归测试通过，原生身份验证仍需实测。

`harmony-artifacts/` 保留按架构命名的调试包；每次改代码后必须重新生成对应架构。旧包即使仍在该目录，也不代表包含最新修改。尚无签名包或公开 Release。

## 发布要求

保留上游 LICENSE、版权和声明；衍生代码按 GPLv3 分发。每个二进制 Release 应关联对应源码标签、构建步骤和依赖信息，明确未通过测试或不支持的功能。逐项核查依赖许可证。

上游 README 的“禁止商业用途”与标准 GPLv3 存在许可歧义，保留原文并公开说明，不能默默删除或声称已获得作者澄清。源码许可不授予漫画内容、平台服务或商标的权利。

不要提交签名私钥、个人证书、账号凭据及本地构建产物。

## 修改记录

- 2026-10-15：加入鸿蒙环境脚本及移植状态说明；尚未修改原应用功能。
- 2026-10-16：加入鸿蒙工程、四个鸿蒙平台插件、SQLite/连接池原生 hook 适配、双架构原生编译及包结构检查脚本；保留上游许可证，依赖来源与修改见 `third_party/UPSTREAM.md`。尚未向 GitHub 发布。

## 2026-10-17 预览版补充验证

- 最终 Dart 静态检查没有 error/warning，23 条 info；网络、路由、工具回归测试共 16 项通过。
- 正常应用入口实测：通过系统保存窗口写入自建三页 ZIP，再在「我的下载」中选择该 ZIP，成功导入 3/3 张图片；进入阅读器，图片正常显示，连续滚动至 3/3 和「本章完」。截图见 README。此流程覆盖 ZIP 导出文件的可读性、系统文件选择、解压、下载存储与本地阅读，不代表在线漫画下载通过。
- 文件夹能力检测在此模拟器返回支持，但系统窗口无法确认文件夹。公开预览版使用 ZIP/CBZ 文件导入；实验性文件夹桥接保留供后续验证，不用于正常应用流程。
- 鸿蒙下载使用应用内部存储，暂不提供自定义路径；音量键翻页明确禁用，支持触屏阅读。WebDAV、在线阅读和下载、大文件、原生认证与 arm64 真机仍待完整实测。
- HAP 使用正常 `lib/main.dart` 入口，不发布离线测试入口。HAP 应用版本为 1.0.0，沿用上游界面版本 1.2.7；首个移植标签为 `v0.1.0-harmony-preview.1`。预览版不具备自动更新。

源码与依赖许可保留在本仓库；修改清单见 `MODIFICATIONS_HARMONYOS.md`。公开 HAP 不包含用户运行时登录数据、漫画缓存或签名材料。