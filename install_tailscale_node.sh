#!/bin/bash

set -e

echo "[INFO] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

echo "[INFO] Enabling UFW..."
sudo ufw enable || true

echo "[INFO] Adding UFW rules for Tailscale..."
# Allow all traffic over tailscale interface
echo "tailscale0..."
sudo ufw allow in on tailscale0
sudo ufw allow out on tailscale0

# Allow access to the Tailscale subnet (100.64.0.0/10)
echo "109.64.0.0..."
sudo ufw allow from 100.64.0.0/10

# Allow HTTPS (Headscale coordination server)
# echo "headscale.utzinger.us port 443 and 80"
# sudo ufw allow out to headscale.utzinger.us port 443 proto tcp
# sudo ufw allow out to headscale.utzinger.us port 80 proto tcp

# Optional: Allow local LAN access
# echo "192.168.16.0"
# sudo ufw allow from 192.168.16.0/24

echo "[INFO] UFW verbose"
sudo ufw status verbose

# echo "[INFO] Enabling IP forwarding (just in case any routing is needed later)..."
# sudo sysctl -w net.ipv4.ip_forward=1
# sudo sysctl -w net.ipv6.conf.all.forwarding=1

# sudo grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || \
#   echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
# sudo grep -q '^net.ipv6.conf.all.forwarding=1' /etc/sysctl.conf || \
#   echo 'net.ipv6.conf.all.forwarding=1' | sudo tee -a /etc/sysctl.conf

echo "[INFO] Starting Tailscale and authenticating..."

# Start Tailscale
read -rp "Enter your Tailscale auth key: " TAILSCALE_AUTHKEY

if [ -z "$TAILSCALE_AUTHKEY" ]; then
  echo "[ERROR] TAILSCALE_AUTHKEY is not set. Exiting."
  exit 1
fi

echo "[INFO] Starting Tailscale and authenticating..."

if sudo tailscale up \
  --authkey "$TAILSCALE_AUTHKEY" \
  --hostname pop-os \
  --login-server=https://headscale.something \
  --operator=<your-username-in ubuntu> \
  --accept-routes \
  --accept-dns=true \
  --reset; then
  echo "[INFO] Tailscale brought up successfully"
else
  echo "[WARN] Tailscale may already be running or failed to start"
fi 

echo "Laptop installation complete. Approve routes via Headscale if needed."
