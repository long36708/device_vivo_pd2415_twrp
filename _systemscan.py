import gzip, os, collections

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
MAGIC = b'070701'; TRAILER = b'TRAILER!!!'

data = gzip.decompress(open(os.path.join(BASE, 'prebuilt', 'vendor_ramdisk', 'platform.cpio.gz'), 'rb').read())

lvl2 = collections.Counter()
exts = collections.Counter()
samples = collections.defaultdict(list)
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
    if name.startswith('system/') and filesize:
        parts = name.split('/')
        key = '/'.join(parts[:3]) if len(parts) > 2 else '/'.join(parts[:2])
        lvl2[key] += filesize
        ext = os.path.splitext(name)[1] or '(noext)'
        exts[ext] += filesize
        if len(samples[key]) < 3:
            samples[key].append((name, filesize))
    i += filesize + ((-filesize) % 4)

print('=== system/ by 2nd level (raw, top 20) ===')
tot = sum(lvl2.values())
for k, s in lvl2.most_common(20):
    print('  %-42s %8.1f MiB  (%4.1f%%)' % (k, s / 1048576.0, 100.0 * s / tot))
print('\nsystem/ total: %.1f MiB' % (tot / 1048576.0))

print('\n=== system/ by extension (top 12) ===')
for e, s in exts.most_common(12):
    print('  %-14s %8.1f MiB' % (e, s / 1048576.0))

print('\n=== samples from the largest dirs ===')
for k, s in lvl2.most_common(5):
    print(' [%s]' % k)
    for nm, sz in samples[k]:
        print('     %-70s %8.1f KiB' % (nm, sz / 1024.0))
