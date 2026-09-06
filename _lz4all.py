import os, glob, lz4.frame

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
mod_dir = os.path.join(BASE, 'prebuilt', 'recovery_modules')

def lz(b):
    return len(lz4.frame.compress(b, compression_level=12))

total = 0
count = 0
raw = 0
for p in sorted(glob.glob(os.path.join(mod_dir, '*.ko'))):
    d = open(p, 'rb').read()
    raw += len(d)
    total += lz(d)
    count += 1
print('ALL %d modules: raw %.1f MiB, lz4 %.1f MiB' % (count, raw / 1048576.0, total / 1048576.0))

# platform fragment as CI actually builds it: lz4 of platform.cpio.gz contents
import gzip
plat = gzip.decompress(open(os.path.join(BASE, 'prebuilt', 'vendor_ramdisk', 'platform.cpio.gz'), 'rb').read())
plat_lz = lz(plat)
print('platform fragment (lz4 of platform.cpio.gz): %.1f MiB' % (plat_lz / 1048576.0))

KERNEL = 36379136
DTB = 540239
HAL = 18378751
FW = 2035000  # 34 TP blobs staged, measured earlier as 1.94 MiB
pre = plat_lz + KERNEL + DTB + total + HAL + FW
print('')
print('=== pre-AVB with ALL 337 modules (excl. TWRP own files) ===')
print('  platform   %6.1f' % (plat_lz / 1048576.0))
print('  kernel     %6.1f' % (KERNEL / 1048576.0))
print('  dtb        %6.1f' % (DTB / 1048576.0))
print('  modules    %6.1f  (%d ko)' % (total / 1048576.0, count))
print('  HAL        %6.1f' % (HAL / 1048576.0))
print('  firmware   %6.1f' % (FW / 1048576.0))
print('  subtotal   %6.1f MiB' % (pre / 1048576.0))
print('  headroom to 128 MiB die line: %6.1f MiB' % ((134217728 - pre) / 1048576.0))
