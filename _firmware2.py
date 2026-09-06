import os, collections, re

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
fw = os.path.join(BASE, 'prebuilt', 'recovery_firmware')
files = sorted(f for f in os.listdir(fw) if os.path.isfile(os.path.join(fw, f)))
sizes = {f: os.path.getsize(os.path.join(fw, f)) for f in files}

groups = collections.OrderedDict()
def bucket(name):
    m = re.match(r'(TP-[A-Z]+)-FW-(PD\d+)-', name)
    if m:
        return '%s %s' % (m.group(1), m.group(2))
    if name.startswith('gt9895'):  return 'gt9895'
    if name.startswith('gt9896'):  return 'gt9896s'
    if name.startswith('gt9897'):  return 'gt9897'
    if 'novatek' in name.lower():  return 'novatek'
    if 'st_fts' in name.lower():   return 'st_fts'
    if 's6smc41' in name.lower():  return 's6smc41'
    if name.endswith('.wmfw'):     return 'wmfw (audio dsp)'
    if 'cs40l26' in name.lower() or 'aw8' in name.lower() or 'tfa98xx' in name.lower():
                                   return 'haptic'
    if 'vivo_ram_haptic' in name.lower(): return 'haptic ram'
    return 'other'

for f in files:
    groups.setdefault(bucket(f), []).append(f)

print('=== recovery_firmware grouped (%d files, %.1f MiB total) ==='
      % (len(files), sum(sizes.values())/1048576.0))
for g in sorted(groups):
    tot = sum(sizes[f] for f in groups[g])
    print('%-28s %3d files  %7.2f MiB' % (g, len(groups[g]), tot/1048576.0))
    if g == 'other':
        for f in groups[g]:
            print('      ' + f)
    if g in ('novatek', 'st_fts', 's6smc41', 'gt9897', 'gt9895', 'gt9896s'):
        for f in groups[g]:
            print('      %-46s %7.1f KB' % (f, sizes[f]/1024.0))
