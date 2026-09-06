import os, collections

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
cpio = os.path.join(BASE, 'prebuilt', 'vendor_ramdisk', 'platform.cpio')

MAGIC = b'070701'; TRAILER = b'TRAILER!!!'
tops = collections.Counter()
vendor_bytes = 0; vendor_files = 0
ko_count = 0; ko_bytes = 0
so_count = 0; so_bytes = 0
hwbin = []
firmware_bytes = 0; firmware_files = 0
total_files = 0; total_bytes = 0

with open(cpio, 'rb') as f:
    while True:
        hdr = f.read(110)
        if len(hdr) != 110 or hdr[0:6] != MAGIC:
            break
        filesize = int(hdr[54:62], 16)
        namesize = int(hdr[94:102], 16)
        name = f.read(namesize).rstrip(b'\0').decode('utf-8', 'surrogateescape')
        f.seek((-(110 + namesize)) % 4, os.SEEK_CUR)
        if name == 'TRAILER!!!':
            break
        total_files += 1; total_bytes += filesize
        if '/' in name:
            tops[name.split('/', 1)[0]] += 1
        if name.startswith('vendor/') or name == 'vendor':
            vendor_bytes += filesize
            if filesize:
                vendor_files += 1
        if name.endswith('.ko'):
            ko_count += 1; ko_bytes += filesize
        if name.endswith('.so'):
            so_count += 1; so_bytes += filesize
        if name.startswith('vendor/bin/hw/') and filesize:
            hwbin.append(name.rsplit('/', 1)[-1])
        if '/firmware/' in name and filesize:
            firmware_bytes += filesize; firmware_files += 1
        f.seek(filesize + ((-filesize) % 4), os.SEEK_CUR)

print('platform.cpio: %d files, %.1f MiB total' % (total_files, total_bytes/1048576.0))
print('top-level dirs (file counts):')
for d, c in tops.most_common(30):
    print('   %-24s %d' % (d, c))
print('vendor/ subtree: %d files, %.1f MiB' % (vendor_files, vendor_bytes/1048576.0))
print('.ko: %d files, %.1f MiB' % (ko_count, ko_bytes/1048576.0))
print('.so: %d files, %.1f MiB' % (so_count, so_bytes/1048576.0))
print('firmware: %d files, %.1f MiB' % (firmware_files, firmware_bytes/1048576.0))
print('vendor/bin/hw entries (%d):' % len(hwbin))
for h in sorted(hwbin)[:40]:
    print('   ' + h)
