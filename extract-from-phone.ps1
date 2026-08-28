# pd2415 prebuilt extraction script (rooted device, Windows PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File extract-from-phone.ps1

$ErrorActionPreference = "Stop"
$deviceTree = "f:\learn-front\learn-hook\vivo-twrp\device_vivo_pd2415_twrp"
$prebuilt = Join-Path $deviceTree "prebuilt"
$tmpRemote = "/data/local/tmp/pd2415_extract"

function Assert-AdbDevice {
    $output = adb devices
    Write-Host "[debug] adb devices output:"
    Write-Host $output
    # Look for a line with "device" as the status (not "offline", "unauthorized", "no devices")
    $deviceLine = $output -split "`n" | Where-Object { $_ -match "\sdevice\s*$" -or $_ -match "\tdevice$" }
    if (-not $deviceLine) {
        Write-Error "No adb device in 'device' state. Connect phone and enable USB debugging.`nOutput:`n$output"
        exit 1
    }
    Write-Host "[+] Found device: $($deviceLine.Trim())"
}

function Invoke-AdbShellSu {
    param([string]$Command)
    $result = adb shell "su -c '$Command'" 2>&1
    return $result
}

function Invoke-AdbShellSuFile {
    param([string]$RemoteCommand, [string]$RemoteFile)
    # Write a script to remote, execute it, so we avoid quoting hell
    $script = "echo '$RemoteCommand' > $tmpRemote/_cmd.sh && sh $tmpRemote/_cmd.sh"
    adb shell "su -c 'mkdir -p $tmpRemote && $script'" 2>&1 | ForEach-Object { Write-Host $_ }
}

function Pull-Directory {
    param([string]$RemotePath, [string]$LocalPath, [string]$Label)
    Write-Host "[*] Pulling $Label from $RemotePath ..."
    New-Item -ItemType Directory -Force -Path $LocalPath | Out-Null
    # adb pull for a directory pulls recursively into the destination
    $result = adb pull $RemotePath $LocalPath 2>&1
    Write-Host $result
}

# --- 0. check device ---
Assert-AdbDevice
Write-Host "[+] Device connected."

# --- 1. dump boot + init_boot partitions ---
Write-Host "`n=== [1/5] Dumping boot + init_boot partitions ==="

# Create remote tmp dir
adb shell "su -c 'mkdir -p $tmpRemote && chmod 777 $tmpRemote'" 2>&1 | Out-Null

# Detect A/B slot suffix (PD2415 uses boot_a/boot_b, not boot)
$slotSuffix = (adb shell "getprop ro.boot.slot_suffix" 2>&1).Trim()
Write-Host "[*] Active slot suffix: '$slotSuffix'"

# Resolve partition paths (use slot-suffixed names)
$bootPath = (adb shell "su -c 'readlink -f /dev/block/by-name/boot$slotSuffix'" 2>&1).Trim()
Write-Host "    boot$slotSuffix -> $bootPath"
$initBootPath = (adb shell "su -c 'readlink -f /dev/block/by-name/init_boot$slotSuffix'" 2>&1).Trim()
Write-Host "    init_boot$slotSuffix -> $initBootPath"

if (-not $bootPath -or $bootPath -notmatch "^/dev/block/sd") {
    Write-Error "Failed to resolve boot partition path. Got: '$bootPath'"
    exit 1
}

# Dump boot partition
Write-Host "[*] Dumping boot partition ($bootPath) to /data/local/tmp ..."
adb shell "su -c 'dd if=$bootPath of=$tmpRemote/boot.img bs=8M'" 2>&1 | ForEach-Object { if ($_ -match "records|copied") { Write-Host "    $_" } }
adb shell "su -c 'chmod 644 $tmpRemote/boot.img'" 2>&1 | Out-Null

# Dump init_boot partition (if it exists)
$initBootSize = $null
if ($initBootPath -and $initBootPath -match "^/dev/block/sd") {
    Write-Host "[*] Dumping init_boot partition ($initBootPath) to /data/local/tmp ..."
    adb shell "su -c 'dd if=$initBootPath of=$tmpRemote/init_boot.img bs=8M'" 2>&1 | ForEach-Object { if ($_ -match "records|copied") { Write-Host "    $_" } }
    adb shell "su -c 'chmod 644 $tmpRemote/init_boot.img'" 2>&1 | Out-Null
    # Read partition size
    $initBootSize = (adb shell "su -c 'blockdev --getsize64 $initBootPath'" 2>&1).Trim()
    Write-Host "    init_boot partition size: $initBootSize bytes"
} else {
    Write-Host "    [!] init_boot partition not resolved — device may use combined boot"
}

# Pull boot.img and init_boot.img
$kernelDir = Join-Path $prebuilt "kernel_source"
New-Item -ItemType Directory -Force -Path $kernelDir | Out-Null
Write-Host "[*] Pulling boot.img ..."
    adb pull "$tmpRemote/boot.img" $kernelDir 2>&1 | ForEach-Object { Write-Host "    $_" }

if ($initBootPath -and $initBootPath -match "^/dev/") {
    Write-Host "[*] Pulling init_boot.img ..."
    adb pull "$tmpRemote/init_boot.img" $kernelDir 2>&1 | ForEach-Object { Write-Host "    $_" }
    # Save the size for later substitution
    $initBootSize | Set-Content (Join-Path $kernelDir "init_boot_size.txt") -NoNewline
    Write-Host "    init_boot size saved to init_boot_size.txt"
}

