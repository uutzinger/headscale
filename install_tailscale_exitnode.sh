#!/bin/bash

set -e

# Install
echo "[INFO] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale service
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

# Enable IP forwarding no persistent
echo "[INFO] Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Enable ipv4_forwarding permanently
if grep -q '^\s*#\?\s*net\.ipv4\.ip_forward\s*=' /etc/sysctl.conf; then
  echo "[INFO] Updating existing net.ipv4.ip_forward=1 line..."
  sudo sed -i 's|^\s*#\?\s*net\.ipv4\.ip_forward\s*=.*|net.ipv4.ip_forward=1|' /etc/sysctl.conf
else
  echo "[INFO] Adding net.ipv4.ip_forward=1 to sysctl.conf"
  echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
fi

# Enable ipv6 forward permanently
if grep -q '^\s*#\?\s*net\.ipv6\.conf\.all\.forwarding\s*=' /etc/sysctl.conf; then
  echo "[INFO] Updating existing net.ipv6.conf.all.forwarding=1 line..."
  sudo sed -i 's|^\s*#\?\s*net\.ipv6\.conf\.all\.forwarding\s*=.*|net.ipv6.conf.all.forwarding=1|' /etc/sysctl.conf
else
  echo "[INFO] Adding net.ipv6.conf.all.forwarding=1 to sysctl.conf"
  echo 'net.ipv6.conf.all.forwarding=1' | sudo tee -a /etc/sysctl.conf
fi

# Disable Firewalls
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

echo "[INFO] Installing iptables-persistent if needed..."
sudo apt-get install -y iptables-persistent

echo "[INFO] Saving iptables rules..."
sudo netfilter-persistent save

# Start Tailscale
read -rp "Enter your Tailscale auth key: " TAILSCALE_AUTHKEY

if [ -z "$TAILSCALE_AUTHKEY" ]; then
  echo "[ERROR] TAILSCALE_AUTHKEY is not set. Exiting."
  exit 1
fi

echo "[INFO] Bringing up Tailscale..."

if sudo tailscale up \
  --authkey "$TAILSCALE_AUTHKEY" \
  --advertise-routes=192.168.something.0/24 \ # your home network
  --advertise-exit-node \
  --snat-subnet-routes=true \
  --accept-routes=true \
  --hostname tailscale \
  --login-server=https://headscale.something \ # your pulic internet address
  --operator=<username> \ # your current system username in ubuntu
  --stateful-filtering=true \
  --accept-dns=true; then
  echo "[OK] Tailscale brought up successfully."
else
  echo "[WARN] Tailscale may already be running or failed to start"
fi

echo "Exit node installation complete. Approve routes via Headscale if needed."
