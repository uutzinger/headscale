docker exec headscale headscale users list

docker exec headscale \
  headscale preauthkeys create \
    --user 2 \
    --ephemeral \
    --reusable=false \
    --expiration 1h
