#!/bin/bash
# Reapply power settings after resume from suspend/hibernate
# Thinkfan has its own sleep/wakeup services — not handled here.

case "$1" in
    post)
        # Small delay to let hardware and EC settle after wake
        sleep 2

        # Apply correct AC/battery profile (EPP, boost, iGPU, tuned)
        /usr/local/bin/power-switch.sh

        # Battery charge thresholds (EC may reset on some firmware)
        echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold
        echo 75 > /sys/class/power_supply/BAT0/charge_control_start_threshold
        ;;
esac
