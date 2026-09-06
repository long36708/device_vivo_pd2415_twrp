import os, sys, lz4.frame

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'

def lz_size_of_bytes(data):
    return len(lz4.frame.compress(data, compression_level=12))

def lz_size_of_file(path):
    with open(path, 'rb') as f:
        return lz_size_of_bytes(f.read())

# 1) platform fragment: compress the whole platform.cpio (mirrors lz4 of the
#    stock platform ramdisk in package-vendor-boot.sh).
platform_cpio = os.path.join(BASE, 'prebuilt', 'vendor_ramdisk', 'platform.cpio')
platform_lz = lz_size_of_file(platform_cpio)
print('platform.cpio (lz4 L12): %d bytes (%.1f MiB)' % (platform_lz, platform_lz/1048576.0))

# 2) recovery fragment modules: the essential allowlist.
mod_dir = os.path.join(BASE, 'prebuilt', 'recovery_modules')
allowlist = os.path.join(mod_dir, 'essential_modules.txt')
with open(allowlist, 'r', encoding='utf-8') as f:
    names = [ln.strip() for ln in f if ln.strip() and '/*' not in ln]
mod_lz = 0
for n in names:
    p = os.path.join(mod_dir, n)
    if os.path.isfile(p):
        mod_lz += lz_size_of_file(p)
print('recovery modules (lz4 L12, %d files): %d bytes (%.1f MiB)' % (len(names), mod_lz, mod_lz/1048576.0))

# 3) recovery fragment HAL: whole recovery_vendor_hal tree.
hal_dir = os.path.join(BASE, 'prebuilt', 'recovery_vendor_hal')
hal_lz = 0
hal_count = 0
for root, _dirs, files in os.walk(hal_dir):
    for fn in files:
        hal_lz += lz_size_of_file(os.path.join(root, fn))
        hal_count += 1
print('recovery HAL (lz4 L12, %d files): %d bytes (%.1f MiB)' % (hal_count, hal_lz, hal_lz/1048576.0))

# 4) firmware (gt9897 filter -> currently empty here)
fw_dir = os.path.join(BASE, 'prebuilt', 'recovery_firmware')
fw_lz = 0
fw_count = 0
for fn in os.listdir(fw_dir):
    if 'gt9897' in fn:
        fw_lz += lz_size_of_file(os.path.join(fw_dir, fn))
        fw_count += 1
print('recovery firmware gt9897 (lz4 L12, %d files): %d bytes (%.1f MiB)' % (fw_count, fw_lz, fw_lz/1048576.0))

KERNEL = 36379136
DTB = 540239
recovery_payload_lz = mod_lz + hal_lz + fw_lz
print('---')
print('kernel (raw):        %.1f MiB' % (KERNEL/1048576.0))
print('dtb (raw):           %.1f MiB' % (DTB/1048576.0))
print('platform (lz4):      %.1f MiB' % (platform_lz/1048576.0))
print('recovery payload(lz4, mod+hal+fw): %.1f MiB' % (recovery_payload_lz/1048576.0))
# NOTE: recovery_payload here excludes the TWRP recovery binary + libs (built by
# AOSP, not present locally); add ~10-25 MiB for a realistic total.
total_no_twrp = KERNEL + DTB + platform_lz + recovery_payload_lz
print('pre-AVB (excl. TWRP rest): %.1f MiB  (die line 128, stock warn 115.2)' % (total_no_twrp/1048576.0))
