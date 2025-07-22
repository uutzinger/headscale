#!/bin/bash

echo "🔐 Headscale Preauth Key Generator"
echo "=================================="

# List users in a table
echo -e "\n📋 Available Users:"
docker exec headscale headscale users list | column -t

# Prompt for username (safer than numeric ID)
read -rp $'\n👤 Enter the username to generate a preauth key for: ' USERNAME

# Confirm user exists
if ! docker exec headscale headscale users list | grep -q "\"$USERNAME\""; then
    echo "❌ Error: User '$USERNAME' not found. Please check the name and try again."
    exit 1
fi

# Prompt for key expiration time
read -rp $'\n⏳ Enter expiration time (e.g., 1h, 2d): ' EXPIRATION
EXPIRATION=${EXPIRATION:-1h}  # Default to 1 hour if empty

# Generate preauth key
echo -e "\n🔑 Generating ephemeral, single-use preauth key..."
docker exec headscale \
  headscale preauthkeys create \
    --user "$USERNAME" \
    --ephemeral \
    --reusable=false \
    --expiration "$EXPIRATION"

echo -e "\n✅ Done. Use the above key on the new device."
