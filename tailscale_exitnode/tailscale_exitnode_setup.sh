#!/bin/bash

LOG_FILE="/home/uutzinger/tailscale_exitnode_setup.log"
> "$LOG_FILE"  # Clears previous log on each run
exec > >(tee -a "$LOG_FILE") 2>&1

echo "----- $(date) Starting Tailscale Exit Node Setup -----"

# Enable IPv4 & IPv6 forwarding
echo "[INFO] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Detect Interface
echo "[INFO] Detecting default interface..."
IFACE=$(ip route get 8.8.8.8 | awk '{ print $5; exit }')

# Setup NAT
echo "[INFO] Checking NAT (MASQUERADE) rule..."
iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null
if [ $? -ne 0 ]; then
  echo "[INFO] Adding MASQUERADE rule..."
  iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
else
  echo "[INFO] MASQUERADE rule already exists."
fi

# Validate MASQUERADE rule after setting it
echo "[CHECK] Validating MASQUERADE rule..."
iptables -t nat -L POSTROUTING -n -v | grep -q "MASQUERADE.*$IFACE"
if [ $? -eq 0 ]; then
  echo "[OK] MASQUERADE rule is active on $IFACE"
else
  echo "[ERROR] MASQUERADE rule is missing or incorrect on $IFACE"
fi

# UDP GRO fix
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

echo "----- $(date) Tailscale Exit Node Setup Complete -----"
