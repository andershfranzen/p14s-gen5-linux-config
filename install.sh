#!/bin/bash
# Config-only installer for ThinkPad P14s Gen 5 AMD power management
# Assumes packages and ryzenadj are already installed. Use setup.sh for full setup.
#
# Usage: sudo ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Installing power config ==="

# Kernel module
if [ ! -f /etc/modprobe.d/thinkpad_acpi.conf ] || ! grep -q fan_control /etc/modprobe.d/thinkpad_acpi.conf; then
    echo "Installing thinkpad_acpi modprobe config..."
    sudo cp "$SCRIPT_DIR/modprobe/thinkpad_acpi.conf" /etc/modprobe.d/thinkpad_acpi.conf
fi

# Thinkfan
echo "Installing thinkfan config..."
sudo cp "$SCRIPT_DIR/thinkfan/thinkfan.yaml" /etc/thinkfan.yaml

# Power-switch script + udev rule
echo "Installing power-switch script..."
sudo cp "$SCRIPT_DIR/scripts/power-switch.sh" /usr/local/bin/power-switch.sh
sudo chmod 755 /usr/local/bin/power-switch.sh
sudo cp "$SCRIPT_DIR/udev/99-power-switch.rules" /etc/udev/rules.d/99-power-switch.rules
sudo udevadm control --reload-rules

# Systemd services
echo "Installing systemd services..."
sudo cp "$SCRIPT_DIR/systemd/ryzenadj.service" /etc/systemd/system/ryzenadj.service
sudo cp "$SCRIPT_DIR/systemd/powertop-autotune.service" /etc/systemd/system/powertop-autotune.service

# Sleep hook
echo "Installing sleep hook..."
sudo mkdir -p /etc/systemd/system-sleep
sudo cp "$SCRIPT_DIR/sleep-hooks/ryzenadj.sh" /etc/systemd/system-sleep/ryzenadj.sh
sudo chmod 755 /etc/systemd/system-sleep/ryzenadj.sh

# zram + sysctl
echo "Installing zram and sysctl config..."
sudo cp "$SCRIPT_DIR/zram/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo cp "$SCRIPT_DIR/sysctl/99-zram.conf" /etc/sysctl.d/99-zram.conf
sudo sysctl --load=/etc/sysctl.d/99-zram.conf

# Enable services
echo "Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable --now thinkfan.service
sudo systemctl enable --now powertop-autotune.service
sudo systemctl enable ryzenadj.service
sudo systemctl start ryzenadj.service

echo ""
echo "=== Verification ==="
echo "thinkfan:      $(systemctl is-active thinkfan.service)"
echo "ryzenadj:      exit $(systemctl show -p ExecMainStatus ryzenadj.service | cut -d= -f2) (0=success)"
echo "powertop:      exit $(systemctl show -p ExecMainStatus powertop-autotune.service | cut -d= -f2) (0=success)"
echo "tuned:         $(tuned-adm active)"
echo "power-switch:  $([ -x /usr/local/bin/power-switch.sh ] && echo 'installed' || echo 'MISSING')"
echo "sleep hook:    $([ -x /etc/systemd/system-sleep/ryzenadj.sh ] && echo 'installed' || echo 'MISSING')"
echo "bat start:     $(cat /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null || echo 'N/A')"
echo "bat stop:      $(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo 'N/A')"
echo "fan_control:   $(cat /sys/module/thinkpad_acpi/parameters/fan_control 2>/dev/null || echo 'N/A')"
echo "swappiness:    $(cat /proc/sys/vm/swappiness)"
echo ""
echo "Done. Reboot recommended for zram changes."
