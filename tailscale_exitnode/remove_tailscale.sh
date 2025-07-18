#!/bin/bash

set -e

echo "[INFO] Logging out of Tailscale..."
sudo tailscale logout || echo "[WARN] Already logged out or error"

echo "[INFO] Shutting down Tailscale..."
sudo tailscale down || echo "[WARN] Tailscale not running or already down"

echo "[INFO] Stopping tailscaled service..."
sudo systemctl stop tailscaled

echo "[INFO] Removing Tailscale state..."
if [ -d /var/lib/tailscale ]; then
  sudo rm -rf /var/lib/tailscale
  echo "[OK] Removed /var/lib/tailscale"
elif [ -d /etc/tailscale ]; then
  sudo rm -rf /etc/tailscale
  echo "[OK] Removed /etc/tailscale"
else
  echo "[INFO] No Tailscale state directory found"
fi

echo "[DONE] Tailscale client reset complete. You can now re-authenticate with a new auth key."
