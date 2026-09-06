import os, fnmatch, lz4.frame

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
fw = os.path.join(BASE, 'prebuilt', 'recovery_firmware')

def lz(data):
    return len(lz4.frame.compress(data, compression_level=12))

# exactly what prepare-ramdisk.sh globs: TP-*-PD2415-* and TP-*-PD2419-*
staged = []
for f in sorted(os.listdir(fw)):
    p = os.path.join(fw, f)
    if not os.path.isfile(p):
        continue
    for proj in ('PD2415', 'PD2419'):
        if fnmatch.fnmatch(f, 'TP-*-' + proj + '-*'):
            staged.append(p)
            break

raw = sum(os.path.getsize(p) for p in staged)
lz4tot = sum(lz(open(p, 'rb').read()) for p in staged)
print('staged touch firmware: %d blobs, raw %.2f MiB, lz4 %.2f MiB'
      % (len(staged), raw/1048576.0, lz4tot/1048576.0))
for p in staged:
    print('   %-56s %7.1f KB' % (os.path.basename(p), os.path.getsize(p)/1024.0))

# measured earlier
platform_lz = 59970404
hal_lz      = 18378751
mod_lz      = 0        # every allowlist .ko is already in platform -> skipped
KERNEL      = 36379136
DTB         = 540239

pre = platform_lz + hal_lz + mod_lz + lz4tot + KERNEL + DTB
print('\n=== pre-AVB budget (lz4 fragments) ===')
print('  platform fragment        %6.1f MiB' % (platform_lz/1048576.0))
print('  recovery: modules        %6.1f MiB  (all 337 shipped by platform)' % (mod_lz/1048576.0))
print('  recovery: touch firmware %6.1f MiB' % (lz4tot/1048576.0))
print('  recovery: HAL+mcRegistry %6.1f MiB' % (hal_lz/1048576.0))
print('  kernel                   %6.1f MiB' % (KERNEL/1048576.0))
print('  dtb                      %6.1f MiB' % (DTB/1048576.0))
print('  ----------------------------------')
print('  subtotal (excl. TWRP)    %6.1f MiB' % (pre/1048576.0))
print('  headroom to 128 MiB die  %6.1f MiB' % ((134217728 - pre)/1048576.0))
print('  headroom to 115.2 warn   %6.1f MiB' % ((120795136 - pre)/1048576.0))
