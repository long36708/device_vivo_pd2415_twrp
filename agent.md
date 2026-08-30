# Agent 协作规则 (agent.md)

本文件记录本设备树开发中的硬性约定，AI 助手在修改相关文件时必须遵守。

## 修改 prebuilt 输入后必须同步更新哈希常量

`package-vendor-boot.sh` 在组装最终 `vendor_boot` 镜像时，会用 `require_sha256`
对以下输入文件逐项做哈希校验，任一项不符即报 `hash mismatch` 并以退出码 1 失败（CI 因此中断）：

| 文件 | 脚本中的常量 | 校验层级 |
|------|--------------|----------|
| `prebuilt/vendor_ramdisk/platform.cpio.gz` | `PLATFORM_GZIP_SHA256` | `.gz` 文件本身 |
| （同上，解压后） | `PLATFORM_CPIO_SHA256` | `gunzip` 后的 cpio 内容 |
| `prebuilt/vendor_ramdisk/official_recovery.cpio.gz` | `OFFICIAL_RECOVERY_CPIO_SHA256` | `.gz` 文件本身 |
| `prebuilt/dtb/pd2415.dtb` | `DTB_SHA256` | 文件本身 |

### 规则

1. 任何对上述文件的增删改（重新生成、替换、压缩方式变化等），**必须同步更新**
   `package-vendor-boot.sh` 顶部对应的 SHA256 常量。
2. **gzip 级哈希与 cpio 内容级哈希是两套独立常量**：重新生成 `.gz` 时，即使内层
   cpio 内容字节完全相同，gzip 外层元数据（时间戳/头）不同也会导致 gzip 级哈希变化。
   因此 `PLATFORM_GZIP_SHA256` 和 `PLATFORM_CPIO_SHA256` 都可能需要改，不能只改一个。
3. 正确哈希值用 `sha256sum` 或 python 从**实际文件**算出后回填，严禁凭记忆或沿用旧值。

### 血的教训

- 提交 `f21c0a3b` ("fix: use full official platform ramdisk to stop boot hang at logo")
  把 `platform.cpio.gz` 从 51788770 字节换成 52196154 字节（改用完整 ramdisk.1、停止
  trim），但只更新了 `PLATFORM_CPIO_SHA256`，漏了 `PLATFORM_GZIP_SHA256`，导致 CI
  报 `hash mismatch: .../platform.cpio.gz`。
- 已修复于提交 `65d70a0`（ASCII message 规避 Windows 工具调用层 GBK 双重编码乱码）。
