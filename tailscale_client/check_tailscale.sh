#!/bin/bash

echo "🔍 Checking Allowed IPs for this node:"
tailscale status --json | jq '.Self.AllowedIPs' || echo "❌ Failed to fetch AllowedIPs"

echo ""
echo "📣 Advertised Routes (from debug prefs):"
tailscale debug prefs | jq '.AdvertiseRoutes' || echo "❌ Failed to fetch AdvertiseRoutes"

echo ""
echo "🧭 Available Exit Nodes:"
tailscale status --json | jq '.Peer[] | select(.ExitNodeOption == true) | {DNSName, AllowedIPs}' || echo "❌ Failed to fetch Peer info"
