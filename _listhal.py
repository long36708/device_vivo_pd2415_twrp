import os

hal = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp/prebuilt/recovery_vendor_hal'
for sub in ('bin', 'lib64', 'mcRegistry'):
    p = os.path.join(hal, sub)
    if not os.path.isdir(p):
        continue
    tot = 0; cnt = 0
    for root, _d, files in os.walk(p):
        for fn in files:
            tot += os.path.getsize(os.path.join(root, fn)); cnt += 1
    print('%s: %d files, %.1f MiB' % (sub, cnt, tot/1048576.0))
    if sub == 'bin':
        for root, _d, files in os.walk(p):
            for fn in files:
                fp = os.path.join(root, fn)
                print('    %s  %.1f KB' % (fn, os.path.getsize(fp)/1024.0))
