# Lenovo V15 G6 ARP (83V4) Internal Microphone Fix for Linux

Out-of-tree build of the Linux kernel module `snd-soc-acp6x-mach` with a DMI
quirk for the **Lenovo V15 G6 ARP**, machine model `83V4`. Without this patch,
the laptop's internal digital microphone (DMIC) is invisible to ALSA/PipeWire
and appears silent, while headset mics keep working.

## Why

On this model the internal mic is a digital mic wired to the **AMD ACP6x**
audio coprocessor, not to the Realtek ALC257 codec. The kernel's
`snd-soc-acp6x-mach` driver only registers a capture sound card on machines
listed in its DMI quirk table. The `83V4` model was not in the table (as of
kernel 7.2.x), so no capture card was ever created and the only "internal mic"
shown was a dead analog pin on the codec — always silence.

This repo patches the quirk table in `src/acp6x-mach.c` with:

```c
{
    .driver_data = &acp6x_card,
    .matches = {
        DMI_MATCH(DMI_BOARD_VENDOR, "LENOVO"),
        DMI_MATCH(DMI_PRODUCT_NAME, "83V4"),
    }
},
```

> **Upstream status:** a quirk for the Lenovo V15 G6 ARP was accepted upstream
> ("ASoC: amd: yc: Add DMI quirk for Lenovo V15 G6 ARP"), but it matches
> machine model `83UU` only. The `83V4` variant still needs this local patch
> until someone submits `83V4` to the mainline quirk table.

## Repository layout

```
.
├── src/
│   ├── acp6x-mach.c                 # Patched machine driver (contains the 83V4 quirk)
│   ├── acp6x.h                      # Headers from the upstream sound/soc/amd/yc directory
│   ├── acp6x_chip_offset_byte.h     #
│   └── Makefile                     # Out-of-tree kbuild file
├── install.sh                       # Build + install helper
├── uninstall.sh                     # Restore the distro-packaged driver
├── LICENSE
└── README.md
```

The module builds against your installed kernel headers; the `.ko` output and
other build artifacts stay inside `src/` and are not tracked by git.

## Requirements

- A Lenovo V15 G6 ARP (check with `sudo dmidecode -s system-product-name`;
  it should print `83V4`)
- Linux kernel headers for the kernel you're running:
  - Arch/CachyOS/Omarchy: `sudo pacman -S linux-headers` (or `linux-<version>-headers`)
  - Debian/Ubuntu: `sudo apt install linux-headers-$(uname -r)`
- `base-devel` / `build-essential` (make, gcc, etc.) and `curl`

> **Check your model first.** If `dmidecode` prints `83UU`, an upstream kernel
> ≥ 7.3 already contains the quirk for your machine and you do **not** need
> this patch — just update your kernel.

## Quick start

```bash
git clone https://github.com/karthikreddy-satlabs/omarchy-microphone-fix.git
cd omarchy-microphone-fix
./install.sh
```

The script will:

1. Build `snd-soc-acp6x-mach.ko` against your running kernel.
2. Install it to `/usr/lib/modules/$(uname -r)/updates/`, which overrides the
   distro-packaged copy of the module.
3. Run `depmod` and reload the module.
4. Verify that an `acp6x` capture card appeared.

If your internal mic still doesn't show up, reboot once — module reload can
leave ACP in a stale state.

## After a kernel update

The module is rebuilt per-kernel, so re-run after every kernel update:

```bash
./install.sh
```

Optionally, automate it with a pacman hook (Arch-based) or run it from your
update script.

## Verify it worked

```bash
cat /proc/asound/cards      # should list an "acp6x-dmic" card
arecord -l                  # should show a capture device on that card
```

Then test in your desktop settings (e.g. GNOME Sound → Input) or with:

```bash
arecord -D hw:acp6x -f S16_LE -r 48000 -c 2 test.wav   # Ctrl+C to stop
```

## Uninstall

```bash
./uninstall.sh
sudo reboot
```

Or manually:

```bash
sudo rm /usr/lib/modules/$(uname -r)/updates/snd-soc-acp6x-mach.ko
sudo depmod -a $(uname -r)
sudo reboot
```

Once the upstream kernel adds `83V4` to the quirk table, this out-of-tree
module is no longer needed at all — just uninstall it and let the packaged
driver take over.

## Troubleshooting

- **`ERROR: no build tree for kernel X`** — install the matching headers package.
- **`ERROR: 83V4 quirk missing from acp6x-mach.c`** — the script refreshes
  sources from kernel.org when building for a non-running kernel and may have
  pulled an upstream version that already contains the quirk (fine) or lost it
  (re-add the DMI block shown above).
- **Card loads but no sound** — check mic isn't muted in `alsamixer` (F6 to
  select the acp6x card), and that PipeWire sees the input port.

## License

The driver sources originate from the Linux kernel
(`sound/soc/amd/yc/`) and are licensed **GPL-2.0-or-later**. This repository
redistributes them under the same license — see [LICENSE](LICENSE), which is
the verbatim `LICENSES/preferred/GPL-2.0` file from the kernel tree.

---

*Not affiliated with or endorsed by Lenovo or AMD. Use at your own risk.*
