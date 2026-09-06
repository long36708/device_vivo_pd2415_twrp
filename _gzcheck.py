import gzip, os

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
vd = os.path.join(BASE, 'prebuilt', 'vendor_ramdisk')

MAGIC = b'070701'; TRAILER = b'TRAILER!!!'; PREFIX = 'lib/modules/'


def scan(data, label):
    mods = []
    i = 0
    n = len(data)
    entries = 0
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
        entries += 1
        if name.startswith(PREFIX) and name.endswith('.ko'):
            mods.append(name.rsplit('/', 1)[-1])
        i += filesize + ((-filesize) % 4)
    print('%-28s bytes=%-12d entries=%-6d lib/modules/.ko=%d'
          % (label, len(data), entries, len(mods)))
    return mods


# what prepare-ramdisk.sh actually parses on CI: gzip -dc platform.cpio.gz
with open(os.path.join(vd, 'platform.cpio.gz'), 'rb') as f:
    gz_data = gzip.decompress(f.read())
gz_mods = scan(gz_data, 'platform.cpio.gz ->')

# the loose file I based my earlier conclusion on (gitignored, absent on CI)
loose = os.path.join(vd, 'platform.cpio')
if os.path.exists(loose):
    with open(loose, 'rb') as f:
        loose_data = f.read()
    loose_mods = scan(loose_data, 'platform.cpio (loose)')
    print('\nsame bytes? %s' % (gz_data == loose_data))
    if gz_data != loose_data:
        print('!!! platform.cpio and platform.cpio.gz DO NOT MATCH')
        only_loose = sorted(set(loose_mods) - set(gz_mods))
        print('modules only in loose platform.cpio: %d' % len(only_loose))
else:
    print('\nplatform.cpio (loose) not present')

with open(os.path.join(vd, 'official_recovery.cpio.gz'), 'rb') as f:
    rec = gzip.decompress(f.read())
scan(rec, 'official_recovery.cpio.gz')
