#!/bin/bash

echo "🧠 Headscale Node Overview"
echo "=========================="

echo ""
echo "🔍 Listing available Nodes:"
docker exec headscale headscale nodes list \
|| echo "❌ Failed to fetch nodes"

echo ""
echo "📣 Available Routes:"
docker exec headscale headscale nodes list-routes \
|| echo "❌ Failed to fetch routes"

echo ""
echo "🔍 Available Users:"
docker exec headscale headscale users list

echo ""
echo "ℹ️  ACL Policy:"
docker exec headscale headscale policy get

echo ""
echo "ℹ️ Headscale Server Info:"
docker exec headscale headscale version \
|| echo "❌ Failed to fetch version"
