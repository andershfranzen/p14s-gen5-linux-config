# Lenovo ThinkPad P14s Gen 5 AMD — Linux Power Config

Power management, fan control, and thermal tuning for the ThinkPad P14s Gen 5 AMD running Fedora.

## Hardware

| Component | Spec |
|---|---|
| Model | Lenovo ThinkPad P14s Gen 5 AMD (21ME0006MX) |
| CPU | AMD Ryzen 7 PRO 8840HS (Hawk Point / Zen 4, 8C/16T, Tjmax 100C) |
| GPU | AMD Radeon 780M (integrated) |
| RAM | 32 GB LPDDR5x |
| Storage | 1 TB SK Hynix NVMe (HFS001TEJ9X162N) |
| Fan | Single fan via ThinkPad ACPI (`/proc/acpi/ibm/fan`) |

## Software

| Component | Version |
|---|---|
| OS | Fedora 43 (KDE Plasma Desktop Edition) |
| Kernel | 6.18.x (`amd_pstate_epp` default) |
| Fan control | thinkfan 2.0 |
| System tuning | tuned + tuned-ppd |
| Misc power | powertop auto-tune |

## What This Does

- **Fan control** via thinkfan with a custom fan curve tuned for the 8840HS — silent at idle, progressive ramp through load, full speed safety above 83C
- **AC/battery auto-switching** — udev rule triggers automatic profile switching on plug/unplug (EPP, boost, iGPU DPM, tuned profile)
- **Battery charge thresholds** — start 75%, stop 80% (extends long-term battery health)
- **iGPU power management** — dynamic DPM on AC, low-power on battery
- **zram optimization** — zstd compression with tuned swappiness for better memory utilization
- **Powertop auto-tune** — USB autosuspend, audio codec power save, and misc kernel tunables
- **Post-resume hook** — reapplies the correct AC/battery profile and battery thresholds after suspend/hibernate

## Quick Setup

```bash
git clone https://github.com/andershfranzen/p14s-gen5-linux-config.git
cd p14s-gen5-linux-config
sudo ./setup.sh
```

The setup script will:
1. Install packages (thinkfan, tuned, tuned-ppd, powertop)
2. Configure `thinkpad_acpi` kernel module with `fan_control=1`
3. Deploy thinkfan config, zram config, sysctl tuning
4. Install power-switch script, udev rule, systemd services, and sleep hook
5. Enable and start all services
6. Print verification output

## File Layout

```
├── setup.sh                        # Full automated setup
├── install.sh                      # Config-only installer (assumes deps installed)
├── scripts/
│   └── power-switch.sh             # AC/battery profile switcher → /usr/local/bin/
├── udev/
│   └── 99-power-switch.rules       # AC plug/unplug trigger → /etc/udev/rules.d/
├── systemd/
│   ├── power-switch.service        # Boot: apply profile + battery thresholds → /etc/systemd/system/
│   └── powertop-autotune.service   # Boot: powertop --auto-tune → /etc/systemd/system/
├── sleep-hooks/
│   └── power-switch.sh             # Post-resume hook → /etc/systemd/system-sleep/
├── thinkfan/
│   └── thinkfan.yaml               # Fan curve → /etc/thinkfan.yaml
├── zram/
│   └── zram-generator.conf         # zstd compression → /etc/systemd/zram-generator.conf
├── sysctl/
│   └── 99-zram.conf                # Swappiness + page-cluster → /etc/sysctl.d/
└── modprobe/
    └── thinkpad_acpi.conf          # fan_control=1 → /etc/modprobe.d/
```

## Power Profiles

### AC (plugged in)

| Parameter | Value |
|---|---|
| EPP | balance_performance |
| CPU boost | On |
| iGPU DPM | auto |
| Tuned profile | balanced |

### Battery (unplugged)

| Parameter | Value |
|---|---|
| EPP | power |
| CPU boost | Off |
| iGPU DPM | low |
| Tuned profile | balanced-battery |

Switching is automatic via udev rule on AC plug/unplug, and reapplied after suspend resume.

**Note:** Both Curve Optimizer and RyzenAdj power limits are locked by the Lenovo BIOS firmware on this model — the SMU accepts commands but silently ignores them. Kernel-level controls (EPP, boost, tuned) provide the actual AC/battery differentiation.

## Fan Curve

| Level | Lower (C) | Upper (C) | Notes |
|---|---|---|---|
| 0 (off) | 0 | 50 | Silent idle/desktop |
| 1 | 47 | 55 | Light browsing |
| 2 | 52 | 60 | |
| 3 | 57 | 65 | |
| 4 | 62 | 70 | Medium load |
| 5 | 67 | 75 | |
| 6 | 72 | 80 | |
| 7 | 77 | 85 | Heavy sustained |
| Disengaged | 83 | - | Full speed safety |

Hysteresis gaps between lower/upper limits prevent fan speed oscillation.

## zram

- Compression: zstd (better ratio than default lzo-rle, negligible CPU cost on Zen 4)
- Size: min(RAM, 8GB)
- Swappiness: 150 (lets kernel compress cold pages aggressively into zram)
- page-cluster: 0 (read single pages from swap, not clusters — better for compressed swap)

## Services

| Service | Type | Purpose |
|---|---|---|
| `thinkfan.service` | long-running | Fan control daemon |
| `thinkfan-sleep.service` | oneshot | Signals thinkfan before sleep |
| `thinkfan-wakeup.service` | oneshot | Reloads thinkfan after wake |
| `power-switch.service` | oneshot (boot) | Applies power profile + battery thresholds |
| `powertop-autotune.service` | oneshot (boot) | Misc kernel power tunables |
| `tuned.service` | long-running | Dynamic system tuning |
| `tuned-ppd.service` | long-running | PPD API translation for desktop integration |

Post-resume: `/etc/systemd/system-sleep/power-switch.sh` reapplies the correct AC/battery profile and battery thresholds.

## Customization

**Power profiles:** Edit `scripts/power-switch.sh` (both AC and battery sections), redeploy with `install.sh`.

**Fan curve:** Edit `thinkfan/thinkfan.yaml`, copy to `/etc/thinkfan.yaml`, then `sudo systemctl restart thinkfan`.

**Battery thresholds:** Edit the threshold lines in `systemd/power-switch.service` and `sleep-hooks/power-switch.sh`.

**Tuned profile:** Change profile names in `scripts/power-switch.sh`. See `tuned-adm list` for options.

**zram:** Edit `zram/zram-generator.conf` and `sysctl/99-zram.conf`. Reboot to apply zram changes.
