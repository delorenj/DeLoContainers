# Node-RED (Bloodbank-ready)

This stack runs Node-RED behind Traefik and includes example flows to integrate with the Bloodbank event system and Fireflies.

## Quick start

```bash
cd /home/delorenj/docker/trunk-main/stacks/apps/node-red
cp .env.example .env
# edit .env

docker compose up -d --build
```

Open `https://nodered.delo.sh` and import the example flow from:

```
/home/delorenj/docker/trunk-main/stacks/apps/node-red/flows/fireflies-bloodbank-example.json
```

## Notes

- The example uses the Bloodbank HTTP publisher (`/events/custom`). Ensure Bloodbank HTTP is reachable from the container.
- Fireflies webhook verification (HMAC signature) is not enforced in the sample flow. Add a signature check before production.
- The flow expects media to be available at `PUBLIC_BASE_URL` after moving into `PUBLIC_DIR`.
