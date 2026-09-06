import os, re

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
fw = os.path.join(BASE, 'prebuilt', 'recovery_firmware')
mods = os.path.join(BASE, 'prebuilt', 'recovery_modules')

files = sorted(f for f in os.listdir(fw) if os.path.isfile(os.path.join(fw, f)))
print('=== recovery_firmware: %d files ===' % len(files))
for f in files:
    print('  %-58s %8.1f KB' % (f, os.path.getsize(os.path.join(fw, f))/1024.0))

# firmware names requested by the touch driver
ts = os.path.join(mods, 'vivo_ts.ko')
if os.path.isfile(ts):
    blob = open(ts, 'rb').read()
    txt = blob.decode('latin-1')
    cands = set()
    for pat in (r'gt9\d{3}[A-Za-z0-9_.\-]*', r'gt8\d{3}[A-Za-z0-9_.\-]*',
                r'TP-[A-Z0-9\-]{2,}', r'[A-Za-z0-9_\-]*\.ftb',
                r'[A-Za-z0-9_\-]*\.bin', r'novatek[A-Za-z0-9_\-]*',
                r'nt36[A-Za-z0-9_\-]*'):
        for m in re.findall(pat, txt):
            if 3 < len(m) < 64:
                cands.add(m)
    print('\n=== possible firmware names referenced by vivo_ts.ko (%d) ===' % len(cands))
    for c in sorted(cands):
        print('   ' + c)
else:
    print('\nvivo_ts.ko not found at ' + ts)
