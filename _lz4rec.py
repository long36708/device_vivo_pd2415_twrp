import os, lz4.frame

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
rec = os.path.join(BASE, 'prebuilt', 'vendor_ramdisk', 'official_recovery.cpio')

data = open(rec, 'rb').read()
print('official_recovery.cpio raw: %.1f MiB' % (len(data)/1048576.0))
print('official_recovery.cpio lz4 L12: %.1f MiB' % (len(lz4.frame.compress(data, compression_level=12))/1048576.0))

# parse newc, tally lib/modules
MAGIC = b'070701'; TRAILER = b'TRAILER!!!'; PREFIX = b'lib/modules/'
mod_bytes = 0; mod_count = 0
i = 0; n = len(data)
while i + 110 <= n:
    hdr = data[i:i+110]
    if hdr[0:6] != MAGIC:
        break
    filesize = int(hdr[54:62], 16)
    namesize = int(hdr[94:102], 16)
    name = data[i+110:i+110+namesize].rstrip(b'\0').decode('utf-8','surrogateescape')
    i += 110 + namesize + ((-(110+namesize)) % 4)
    if name == 'TRAILER!!!':
        break
    if name.startswith('lib/modules/') and name.endswith('.ko'):
        mod_bytes += filesize; mod_count += 1
    i += filesize + ((-filesize) % 4)
print('official_recovery lib/modules: %d .ko, %.1f MiB raw' % (mod_count, mod_bytes/1048576.0))
