import subprocess, os

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
target = os.path.join(BASE, 'BoardConfig.mk')

# Pull the committed blob straight out of git (HEAD was clean before the EOL
# scripts mangled the worktree copy) and force pure LF on the way back in.
proc = subprocess.run(['git', 'show', 'HEAD:device_vivo_pd2415_twrp/BoardConfig.mk'],
                      cwd=r'f:/learn-front/learn-hook/vivo-twrp', capture_output=True)
if proc.returncode != 0:
    # fall back to a path relative to the repo root of this device tree
    proc = subprocess.run(['git', 'show', 'HEAD:BoardConfig.mk'],
                          cwd=BASE, capture_output=True)
if proc.returncode != 0:
    raise SystemExit('git show failed: ' + proc.stderr.decode('utf-8', 'replace'))

data = proc.stdout.replace(b'\r\n', b'\n')
if not data:
    raise SystemExit('git blob is empty - refusing to write')

with open(target, 'wb') as f:
    f.write(data)

check = open(target, 'rb').read()
print('restored: %d bytes, %d lines, CR count=%d'
      % (len(check), check.count(b'\n'), check.count(b'\r')))
print('first line : ' + check.split(b'\n', 1)[0].decode('utf-8', 'replace'))
print('line 2     : ' + check.split(b'\n', 2)[1].decode('utf-8', 'replace'))
