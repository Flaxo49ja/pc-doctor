#!/usr/bin/env bash
# =====================================================================
# build.sh -- produces pc-doctor-live.iso (Debian trixie, amd64)
# UEFI + legacy hybrid, auto-login tty1 -> pc-doctor.sh, memtest86+
# in the boot menu. Target < 1 GB so it fits a 4 GB stick.
#
# Requirements: build on Debian 13+ (or in a container):
#   sudo apt install live-build
#   sudo ./build.sh
# Output: pc-doctor-live.iso + pc-doctor-live.iso.sha256
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }

# clean previous attempts but keep our own files
rm -rf config chroot cache pc-doctor-live.iso binary*.iso
mkdir -p config

# ---------- copy the toolkit that ships on the ISO ----------
mkdir -p config/includes.launch/pc-doctor
cp ../pc-doctor.sh config/includes.launch/pc-doctor/
cp ../CHECKLIST.md config/includes.launch/pc-doctor/ 2>/dev/null || true
cp ../CHECKLIST.pt.md config/includes.launch/pc-doctor/ 2>/dev/null || true
chmod +x config/includes.launch/pc-doctor/pc-doctor.sh

# ---------- auto-login tty1 that launches pc-doctor ----------
mkdir -p config/includes.lib.systemd.system/getty@tty1.service.d
cat > config/includes.lib.systemd.system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF

# ---------- bash profile launches the tool on tty1 ----------
mkdir -p config/includes/etc/profile.d
cat > config/includes/etc/profile.d/pc-doctor.sh <<'EOF'
# start the inspector automatically on the physical console
if [ "$(tty)" = "/dev/tty1" ] && [ -x /pc-doctor/pc-doctor.sh ]; then
  echo "PC-DOCTOR live - starting in 3s (Ctrl+C to get a shell)"
  sleep 3
  /pc-doctor/pc-doctor.sh --lang=pt --quick
fi
EOF

# ---------- main live-build config ----------
cat > config/auto/config <<'EOF'
#!/bin/sh
lb config noauto \
  --architecture amd64 \
  --distribution trixie \
  --archive-areas "main contrib non-free non-free-firmware" \
  --mode debian \
  --binary-images iso-hybrid \
  --bootappend-live "boot=live components quiet splash" \
  --packages-lists none \
  --memtest memtest86+ \
  --debian-installer false \
  --iso-volume "PC-DOCTOR" \
  "$@"
EOF
chmod +x config/auto/config

# ---------- package list (keep under ~1 GB) ----------
mkdir -p config/package-lists
cat > config/package-lists/pc-doctor.list.chroot <<'EOF'
linux-image-amd64
live-boot
systemd-sysv
bash
whiptail
smartmontools
nvme-cli
memtester
stress-ng
lm-sensors
evtest
f3
fio
dmidecode
pciutils
usbutils
edid-decode
efibootmgr
ethtool
glmark2
curl
jq
turbostat
badblocks
e2fsprogs
util-linux
net-tools
iproute2
wireless-tools
firmware-linux-nonfree
firmware-misc-nonfree
EOF

# note: 'turbostat' ships inside linux-tools on Debian; install via hook
mkdir -p config/hooks/live
cat > config/hooks/live/0100-turbostat.hook.chroot <<'EOF'
#!/bin/sh
set -e
apt-get install -y linux-tools-common linux-tools-generic 2>/dev/null || true
EOF
chmod +x config/hooks/live/0100-turbostat.hook.chroot

# ---------- run ----------
lb clean
lb config --config config/auto/config || lb config
lb build

[ -f live-image-amd64.hybrid.iso ] && mv live-image-amd64.hybrid.iso pc-doctor-live.iso
[ -f pc-doctor-live.iso ] || { echo "build failed"; exit 1; }
sha256sum pc-doctor-live.iso > pc-doctor-live.iso.sha256
echo "DONE:"
ls -lh pc-doctor-live.iso*
cat pc-doctor-live.iso.sha256
