import os

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
cpio = os.path.join(BASE, 'prebuilt', 'vendor_ramdisk', 'platform.cpio')
MAGIC = b'070701'; TRAILER = b'TRAILER!!!'; PREFIX = 'lib/modules/'

plat_mods = set()
plat_so = set()
ta_files = []          # mcRegistry / trustlets
plat_vendor_bins = []
with open(cpio, 'rb') as f:
    while True:
        hdr = f.read(110)
        if len(hdr) != 110 or hdr[0:6] != MAGIC:
            break
        filesize = int(hdr[54:62], 16)
        namesize = int(hdr[94:102], 16)
        name = f.read(namesize).rstrip(b'\0').decode('utf-8', 'surrogateescape')
        f.seek((-(110 + namesize)) % 4, os.SEEK_CUR)
        if name == TRAILER:
            break
        if name.startswith(PREFIX) and name.endswith('.ko'):
            plat_mods.add(name.rsplit('/', 1)[-1])
        if name.startswith('vendor/lib64/') and name.endswith('.so'):
            plat_so.add(name.rsplit('/', 1)[-1])
        if name.startswith('vendor/bin/hw/'):
            plat_vendor_bins.append(name.rsplit('/', 1)[-1])
        if any(name.endswith(e) for e in ('.tlbin', '.drbin', '.tabin', '.mclib')):
            ta_files.append((name, filesize))
        f.seek(filesize + ((-filesize) % 4), os.SEEK_CUR)

allow = os.path.join(BASE, 'prebuilt', 'recovery_modules', 'essential_modules.txt')
with open(allow, 'r', encoding='utf-8') as fh:
    allowlist = [ln.strip() for ln in fh if ln.strip()]

inplat = [m for m in allowlist if m in plat_mods]
notin  = [m for m in allowlist if m not in plat_mods]
print('platform ships %d .ko under lib/modules/' % len(plat_mods))
print('allowlist entries: %d' % len(allowlist))
print('  SKIPPED (already in platform): %d   -> these cost 0 bytes in the recovery fragment' % len(inplat))
print('  WOULD STAGE (missing from platform): %d' % len(notin))
for m in notin:
    print('     + ' + m)
print('platform vendor/lib64 .so: %d' % len(plat_so))
print('platform vendor/bin/hw: %s' % plat_vendor_bins)
print('platform trustlets (tlbin/drbin/tabin): %d files, %.1f MiB'
      % (len(ta_files), sum(s for _n, s in ta_files)/1048576.0))
for n, s in ta_files[:10]:
    print('     %s  (%.1f KB)' % (n, s/1024.0))
