# HaKa Comic · HarmonyOS

基于 [raoxwup/haka_comic](https://github.com/raoxwup/haka_comic) 的**非官方鸿蒙原生移植**，由 [123litiany](https://github.com/123litiany) 维护。使用 Flutter OHOS 与 ArkTS 平台接口，不依赖安卓兼容环境。

> **鸿蒙预览版，尚非稳定版。** 当前验证环境是 HarmonyOS 7.0.0.107 / API 26 的 x64 模拟器。手机 arm64 包需要自行签名，尚无真机验证；不能将模拟器测试通过视作真机侧载或完整功能通过。

[下载与版本记录](https://github.com/123litiany/haka_comic_harmony/releases) · [移植进度与构建说明](HARMONYOS.md) · [侧载安装说明](INSTALL_HARMONYOS.md) · [第三方来源](third_party/UPSTREAM.md) · [反馈问题](https://github.com/123litiany/haka_comic_harmony/issues)

## 鸿蒙版进度

| 功能 | 当前验证情况 |
| --- | --- |
| 启动、登录、分类、个人页 | 模拟器实测通过；重启保留登录状态 |
| 主题与本地存储 | 模拟器实测通过 |
| SQLite、Rust ZIP | 写入重开、压缩解压内容比对通过 |
| 图片与 PDF | 自建 PNG 解码、排序和三页 PDF 结构检查通过 |
| 文档导出 | 系统保存与取消通过；大文件仍待测试 |
| ZIP/CBZ 导入与本地阅读 | 自建三页 ZIP 经系统选择器导入，阅读器显示并翻至 3/3 页；CBZ 和大文件待测 |
| 在线阅读、网络下载、WebDAV | 保留上游实现，完整流程待验证 |
| 真机、签名、侧载 | 待真机验证 |

HAP 下载入口在本仓库 **[Releases → Assets](https://github.com/123litiany/haka_comic_harmony/releases)**，与源码标签、SHA256 和变更说明配套。手机使用 **arm64** 包；**x64 仅用于模拟器**。`debug-unsigned` 是未签名调试预览包，需要按设备签名，不能直接点击安装。使用小白调试助手前请阅读[安装说明](INSTALL_HARMONYOS.md)。

本地导入：进入「我的 → 我的下载」，点击右上角导入按钮，选择包含 JPG/PNG/WebP 漫画图片的 ZIP 或 CBZ。下载内容保存在应用内，可导出 ZIP/PDF；卸载前先导出。当前鸿蒙版不提供文件夹直接导入、自定义下载目录和音量键翻页，更新通过「关于 → 检查更新」打开本仓库发布页。

### 模拟器实测

以下仅为自行生成的测试图片，不含漫画服务内容或账号信息。

| 本地 ZIP 导入 | 阅读至第三页 |
| --- | --- |
| <img src="screenshots/harmony-import.png" width="260"> | <img src="screenshots/harmony-reader.png" width="260"> |

## 开源与来源

保留上游 GPLv3 许可证、版权和历史，移植代码以同一许可证分发。引入的平台插件及其修改记录见 [third_party/UPSTREAM.md](third_party/UPSTREAM.md)。本项目不附带漫画内容、账号凭据或签名私钥。

下方保留上游介绍，其平台支持、下载地址和声明描述的是原项目；鸿蒙适配状态以上表和 `HARMONYOS.md` 为准。上游 README 中的非商业用途声明与标准 GPLv3 存在歧义，保留原文，不声称已获得额外授权或作者澄清。

---

# 上游 HaKa Comic

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg?logo=gnu)](https://opensource.org/licenses/GPL-3.0)
[![GitHub Stars](https://img.shields.io/github/stars/raoxwup/haka_comic.svg?style=flat&logo=github)](https://github.com/raoxwup/haka_comic/stargazers)

## 📖 项目简介

第三方哗咔漫画跨平台客户端。**学习 flutter 的练习项目**，支持 Android、iOS、Mac、Windows、Linux平台，目前仍在持续完善中。如果觉得项目有帮助，欢迎给个 star ⭐ 支持一下

---

## 🖼️ 项目截图

| 分类浏览                                          | 漫画列表                                              | 漫画详情                                              | 阅读界面                                          |
| ------------------------------------------------- | ----------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------- |
| <img src="./screenshots/分类.png" width="200">    | <img src="./screenshots/漫画列表.png" width="200">    | <img src="./screenshots/漫画详情.png" width="200">    | <img src="./screenshots/阅读.png" width="200">    |
| <img src="./screenshots/pc-分类.png" width="200"> | <img src="./screenshots/pc-漫画列表.png" width="200"> | <img src="./screenshots/pc-漫画详情.png" width="200"> | <img src="./screenshots/pc-阅读.png" width="200"> |

**截图已经过时，以实际项目界面为主**

---

## ⬇️ 下载

所有平台安装包都在 GitHub [Releases](https://github.com/raoxwup/haka_comic/releases)。

| 平台    | 资源类型                                        | 选择建议 / 备注                                                                                                                                                                                                                                                                |
| ------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Android | `APK`（`arm64` 推荐 / `universal` 通用 / 可选） | 大多数真机选 `arm64`；不确定就选 `universal`（体积更大）。`x86_64` 通常用于模拟器。                                                                                                                                                                                            |
| iOS     | `IPA`（未签名）                                 | 需要自签/侧载后才能安装。推荐用 SideStore/AltStore：添加源 `alt_store.json`（`https://raw.githubusercontent.com/raoxwup/haka_comic/main/alt_store.json`），并按官方文档完成前置配置（如 [SideStore 安装前置](https://docs.sidestore.io/zh/docs/installation/prerequisites)）。 |
| macOS   | `DMG`                                           | 首次打开可能需要在系统安全设置里手动允许。                                                                                                                                                                                                                                     |
| Windows | `EXE`                                           | Inno Setup 安装器，可能触发 SmartScreen 提示，按需放行。                                                                                                                                                                                                                       |
| Linux   | `DEB`（`amd64` / `arm64`）                      | Debian/Ubuntu 系：`sudo apt install ./xxx.deb`。目前仅提供 `.deb`。                                                                                                                                                                                                            |

> 提示：具体资产文件名会随版本变化，按 Release 页面展示为准。

---

## 🛠️ 开发环境

| 组件           | 版本要求                                             | 官网安装指南                                                       | 验证命令                                  |
| -------------- | ---------------------------------------------------- | ------------------------------------------------------------------ | ----------------------------------------- |
| Flutter SDK    | `3.41.2`（见 `pubspec.yaml`）                        | [Flutter 安装文档](https://docs.flutter.dev/get-started/install)   | `flutter --version` / `flutter doctor -v` |
| Dart SDK       | `>= 3.10.0 < 4.0.0`（见 `pubspec.yaml`）             | [Dart SDK 安装文档](https://dart.dev/get-dart)                     | `dart --version`                          |
| Rust toolchain | 建议使用 stable（本项目 Rust crate 为 edition 2021） | [Rust 安装文档（rustup）](https://www.rust-lang.org/tools/install) | `rustc --version` / `cargo --version`     |

> 说明：Flutter SDK 自带 Dart SDK；如果你已经安装了 Flutter，一般无需再单独安装 Dart。

---

## ⚠️ 免责声明

1. 本项目为**非官方第三方应用**，与哔咔漫画官方无任何关联
2. 仅用于**技术交流与学习**目的，禁止用于商业用途
3. 使用本软件产生的一切后果由使用者自行承担
4. 资源内容版权归原作者及平台所有，请于下载后 24 小时内删除

---
