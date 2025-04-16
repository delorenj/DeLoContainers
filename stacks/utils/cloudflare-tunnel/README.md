# Cloudflare Tunnel Setup

This stack sets up Cloudflare Tunnel (formerly Argo Tunnel) to securely connect your home server to Cloudflare without exposing your home IP address.

## Benefits

- **No Open Ports**: No need to open ports in your firewall/router
- **IP Protection**: Your home IP address remains hidden
- **SSL Everywhere**: Automatic HTTPS with Cloudflare's SSL
- **DDoS Protection**: Cloudflare's protection shields your home network
- **Works with Dynamic IPs**: Even if your ISP changes your IP address

## Setup Instructions

1. **Sign in to Cloudflare Dashboard**: https://dash.cloudflare.com

2. **Create a Tunnel**:
   - Go to "Zero Trust" > "Access" > "Tunnels"
   - Click "Create a tunnel"
   - Name your tunnel (e.g., "DeLoHomeServer")
   - Copy the token provided (you'll need it in step 4)

3. **Configure DNS for your applications**:
   - In the tunnel configuration, add public hostnames:
     - Add `delo.sh` pointing to `localhost:80`
     - Add `traefik.delo.sh` pointing to `localhost:80`
     - Add `lms.delo.sh` pointing to `localhost:80`
     - Add `draw.delo.sh` pointing to `localhost:80`
     - Add `sync.delo.sh` pointing to `localhost:80`
     - (Add any other subdomains you need)

4. **Set environment variable**:
   - Add to your `.env` file in the DeLoContainers root:
     ```
     CLOUDFLARE_TUNNEL_TOKEN=your-tunnel-token-here
     ```

5. **Start the tunnel**:
   ```bash
   cd /home/delorenj/code/DeLoContainers
   docker compose -f stacks/cloudflare-tunnel/compose.yml up -d
   ```

6. **Update your Traefik configuration**:
   Since Cloudflare Tunnel will be handling the SSL termination, you need to make sure Traefik is configured to work with it.
   
   Add the following to your Traefik config in dynamic/config.yml to trust Cloudflare IPs:

   ```yaml
   middlewares:
     cloudflare-ip-whitelist:
       ipWhiteList:
         sourceRange:
           - 173.245.48.0/20
           - 103.21.244.0/22
           - 103.22.200.0/22
           - 103.31.4.0/22
           - 141.101.64.0/18
           - 108.162.192.0/18
           - 190.93.240.0/20
           - 188.114.96.0/20
           - 197.234.240.0/22
           - 198.41.128.0/17
           - 162.158.0.0/15
           - 104.16.0.0/13
           - 104.24.0.0/14
           - 172.64.0.0/13
           - 131.0.72.0/22
   ```

7. **Testing**:
   - Go to your domain (e.g., `https://delo.sh`) in a browser
   - Check Cloudflare Tunnel logs: `docker logs cloudflared`

## Troubleshooting

- **Tunnel not connecting**: Check the token is correct and the container logs
- **Website not loading**: Verify your DNS entries in Cloudflare and check that the Traefik routes are correctly configured
- **Certificate errors**: Make sure SSL is set to "Full" or "Full (Strict)" in Cloudflare SSL/TLS settings

## Maintenance

- Cloudflare Tunnel automatically updates when you restart the container 
- Periodically check the Cloudflare dashboard for any needed configuration changes
