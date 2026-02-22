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
| Power limits | RyzenAdj (built from source) |

## What This Does

- **Fan control** via thinkfan with a custom fan curve tuned for the 8840HS — silent at idle, progressive ramp through load, full speed safety above 83C
- **Power limits** via RyzenAdj — STAPM 25W, slow PPT 28W, fast PPT 35W, Tctl target 85C (lower thermals while retaining burst performance)
- **Battery charge thresholds** — start 75%, stop 80% (extends long-term battery health)
- **Tuned profile** — `balanced` via tuned + tuned-ppd (integrates with KDE/GNOME power profiles)
- **Post-resume hook** — reapplies power limits, battery thresholds, and tuned profile after suspend/hibernate (SMU resets these during sleep)

## Quick Setup

```bash
git clone https://github.com/afranzen/p14s-gen5-linux-config.git
cd p14s-gen5-linux-config
sudo ./setup.sh
```

The setup script will:
1. Install packages (thinkfan, tuned, tuned-ppd, cmake, gcc-c++, etc.)
2. Build and install RyzenAdj from source
3. Configure `thinkpad_acpi` kernel module with `fan_control=1`
4. Deploy thinkfan config (`/etc/thinkfan.yaml`)
5. Install ryzenadj systemd service (boot) and sleep hook (post-resume)
6. Enable and start all services
7. Print verification output

## File Layout

```
├── setup.sh                        # Full automated setup
├── install.sh                      # Config-only installer (assumes ryzenadj already built)
├── modprobe/
│   └── thinkpad_acpi.conf          # fan_control=1 → /etc/modprobe.d/
├── thinkfan/
│   └── thinkfan.yaml               # Fan curve → /etc/thinkfan.yaml
├── systemd/
│   └── ryzenadj.service            # Power limits on boot → /etc/systemd/system/
└── sleep-hooks/
    └── ryzenadj.sh                 # Post-resume hook → /etc/systemd/system-sleep/
```

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

## RyzenAdj Power Limits

| Parameter | Value | Stock Default |
|---|---|---|
| STAPM (sustained) | 25W | ~28W |
| Slow PPT | 28W | ~35W |
| Fast PPT | 35W | ~54W |
| Tctl temp target | 85C | ~95-100C |

**Note:** Curve Optimizer (true undervolting) is locked by the Lenovo BIOS firmware on this model. Power limit tuning is the best available alternative — it reduces voltage indirectly by constraining power draw.

## Services

| Service | Type | Purpose |
|---|---|---|
| `thinkfan.service` | long-running | Fan control daemon |
| `thinkfan-sleep.service` | oneshot | Signals thinkfan before sleep |
| `thinkfan-wakeup.service` | oneshot | Reloads thinkfan after wake |
| `ryzenadj.service` | oneshot (boot) | Applies power limits + battery thresholds |
| `tuned.service` | long-running | Dynamic system tuning |
| `tuned-ppd.service` | long-running | PPD API translation for desktop integration |

Post-resume: `/etc/systemd/system-sleep/ryzenadj.sh` reapplies RyzenAdj limits, battery thresholds, and tuned profile.

## Customization

**Power limits:** Edit values in `systemd/ryzenadj.service` and `sleep-hooks/ryzenadj.sh`, then re-run `install.sh` or copy manually.

**Fan curve:** Edit `thinkfan/thinkfan.yaml` and copy to `/etc/thinkfan.yaml`, then `sudo systemctl restart thinkfan`.

**Battery thresholds:** Edit the `echo` lines in `systemd/ryzenadj.service` and `sleep-hooks/ryzenadj.sh`.

**Tuned profile:** Change `balanced` in `sleep-hooks/ryzenadj.sh` to any profile from `tuned-adm list`.
