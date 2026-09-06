import subprocess, os

BASE = r'f:/learn-front/learn-hook/vivo-twrp/device_vivo_pd2415_twrp'
rel = 'recovery/prepare-ramdisk.sh'
target = os.path.join(BASE, rel)

# What line endings does the committed copy use? That is the house style.
blob = subprocess.run(['git', 'show', 'HEAD:' + rel], cwd=BASE,
                      capture_output=True).stdout
print('HEAD version : bytes=%d LF=%d CR=%d' % (len(blob), blob.count(b'\n'), blob.count(b'\r')))

cur = open(target, 'rb').read()
print('worktree now : bytes=%d LF=%d CR=%d' % (len(cur), cur.count(b'\n'), cur.count(b'\r')))

if cur.count(b'\r') == 0:
    print('already LF - nothing to do')
else:
    fixed = cur.replace(b'\r\n', b'\n')
    with open(target, 'wb') as f:
        f.write(fixed)
    check = open(target, 'rb').read()
    print('fixed to LF : bytes=%d LF=%d CR=%d' % (len(check), check.count(b'\n'), check.count(b'\r')))
    # the shebang must not carry a stray CR
    print('shebang repr: %r' % check.split(b'\n', 1)[0])
