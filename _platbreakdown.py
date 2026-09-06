import gzip, os, collections, lz4.frame

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
MAGIC = b'070701'; TRAILER = b'TRAILER!!!'

data = gzip.decompress(open(os.path.join(BASE, 'prebuilt', 'vendor_ramdisk', 'platform.cpio.gz'), 'rb').read())
print('platform.cpio.gz decompressed: %.1f MiB' % (len(data) / 1048576.0))

sizes = collections.Counter()
i, n = 0, len(data)
while i + 110 <= n:
    hdr = data[i:i + 110]
    if hdr[0:6] != MAGIC:
        break
    filesize = int(hdr[54:62], 16)
    namesize = int(hdr[94:102], 16)
    name = data[i + 110:i + 110 + namesize].rstrip(b'\0').decode('utf-8', 'surrogateescape')
    i += 110 + namesize + ((-(110 + namesize)) % 4)
    if name == TRAILER:
        break
    top = name.split('/', 1)[0] if '/' in name else name
    sizes[top] += filesize
    i += filesize + ((-filesize) % 4)

print('\nplatform fragment content by top-level dir (raw):')
tot = sum(sizes.values())
for d, s in sizes.most_common():
    print('  %-24s %8.1f MiB  (%4.1f%%)' % (d, s / 1048576.0, 100.0 * s / tot))

# how much would dropping the stock recovery UI resources save?
drop = sizes['recovery_resources'] + sizes['res']
print('\nrecovery_resources + res (stock recovery UI, redundant next to TWRP twres): %.1f MiB raw' % (drop / 1048576.0))
