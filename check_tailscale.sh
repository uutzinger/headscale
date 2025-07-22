#!/bin/bash

echo "🔍 Checking Allowed IPs for this node:"
tailscale status --json | jq '.Self.AllowedIPs' || echo "❌ Failed to fetch AllowedIPs"

echo ""
echo "📣 Advertised Routes (from debug prefs):"
tailscale debug prefs | jq '.AdvertiseRoutes' || echo "❌ Failed to fetch AdvertiseRoutes"

echo ""
echo "🧭 Available Exit Nodes:"
tailscale status --json | jq '
  . as $root |
  (if $root.Self.ExitNodeOption == true then
    [{"DNSName": $root.Self.DNSName, "AllowedIPs": $root.Self.AllowedIPs}]
  else
    []
  end
  + 
  ($root.Peer | to_entries | map(
    select(.value.ExitNodeOption == true) | {
      DNSName: .value.DNSName,
      AllowedIPs: .value.AllowedIPs
    }
  ))
)' || echo "❌ Failed to fetch exit nodes"


echo ""
echo "ℹ️ Status:"
tailscale status

echo -e "\n🧠 Tailscale daemon:"
systemctl is-active tailscaled && echo "✅ Running" || echo "❌ Not running"

echo -e "\n🔗 Tailscale network interface:"
ip a show tailscale0

echo -e "\n🔍 DNS Config:"
tailscale status --json | jq '.Self.DNS'

echo -e "\n🔍 Current systemd-resolved DNS:"
resolvectl status tailscale0
