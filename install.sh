#!/bin/bash
# Build + install the patched snd-soc-acp6x-mach module with the
# Lenovo V15 G6 ARP (product name "83V4") DMIC quirk.
#
# Usage:
#   ./install.sh [kernel-version]
#
# Examples:
#   ./install.sh              # build for the running kernel
#   ./install.sh 7.2.15-1-omarchy
#
# Run this after every kernel update until the 83V4 quirk lands in
# mainline kernels. See README.md for background.
set -euo pipefail

K=${1:-$(uname -r)}
B=/lib/modules/$K/build

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: do not run as root; the script sudo-extracts only the install steps." >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required to refresh sources for a different kernel version." >&2
    exit 1
fi

if [ ! -d "$B" ]; then
    echo "ERROR: no build tree for kernel $K." >&2
    echo "       Install the matching headers package first, e.g.:" >&2
    echo "         Arch:   sudo pacman -S linux-headers   (or linux-${K%%-*}-headers)" >&2
    echo "         Debian: sudo apt install linux-headers-$K" >&2
    exit 1
fi

cd "$(dirname "$0")"

# When building for a kernel other than the running one, refresh the sources
# from kernel.org so the module matches that kernel's version of the driver.
if [ "$K" != "$(uname -r)" ]; then
    BASE="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/sound/soc/amd/yc"
    H="h=v$K"
    for f in acp6x-mach.c acp6x.h acp6x_chip_offset_byte.h; do
        if curl -fsSL "$BASE/$f?$H" -o "$f"; then
            echo "Refreshed $f from v$K sources."
        else
            echo "WARN: could not fetch $f for $K, using the existing copy." >&2
        fi
    done
fi

# Sanity check: our quirk entry must be present after any source refresh.
if ! grep -q '"83V4"' acp6x-mach.c; then
    echo "ERROR: the 83V4 quirk is missing from acp6x-mach.c." >&2
    echo "       Re-add the DMI block shown in README.md (section 'Why')." >&2
    exit 1
fi

echo "Building for kernel $K ..."
rm -f snd-soc-acp6x-mach.ko
make -C "$B" M="$PWD" modules

echo "Installing to /usr/lib/modules/$K/updates/ ..."
sudo mkdir -p "/usr/lib/modules/$K/updates"
sudo cp snd-soc-acp6x-mach.ko "/usr/lib/modules/$K/updates/"
sudo depmod -a "$K"
sudo modprobe -r snd_soc_acp6x_mach 2>/dev/null || true
sudo modprobe snd_soc_acp6x_mach

sleep 1
if cat /proc/asound/cards | grep -A1 acp6x; then
    echo "OK: DMIC card active. If the internal mic still shows no input, reboot once."
else
    echo "NOTE: no acp6x card listed yet — try a reboot, then check /proc/asound/cards." >&2
    exit 1
fi
