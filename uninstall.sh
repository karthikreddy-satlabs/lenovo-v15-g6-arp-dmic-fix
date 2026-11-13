#!/bin/bash
# Remove the out-of-tree patched snd-soc-acp6x-mach module installed by
# install.sh, restoring the distro-packaged copy.
#
# Usage: ./uninstall.sh [kernel-version]   (default: running kernel)
set -euo pipefail

K=${1:-$(uname -r)}
MOD="/usr/lib/modules/$K/updates/snd-soc-acp6x-mach.ko"

if [ ! -f "$MOD" ]; then
    echo "Nothing to remove: $MOD not found."
    exit 0
fi

sudo modprobe -r snd_soc_acp6x_mach 2>/dev/null || true
sudo rm -f "$MOD"
sudo depmod -a "$K"
sudo modprobe snd_soc_acp6x_mach 2>/dev/null || true

echo "Removed $MOD and regenerated module dependencies."
echo "A reboot is recommended so the packaged driver takes over cleanly."
