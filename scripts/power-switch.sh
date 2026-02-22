#!/bin/bash
# AC/Battery power profile switcher for ThinkPad P14s Gen 5 AMD
# Called by udev on AC plug/unplug events

AC_ONLINE=$(cat /sys/class/power_supply/AC/online 2>/dev/null)

if [ "$AC_ONLINE" = "1" ]; then
    # === AC POWER ===
    # Balanced EPP
    for cpu in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
        echo balance_performance > "$cpu" 2>/dev/null
    done

    # Boost on
    echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null

    # iGPU auto DPM
    echo auto > /sys/class/drm/card1/device/power_dpm_force_performance_level 2>/dev/null

    # Tuned balanced
    /usr/sbin/tuned-adm profile balanced

    logger "power-switch: AC connected — balanced profile"

else
    # === BATTERY ===
    # Power-saving EPP
    for cpu in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
        echo power > "$cpu" 2>/dev/null
    done

    # Boost off on battery (saves significant power)
    echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null

    # iGPU low power
    echo low > /sys/class/drm/card1/device/power_dpm_force_performance_level 2>/dev/null

    # Tuned battery profile
    /usr/sbin/tuned-adm profile balanced-battery

    logger "power-switch: Battery — power-saving profile"
fi
