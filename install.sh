#!/bin/bash
# Power config installer for ThinkPad P14s Gen 5 AMD (Ryzen 7 PRO 8840HS)
# Fedora 43 / kernel 6.x / amd_pstate_epp
#
# Requires: thinkfan, tuned, tuned-ppd, ryzenadj (/usr/local/bin)
#
# Build ryzenadj from source:
#   dnf install cmake gcc-c++ pciutils-devel
#   git clone https://github.com/FlyGoat/RyzenAdj.git
#   cd RyzenAdj && mkdir build && cd build && cmake .. && make
#   sudo cp ryzenadj /usr/local/bin/
#   sudo cp libryzenadj.so /usr/local/lib/ && sudo ldconfig

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Installing power config ==="

# Thinkfan config
echo "Installing thinkfan config..."
sudo cp "$SCRIPT_DIR/thinkfan/thinkfan.yaml" /etc/thinkfan.yaml

# Ensure fan_control is enabled for thinkpad_acpi
if [ ! -f /etc/modprobe.d/thinkpad_acpi.conf ] || ! grep -q fan_control /etc/modprobe.d/thinkpad_acpi.conf; then
    echo "Installing thinkpad_acpi modprobe config..."
    sudo cp "$SCRIPT_DIR/modprobe/thinkpad_acpi.conf" /etc/modprobe.d/thinkpad_acpi.conf
fi

# RyzenAdj boot service
echo "Installing ryzenadj systemd service..."
sudo cp "$SCRIPT_DIR/systemd/ryzenadj.service" /etc/systemd/system/ryzenadj.service

# Sleep hook (post-resume)
echo "Installing sleep hook..."
sudo mkdir -p /etc/systemd/system-sleep
sudo cp "$SCRIPT_DIR/sleep-hooks/ryzenadj.sh" /etc/systemd/system-sleep/ryzenadj.sh
sudo chmod 755 /etc/systemd/system-sleep/ryzenadj.sh

# Reload and enable services
echo "Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable --now thinkfan.service
sudo systemctl enable ryzenadj.service
sudo systemctl start ryzenadj.service

echo ""
echo "=== Verification ==="
echo "thinkfan:  $(systemctl is-active thinkfan.service)"
echo "ryzenadj:  $(systemctl show -p ExecMainStatus ryzenadj.service | cut -d= -f2) (0=success)"
echo "tuned:     $(tuned-adm active)"
echo "bat start: $(cat /sys/class/power_supply/BAT0/charge_control_start_threshold)"
echo "bat stop:  $(cat /sys/class/power_supply/BAT0/charge_control_end_threshold)"
echo "fan_ctrl:  $(cat /sys/module/thinkpad_acpi/parameters/fan_control)"
echo ""
echo "Done."
