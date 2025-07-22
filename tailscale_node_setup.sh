#!/bin/bash

ENABLE_FORWARDING=false  # set true if you are routing

LOG_FILE="/home/<where you want your log>/tailscale_laptop_setup.log"
> "$LOG_FILE"  # Clears previous log on each run
exec > >(tee -a "$LOG_FILE") 2>&1

echo "----- $(date) Starting Laptop Tailscale Client Network Adjustments -----"

# Enable IPv4 & IPv6 forwarding
if $ENABLE_FORWARDING; then
  echo "[INFO] Enabling IP forwarding..."
  sysctl -w net.ipv4.ip_forward=1
  sysctl -w net.ipv6.conf.all.forwarding=1
fi

# Detect Interface
echo "[INFO] Detecting default interface..."
IFACE=$(ip route get 8.8.8.8 | awk '{ print $5; exit }')

# UDP GRO fix (optional)
echo "[INFO] Disabling UDP GRO on $IFACE..."
if ethtool -K "$IFACE"  rx-udp-gro-forwarding on rx-gro-list off; then
  echo "[INFO] GRO disabled on $IFACE"
else
  echo "[WARN] ethtool GRO adjustment failed"
fi

echo "[INFO] Verifying UDP GRO options..."
GRO_STATUS=$(ethtool -k "$IFACE")
if echo "$GRO_STATUS" | grep -q "rx-udp-gro-forwarding: on"; then
    echo "[OK] rx-udp-gro-forwarding is ON"
else
    echo "[WARN] rx-udp-gro-forwarding is NOT set correctly"
fi

if echo "$GRO_STATUS" | grep -q "rx-gro-list: off"; then
    echo "[OK] rx-gro-list is OFF"
else
    echo "[WARN] rx-gro-list is NOT set correctly"
fi

echo "----- $(date) Laptop Tailscale Client Network Adjustments Complete -----"