# --- 2. vendor build.prop ---
Write-Host "`n=== [2/5] Pulling vendor/build.prop ==="
$propDir = Join-Path $prebuilt "recovery_properties"
New-Item -ItemType Directory -Force -Path $propDir | Out-Null

# Try /vendor/build.prop first, fallback to prop query
$vendorProp = (adb shell "su -c 'cat /vendor/build.prop'" 2>&1)
if ($LASTEXITCODE -eq 0 -and $vendorProp) {
    $vendorProp | Set-Content (Join-Path $propDir "vendor.build.prop") -Encoding ASCII
    Write-Host "[+] vendor.build.prop saved."
} else {
    Write-Host "[!] /vendor/build.prop not readable, trying getprop ..."
    # Fallback: dump all props and filter vendor.* + ro.build.*
    $allProps = adb shell "su -c 'getprop'" 2>&1
    $filtered = $allProps | Where-Object { $_ -match "^\[ro\.(build|vendor)\." }
    $filtered | Set-Content (Join-Path $propDir "vendor.build.prop") -Encoding ASCII
    Write-Host "[+] vendor.build.prop (from getprop) saved."
}

# Also pull the full /vendor/etc/prop_default if it exists (more authoritative)
adb shell "su -c 'ls /vendor/etc/build.prop /vendor/etc/prop.default'" 2>&1 | ForEach-Object {
    if ($_ -match "build\.prop") {
        adb pull "/vendor/etc/build.prop" $propDir 2>&1 | Out-Null
    }
}

# --- 3. vendor HAL closure (crypto chain) ---
Write-Host "`n=== [3/5] Pulling vendor HAL closure ==="
$halDir = Join-Path $prebuilt "recovery_vendor_hal"
New-Item -ItemType Directory -Force -Path $halDir | Out-Null

# Pull the crypto-relevant HAL binaries + libs from /vendor
# Key binaries: tee-supplicant, vendor.keymint-*, vendor.gatekeeper-*,
# vendor.weaver-*, vendor.secure_element-*, android.hardware.boot-*
Write-Host "[*] Pulling /vendor/bin/hw/ ..."
    adb pull "/vendor/bin/hw" (Join-Path $halDir "bin\hw") 2>&1 | ForEach-Object { Write-Host "    $_" }

Write-Host "[*] Pulling /vendor/bin/tee-supplicant ..."
    adb shell "su -c 'cp /vendor/bin/tee-supplicant $tmpRemote/ 2>/dev/null; chmod 644 $tmpRemote/tee-supplicant 2>/dev/null'" 2>&1 | Out-Null
    adb pull "$tmpRemote/tee-supplicant" (Join-Path $halDir "bin") 2>&1 | ForEach-Object { Write-Host "    $_" }

Write-Host "[*] Pulling /vendor/lib64/ ..."
    # Full /vendor/lib64 is too large; pull only the HAL-related libs
    # The build will pull the right ones via dep resolution; for now get the
    # keymint/gatekeeper/weaver/secure_element libs
    adb pull "/vendor/lib64" (Join-Path $halDir "lib64") 2>&1 | ForEach-Object { Write-Host "    $_" }

# Pull TA directories if they exist (MediaTek Mitee, Keymint TAs)
Write-Host "[*] Checking for TA directories ..."
    adb shell "su -c 'ls -d /vendor/mitee /vendor/ta /vendor/etc/tas /vendor/lib64/ta 2>/dev/null'" 2>&1 | ForEach-Object {
        $taDir = $_.Trim()
        if ($taDir) {
            Write-Host "    Found TA dir: $taDir"
            adb pull $taDir $halDir 2>&1 | ForEach-Object { Write-Host "    $_" }
        }
    }

# --- 4. vendor firmware ---
Write-Host "`n=== [4/5] Pulling vendor/firmware ==="
$fwDir = Join-Path $prebuilt "recovery_firmware"
New-Item -ItemType Directory -Force -Path $fwDir | Out-Null

Write-Host "[*] Pulling /vendor/firmware/ ..."
    adb pull "/vendor/firmware" $fwDir 2>&1 | ForEach-Object { Write-Host "    $_" }

# --- 5. Summary ---
Write-Host "`n=== [5/5] Summary ==="
Write-Host "[+] Extraction complete. Files saved to:"
Write-Host "    $prebuilt"
Write-Host ""
Write-Host "    boot.img        -> $kernelDir\boot.img"
if (Test-Path (Join-Path $kernelDir "init_boot.img")) {
    Write-Host "    init_boot.img   -> $kernelDir\init_boot.img"
    Write-Host "    init_boot size  -> $kernelDir\init_boot_size.txt"
}
Write-Host "    vendor.build.prop -> $propDir\vendor.build.prop"
Write-Host "    vendor HAL        -> $halDir"
Write-Host "    vendor firmware   -> $fwDir"
Write-Host ""
Write-Host "[!] Next steps:"
Write-Host "    1. Run unpack_bootimg on boot.img to extract prebuilt/kernel"
Write-Host "    2. Read init_boot_size.txt and replace <INIT_BOOT_SIZE> in BoardConfig.mk"
Write-Host "    3. Run sha256sum on prebuilt files and fill SHA_PLACEHOLDER in package-vendor-boot.sh"
Write-Host "    4. Convert ramdisk.1.lz4 -> platform.cpio.gz, ramdisk.2 -> official_recovery.cpio.gz (needs lz4)"

# Cleanup remote tmp
Write-Host "`n[*] Cleaning up remote tmp ..."
adb shell "su -c 'rm -rf $tmpRemote'" 2>&1 | Out-Null
Write-Host "[+] Done."
