# HaKa Preview 1 双架构调试包

本文为旧 Preview 1 的补充记录。当前 1.0.1 release/AOT 包和构建方式见 [阅读更新记录](HARMONY_READER_UPDATE.md)；本脚本只接受下面固定哈希的旧 debug 包。

2026-10-30：新增 `haka-ohos-universal-debug-unsigned.hap`，同时包含
`arm64-v8a` 和 `x86_64` 的 Flutter、Rust、SQLite、SQLite pool 原生库。
目标是用同一个文件供 ARM64 鸿蒙手机签名安装和 x64 模拟器测试。
这是未签名预览包；尚无 ARM64 真机运行或真机签名安装验证。

## 复现

使用 Python 3.11 或以上，将已发布的 `v0.1.0-harmony-preview.1` 中两个
未签名单架构 HAP 放入同一目录，然后执行：

```powershell
python script/harmony-universal-preview.py <输入目录> <输出目录>/haka-ohos-universal-debug-unsigned.hap
```

脚本固定检查两个输入的已发布 SHA256，拒绝其他版本或已重新签名的包，
不能用来任意合并不同应用。应用源码对应原标签
`v0.1.0-harmony-preview.1` / `0776603a8d7fc324749c96e339766c4b5e58b871`。
原有 GPLv3、版权、第三方许可证和功能限制保持不变。

脚本以原 x64 包为基础，加入原 ARM64 库，合并两架构的 NativeAssetsManifest
及 SDK 依赖清单。检查所有共享资源相同、Ark 字节码只存在校验和与 OHPM
缓存路径差异、source map 对象相同，并校验八个库的 ELF 架构和 ZIP 完整性。
本流程只用于该 debug 版本，不能据此合并其他 release/AOT 包。

## 本次验证

- 输出 177737625 字节，SHA256：
  `14c1c8d7bccba7900969dea6bc377079c32690d9ddcbcf30eaba1c1f58794f8b`。
- 从同一输入重复打包，输出 SHA256 相同。
- HarmonyOS 7.0.0.107 / API 26 x64 模拟器覆盖安装成功，保留应用数据。
- 正常 EntryAbility 启动成功，分类首页显示；本次未重做全部功能回归。
- 手机端需按设备要求签名；模拟器接受未签名包不代表手机也可以直接安装。
- 此补充包已于 2026-10-30 上传至原 GitHub Release；服务器 SHA256 与本地一致，并附带独立校验文件和备用包说明。
