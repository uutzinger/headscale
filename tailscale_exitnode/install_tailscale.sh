#!/bin/bash

set -e

echo "[INFO] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

echo "[INFO] Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

sudo grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || \
  echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo grep -q '^net.ipv6.conf.all.forwarding=1' /etc/sysctl.conf || \
  echo 'net.ipv6.conf.all.forwarding=1' | sudo tee -a /etc/sysctl.conf

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


echo "[INFO] Setting up NAT (masquerading)..."
IFACE=$(ip route get 8.8.8.8 | awk '{ print $5; exit }')
# Check if rule already exists and create it if not
if ! sudo iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null; then
  sudo iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
fi

echo "[INFO] Installing iptables-persistent if needed..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent

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
  --advertise-routes=192.168.16.0/24 \ # your home network
  --advertise-exit-node \
  --snat-subnet-routes=true \
  --accept-routes=true \
  --hostname tailscale \
  --login-server=https://headscale.something.us \ # your pulic internet address
  --operator=uutzinger \
  --stateful-filtering=true \
  --accept-dns=true; then
  echo "[OK] Tailscale brought up successfully."
else
  echo "[WARN] Tailscale may already be running or failed to start"
fi

echo "Exit node installation complete. Approve routes via Headscale if needed."
