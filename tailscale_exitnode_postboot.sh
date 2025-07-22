#!/bin/bash

LOG_FILE="/home/uutzinger/tailscale_exitnode_postboot.log"
> "$LOG_FILE"  # Clears previous log on each run
exec > >(tee -a "$LOG_FILE") 2>&1

echo "----- $(date) Starting Tailscale Exit Node Network Setup -----"

# Enable IPv4 & IPv6 forwarding
echo "[INFO] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

echo "[INFO] Checking for firewalls..."
if command -v ufw >/dev/null; then
  echo "[INFO] UFW detected, disabling..."
  sudo ufw disable || true
fi

if command -v firewall-cmd >/dev/null; then
  echo "[INFO] firewalld detected, stopping..."
  sudo systemctl stop firewalld || true
  sudo systemctl disable firewalld || true
fi

if systemctl list-units | grep -iq nftables; then
  echo "[WARN] nftables detected. Consider checking rules manually (not managed by this script)."
fi

# Allow all traffic from tailscale0 interface
echo "[INFO] Ensuring all INPUT traffic is accepted on tailscale0..."
if iptables -C INPUT -i tailscale0 -j ACCEPT 2>/dev/null; then
  echo "[INFO] ACCEPT INPUT rule already exists on tailscale0"
else
  echo "[INFO] Adding ACCEPT INPUT rule for all traffic on tailscale0"
  iptables -I INPUT -i tailscale0 -j ACCEPT
fi

echo "[INFO] Ensuring all OUTPUT traffic is accepted on tailscale0..."
if iptables -C OUTPUT -o tailscale0 -j ACCEPT 2>/dev/null; then
  echo "[INFO] ACCEPT OUTPUT rule already exists on tailscale0"
else
  echo "[INFO] Adding ACCEPT OUTPUT rule for all traffic on tailscale0"
  iptables -I OUTPUT -o tailscale0 -j ACCEPT
fi

echo "[INFO] Ensuring all FORWARD ingress traffic is accepted on tailscale0..."
if iptables -C FORWARD -i tailscale0 -j ACCEPT 2>/dev/null; then
  echo "[INFO] ACCEPT FORWARD ingress rule already exists on tailscale0"
else
  echo "[INFO] Adding ACCEPT FORWARD ingress rule for all traffic on tailscale0"
  iptables -I FORWARD -i tailscale0 -j ACCEPT
fi

echo "[INFO] Ensuring all FORWARD egresstraffic is accepted on tailscale0..."
if iptables -C FORWARD -o tailscale0 -j ACCEPT 2>/dev/null; then
  echo "[INFO] ACCEPT FORWARD egress rule already exists on tailscale0"
else
  echo "[INFO] Adding ACCEPT FORWARD egress rule for all traffic on tailscale0"
  iptables -I FORWARD -o tailscale0 -j ACCEPT
fi

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

echo "----- $(date) Tailscale Exit Node Network  Setup Complete -----"