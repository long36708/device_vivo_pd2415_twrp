import gzip, os, collections

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
MAGIC = b'070701'; TRAILER = b'TRAILER!!!'

def scan(data, label):
    tops = collections.Counter()
    ko_any = []
    mods_dirs = collections.Counter()
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
        if '/' in name:
            tops[name.split('/', 1)[0]] += 1
        if name.endswith('.ko'):
            ko_any.append(name)
            mods_dirs[os.path.dirname(name)] += 1
        i += filesize + ((-filesize) % 4)
    print('=== %s ===' % label)
    print('  top-level: %s' % dict(tops.most_common(12)))
    print('  *.ko anywhere: %d' % len(ko_any))
    if ko_any:
        print('  ko dirs: %s' % dict(mods_dirs.most_common(5)))
    return ko_any

gz = gzip.decompress(open(os.path.join(BASE, 'prebuilt', 'vendor_ramdisk', 'platform.cpio.gz'), 'rb').read())
scan(gz, 'platform.cpio.gz (what prepare-ramdisk.sh parses)')

rec = gzip.decompress(open(os.path.join(BASE, 'prebuilt', 'vendor_ramdisk', 'official_recovery.cpio.gz'), 'rb').read())
scan(rec, 'official_recovery.cpio.gz (official RECOVERY ramdisk)')
