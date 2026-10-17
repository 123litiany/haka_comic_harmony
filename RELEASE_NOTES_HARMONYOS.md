# HaKa HarmonyOS 0.1.0 Preview 1

首个鸿蒙原生移植预览版，基于上游 HaKa 1.2.7。**这是未签名调试包，不是稳定版；尚无真机侧载验证。**

## 下载与安装

- 手机下载 `haka-ohos-arm64-debug-unsigned.hap`。
- 电脑鸿蒙模拟器下载 `haka-ohos-x64-debug-unsigned.hap`。
- 校验值见 `SHA256SUMS.txt`。源码对应标签 `v0.1.0-harmony-preview.1`，可从下方 Source code 下载。
- 安装前阅读 [侧载说明](https://github.com/123litiany/haka_comic_harmony/blob/v0.1.0-harmony-preview.1/INSTALL_HARMONYOS.md)。未签名 HAP 需要按自己的设备配置有效签名。小白调试助手的真机流程尚待验证，不能保证直接下载后即可安装。

目标验证环境是 HarmonyOS 7.0.0.107 / API 26 x64 模拟器。工程最低版本声明为 5.1 / API 18，但未验证旧版本兼容性。手机 arm64 包只完成构建和包结构检查。

## 已验证

- 模拟器启动、用户自行登录、分类与个人页显示、重启保留登录与主题。
- SQLite 写入重开、设置存储、Rust ZIP 压缩解压、图片自然排序及解码、三页 PDF 结构检查。
- 原生系统文档保存及取消；自建三页 ZIP 保存后从系统文件选择器导入，阅读器显示图片并翻至 3/3 页。
- 16 项回归测试通过；Dart 静态检查无 error/warning。

## 当前限制

- 在线阅读、网络下载、WebDAV、大文件导入导出、原生认证及 arm64 真机尚未完成完整验证。
- 文件导入接受 ZIP/CBZ；实测 ZIP，CBZ 待测。暂不提供文件夹直接导入、自定义下载目录或音量键翻页。
- 下载内容保存在应用内部，卸载前请导出；使用同一签名覆盖升级并提前备份。
- 「关于 → 检查更新」打开本仓库发布页；暂不自动更新。

保留上游 GPLv3、版权和来源声明；第三方许可证及变更见 [修改说明](https://github.com/123litiany/haka_comic_harmony/blob/v0.1.0-harmony-preview.1/MODIFICATIONS_HARMONYOS.md)。本发行物不包含账号、漫画内容、证书或私钥。
