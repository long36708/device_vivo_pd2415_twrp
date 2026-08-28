"""pd2415 recovery_firmware 精准清理脚本

只保留 recovery 需要的触觉驱动固件 + 触摸屏固件，
删除振动马达波形 / 相机 / 蓝牙 / WiFi / 充电等无关固件。

Usage: python clean_firmware.py
"""
import os
import sys

FW_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "prebuilt", "recovery_firmware",
)

KEEP_PATTERNS = [
    # 触摸屏固件
    "TP-FW-",
    "TP-CONFIG-FW-",
    "TP-THPCFG-FW-",
    "TP-VENDORCFG-FW-",
    "gt9895_",
    "gt9896s_",
    "gt9916",
    "gt9764",
    "touch_firmwares.bin",
    "st_fts_",
    # 触觉驱动固件
    "cs40l26-",
    "vivo_ram_haptic",  # vivo 触觉 RAM 固件（驱动需要）
    "aw8",
    "tfa98xx",
]

# 按扩展名白名单（.ftb/.wmfw 等触摸/触觉专用格式直接保留）
KEEP_EXTS = {".ftb", ".wmfw"}


def should_keep(name: str) -> bool:
    lower = name.lower()
    ext = os.path.splitext(lower)[1]
    if ext in KEEP_EXTS:
        return True
    for pat in KEEP_PATTERNS:
        if lower.startswith(pat.lower()):
            return True
    return False


def main():
    if not os.path.isdir(FW_DIR):
        print(f"[!] 目录不存在: {FW_DIR}")
        sys.exit(1)

    all_files = [
        f for f in os.listdir(FW_DIR)
        if os.path.isfile(os.path.join(FW_DIR, f))
    ]
    total_size = sum(
        os.path.getsize(os.path.join(FW_DIR, f)) for f in all_files
    )
    print(f"总文件数: {len(all_files)}")
    print(f"总体积:   {total_size / 1024 / 1024:.1f} MB")

    keep_files = []
    delete_files = []
    for f in all_files:
        if should_keep(f):
            keep_files.append(f)
        else:
            delete_files.append(f)

    keep_size = sum(
        os.path.getsize(os.path.join(FW_DIR, f)) for f in keep_files
    )
    delete_size = sum(
        os.path.getsize(os.path.join(FW_DIR, f)) for f in delete_files
    )
    print(f"\n保留: {len(keep_files)} 文件, {keep_size / 1024 / 1024:.1f} MB")
    print(f"删除: {len(delete_files)} 文件, {delete_size / 1024 / 1024:.1f} MB")

    print("\n保留文件列表:")
    for f in sorted(keep_files):
        size = os.path.getsize(os.path.join(FW_DIR, f))
        print(f"  {f:<60} {size / 1024:>8.1f} KB")

    print(f"\n[*] 删除 {len(delete_files)} 个无关固件 ...")
    for f in delete_files:
        os.remove(os.path.join(FW_DIR, f))
    print(f"[+] 完成。保留 {len(keep_files)} 个文件。")

    final_files = [
        f for f in os.listdir(FW_DIR)
        if os.path.isfile(os.path.join(FW_DIR, f))
    ]
    final_size = sum(
        os.path.getsize(os.path.join(FW_DIR, f)) for f in final_files
    )
    print(f"\n=== 最终结果 ===")
    print(f"文件数: {len(final_files)}")
    print(f"体积:   {final_size / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
