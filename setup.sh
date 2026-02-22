#!/bin/bash
# Full automated setup for ThinkPad P14s Gen 5 AMD power management on Fedora
# Installs all dependencies, builds ryzenadj, deploys configs, and enables services.
#
# Usage: sudo ./setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RYZENADJ_REPO="https://github.com/FlyGoat/RyzenAdj.git"
RYZENADJ_BUILD_DIR="/tmp/RyzenAdj-build"

# --- Helpers ---
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[ OK ]\033[0m $*"; }
err()   { echo -e "\033[1;31m[ERR ]\033[0m $*" >&2; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        err "This script must be run as root (sudo ./setup.sh)"
        exit 1
    fi
}

# --- Step 1: Install packages ---
install_packages() {
    info "Installing packages..."
    dnf install -y thinkfan tuned tuned-ppd powertop \
        cmake gcc-c++ pciutils-devel git
    ok "Packages installed"
}

# --- Step 2: Build and install RyzenAdj ---
install_ryzenadj() {
    if command -v ryzenadj &>/dev/null; then
        info "ryzenadj already installed at $(command -v ryzenadj)"
        return
    fi

    info "Building RyzenAdj from source..."
    rm -rf "$RYZENADJ_BUILD_DIR"
    git clone "$RYZENADJ_REPO" "$RYZENADJ_BUILD_DIR"
    mkdir -p "$RYZENADJ_BUILD_DIR/build"
    cd "$RYZENADJ_BUILD_DIR/build"
    cmake ..
    make -j"$(nproc)"
    cp ryzenadj /usr/local/bin/ryzenadj
    cp libryzenadj.so /usr/local/lib/
    ldconfig
    cd "$SCRIPT_DIR"
    rm -rf "$RYZENADJ_BUILD_DIR"
    ok "RyzenAdj installed to /usr/local/bin/ryzenadj"
}

# --- Step 3: Kernel module config ---
install_modprobe() {
    info "Configuring thinkpad_acpi fan_control..."
    cp "$SCRIPT_DIR/modprobe/thinkpad_acpi.conf" /etc/modprobe.d/thinkpad_acpi.conf

    # Enable immediately if module is loaded
    if [ -f /sys/module/thinkpad_acpi/parameters/fan_control ]; then
        echo 1 > /sys/module/thinkpad_acpi/parameters/fan_control 2>/dev/null || true
    fi
    ok "thinkpad_acpi fan_control=1"
}

# --- Step 4: Thinkfan config ---
install_thinkfan() {
    info "Installing thinkfan config..."
    cp "$SCRIPT_DIR/thinkfan/thinkfan.yaml" /etc/thinkfan.yaml
    ok "Thinkfan config installed"
}

# --- Step 5: Power-switch script + udev rule ---
install_power_switch() {
    info "Installing power-switch script and udev rule..."
    cp "$SCRIPT_DIR/scripts/power-switch.sh" /usr/local/bin/power-switch.sh
    chmod 755 /usr/local/bin/power-switch.sh
    cp "$SCRIPT_DIR/udev/99-power-switch.rules" /etc/udev/rules.d/99-power-switch.rules
    udevadm control --reload-rules
    ok "AC/battery auto-switching installed"
}

# --- Step 6: Systemd services ---
install_services() {
    info "Installing systemd services..."
    cp "$SCRIPT_DIR/systemd/ryzenadj.service" /etc/systemd/system/ryzenadj.service
    cp "$SCRIPT_DIR/systemd/powertop-autotune.service" /etc/systemd/system/powertop-autotune.service
    ok "Systemd services installed"
}

# --- Step 7: Sleep hook (post-resume) ---
install_sleep_hook() {
    info "Installing sleep hook..."
    mkdir -p /etc/systemd/system-sleep
    cp "$SCRIPT_DIR/sleep-hooks/ryzenadj.sh" /etc/systemd/system-sleep/ryzenadj.sh
    chmod 755 /etc/systemd/system-sleep/ryzenadj.sh
    ok "Sleep hook installed"
}

# --- Step 8: zram + sysctl ---
install_zram() {
    info "Installing zram and sysctl config..."
    cp "$SCRIPT_DIR/zram/zram-generator.conf" /etc/systemd/zram-generator.conf
    cp "$SCRIPT_DIR/sysctl/99-zram.conf" /etc/sysctl.d/99-zram.conf
    sysctl --load=/etc/sysctl.d/99-zram.conf
    ok "zram (zstd) and sysctl tuning installed (zram takes effect on reboot)"
}

# --- Step 9: Enable and start services ---
enable_services() {
    info "Enabling services..."
    systemctl daemon-reload

    # Thinkfan (includes sleep/wakeup units via Also= directives)
    systemctl enable --now thinkfan.service

    # Tuned
    systemctl enable --now tuned.service
    systemctl enable --now tuned-ppd.service

    # Powertop auto-tune
    systemctl enable --now powertop-autotune.service

    # RyzenAdj + power profile (oneshot on boot)
    systemctl enable ryzenadj.service
    systemctl start ryzenadj.service

    ok "All services enabled"
}

# --- Step 10: Verify ---
verify() {
    echo ""
    info "=== Verification ==="
    echo "thinkfan:        $(systemctl is-active thinkfan.service)"
    echo "tuned:           $(systemctl is-active tuned.service)"
    echo "tuned-ppd:       $(systemctl is-active tuned-ppd.service)"
    echo "powertop:        $(systemctl show -p ExecMainStatus powertop-autotune.service | cut -d= -f2) (0=success)"
    echo "tuned profile:   $(tuned-adm active 2>/dev/null | awk '{print $NF}')"
    echo "ryzenadj:        exit $(systemctl show -p ExecMainStatus ryzenadj.service | cut -d= -f2) (0=success)"
    echo "sleep hook:      $([ -x /etc/systemd/system-sleep/ryzenadj.sh ] && echo 'installed' || echo 'MISSING')"
    echo "power-switch:    $([ -x /usr/local/bin/power-switch.sh ] && echo 'installed' || echo 'MISSING')"
    echo "udev rule:       $([ -f /etc/udev/rules.d/99-power-switch.rules ] && echo 'installed' || echo 'MISSING')"
    echo "fan_control:     $(cat /sys/module/thinkpad_acpi/parameters/fan_control 2>/dev/null || echo 'N/A')"
    echo "amd_pstate:      $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo 'N/A')"
    echo "epp:             $(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo 'N/A')"
    echo "iGPU DPM:        $(cat /sys/class/drm/card1/device/power_dpm_force_performance_level 2>/dev/null || echo 'N/A')"
    echo "bat start:       $(cat /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null || echo 'N/A')"
    echo "bat stop:        $(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo 'N/A')"
    echo "zram algo:       $(cat /sys/block/zram0/comp_algorithm 2>/dev/null | tr -d '[]' | awk '{for(i=1;i<=NF;i++) if($i ~ /\[/) print $i}' || cat /etc/systemd/zram-generator.conf | grep compression)"
    echo "swappiness:      $(cat /proc/sys/vm/swappiness)"
    echo ""
    ok "Setup complete. Reboot recommended for zram changes to take effect."
}

# --- Main ---
check_root
install_packages
install_ryzenadj
install_modprobe
install_thinkfan
install_power_switch
install_services
install_sleep_hook
install_zram
enable_services
verify
