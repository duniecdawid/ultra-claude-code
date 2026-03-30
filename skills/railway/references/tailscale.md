# Tailscale Subnet Router

Deploy a Tailscale subnet router as a Railway service to give any tailnet device secure private access to all Railway internal services (`*.railway.internal`) without exposing them publicly.

Railway's private networking uses the `fd12::/16` IPv6 prefix and also resolves `*.railway.internal` to IPv4 addresses in the `10.169.0.0/16` range. A subnet router advertises routes to your tailnet so any device on the tailnet can reach Railway internal services directly.

**Important:** Only advertise `fd12::/16` in `TS_ROUTES`. Do NOT add Railway's IPv4 range — it overlaps with common LAN subnets (10.x.x.x) and can hijack traffic on client devices that use `--accept-routes`. IPv6-only routing works because Railway DNS returns both AAAA and A records, and the subnet router handles IPv6 forwarding natively.

## Deployment

Deploy the official Tailscale Docker image as a Railway service:

- **Image:** `tailscale/tailscale:stable`
- **Volume:** `/var/lib/tailscale` — persistent state survives redeployments

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `TS_AUTHKEY` | OAuth client secret (see below) | Authenticates the node to your tailnet |
| `TS_ROUTES` | `fd12::/16` | Advertises Railway's private network to the tailnet. **IPv6 only** — do not add IPv4 ranges (see warning above) |
| `TS_HOSTNAME` | e.g. `anirec-router` | Machine name visible in Tailscale admin |
| `TS_STATE_DIR` | `/var/lib/tailscale` | Persists node identity across restarts (must match volume mount) |
| `TS_USERSPACE` | `true` | Userspace networking — required on Railway (no NET_ADMIN/tun access) |
| `TS_ACCEPT_DNS` | `true` | Accept DNS config from Tailscale admin (needed for split DNS) |
| `TS_AUTH_ONCE` | `true` | Only authenticate on first run — reuses stored state after that |
| `TS_EXTRA_ARGS` | `--advertise-tags=tag:container` | **Required** when using OAuth client secret as `TS_AUTHKEY` — tells Tailscale which ACL tag to assign the node |

### Railway Setup

```bash
# 1. Add the service (use Railway dashboard or CLI)
#    Image: tailscale/tailscale:stable
#    Service name: ts-router (or similar)

# 2. Add a persistent volume mounted at /var/lib/tailscale

# 3. Set all environment variables listed above
#    TS_AUTHKEY comes from the OAuth client (next section)

# 4. Deploy — the container will authenticate and advertise routes
```

## OAuth Client Setup (Preferred over Auth Keys)

OAuth clients are preferred because they **never expire** — unlike auth keys which have a maximum 90-day lifetime.

### Steps

1. Go to **Tailscale Admin Console** → **Settings** → **OAuth Clients**
2. Click **Generate OAuth Client**
3. Set scopes:
   - **Auth Keys** → **Write** (required — the container generates an auth key internally via the OAuth secret)
   - **Devices** → **Core**, **Posture Attributes**, **Routes**, **Device Invites** → all **Write**
4. Under **Tags**, add: `tag:container`
   - This tag must exist in your ACL policy. If it doesn't, add it:
     ```json
     "tagOwners": {
       "tag:container": ["autogroup:admin"]
     }
     ```
5. Click **Generate**
6. Copy the **Client Secret** — this is your `TS_AUTHKEY` value
7. Store it as a Railway variable on the ts-router service

The OAuth client ID is not needed for `TS_AUTHKEY` — only the secret.

## Split DNS

Split DNS makes `*.railway.internal` names resolve from any tailnet device by routing those queries to Railway's internal DNS server.

### Steps

1. Go to **Tailscale Admin Console** → **DNS**
2. Under **Nameservers**, click **Add Nameserver** → **Custom**
3. Enter nameserver: `fd12::10` (Railway's internal DNS resolver)
4. Check **Restrict to domain**
5. Enter domain: `railway.internal`
6. Save

After this, any tailnet device can resolve names like `neo4j.railway.internal` or `redis.railway.internal` — queries for `*.railway.internal` go through the subnet router to Railway's DNS, while all other DNS queries use your normal resolver.

## Route Approval

Tailscale requires explicit approval of advertised subnet routes for security.

### Steps

1. Go to **Tailscale Admin Console** → **Machines**
2. Find the router node (e.g. `anirec-router`)
3. Click the **...** menu → **Edit route settings**
4. Approve the `fd12::/16` route
5. Save

**After changing `TS_ROUTES`:** The service redeploys and advertises the new route set, but changed routes need re-approval in the admin console. Check Machines → router node → Edit route settings and approve any unapproved routes.

Alternatively, if your ACL policy has `autoApprovers`, you can pre-approve (avoids manual re-approval after route changes):

```json
"autoApprovers": {
  "routes": {
    "fd12::/16": ["tag:container"]
  }
}
```

## Client Device Setup

Each tailnet device that needs to reach Railway services must accept subnet routes — this is not enabled by default.

- **macOS/Windows:** Tailscale client → Preferences/Settings → enable **"Use Tailscale subnets"**
- **Linux CLI:** `tailscale set --accept-routes`

Without this, the device ignores the `fd12::/16` route advertisement and `*.railway.internal` addresses won't be reachable even though the router is working.

### Route Conflicts with `--accept-routes`

**Problem:** `--accept-routes` is all-or-nothing — it accepts routes from every node on the tailnet, not just the Railway router. If other tailnet nodes (e.g. a home server, NAS) advertise subnet routes that overlap with the client's local network, return traffic gets misrouted through Tailscale instead of the local interface.

**How to diagnose:** Check Tailscale's routing table (Linux table 52) for routes that overlap with the local network:

```bash
# Show all Tailscale-managed routes
ip route show table 52

# Check which peer advertises a conflicting route
tailscale status --json | node -e "
const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
for (const [k,v] of Object.entries(d.Peer||{})) {
  const routes = v.AllowedIPs || [];
  console.log(v.HostName, '→', routes.filter(r => !r.startsWith('100.') && !r.startsWith('fd7a:')));
}
" | grep -v '→ \[\]'
```

**Example:** A VM on `10.10.21.57` loses connectivity from the host because another tailnet node advertises `10.10.21.0/24`. The VM's return traffic to `10.10.21.x` goes through Tailscale instead of out the local interface.

**Fix — strip conflicting routes on the client:** Since Tailscale doesn't support per-route accept/reject, remove conflicting routes from routing table 52 after Tailscale starts:

```bash
# Immediate fix
sudo ip route del 10.10.21.0/24 dev tailscale0 table 52

# Permanent fix — systemd service that runs after Tailscale
# Install the fix script to /usr/local/bin/fix-tailscale-routes.sh:
#!/bin/bash
sleep 3
ip route del 10.10.21.0/24 dev tailscale0 table 52 2>/dev/null || true
ip route del 10.10.20.0/24 dev tailscale0 table 52 2>/dev/null || true

# Create systemd service:
# /etc/systemd/system/tailscale-route-fix.service
[Unit]
Description=Remove conflicting Tailscale subnet routes
After=tailscaled.service
Requires=tailscaled.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fix-tailscale-routes.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

**Alternative:** Disable the conflicting route on the advertising node via Tailscale Admin Console → Machines → node → Edit route settings → uncheck the overlapping route. Only works if you control that node and it doesn't need the route for other peers.

## Userspace Mode (Required on Railway)

Railway's container runtime does **not** grant `NET_ADMIN` capability or `/dev/net/tun` access. You **must** set `TS_USERSPACE=true` — this is already the default in the env vars table above.

Userspace mode runs Tailscale entirely in userspace with slightly more CPU overhead but works without any special capabilities. Everything else (routes, DNS, auth) works the same as kernel mode.

If you see `unable to create tuntap device file: operation not permitted` in the logs, it means `TS_USERSPACE` is not set to `true`.

## Multi-Project Model

Railway's private network uses a single `fd12::/16` prefix shared across all projects in an account. This means **only one subnet router should be active at a time** — if multiple routers advertise the same `fd12::/16` route, Tailscale can't distinguish which project's services you're trying to reach.

### Switching Between Projects

To switch which project's internal services are accessible:

1. **Disable routes on the current router:**
   - Tailscale Admin Console → Machines → current router → Edit route settings → uncheck `fd12::/16`
   - Or: remove/stop the ts-router service in the current Railway project

2. **Enable routes on the new router:**
   - Tailscale Admin Console → Machines → new router → Edit route settings → approve `fd12::/16`
   - Or: deploy/start the ts-router service in the target Railway project

3. **Update config** — the `tailscale` block in `~/.config/railway-cli/config.json` tracks which project has the active router (see `references/config.md`)

### Why Not Multiple Active Routers?

Each Railway project has its own `fd12::/16` network with different services. If two routers advertise the same prefix, Tailscale uses DERP-based routing and may send traffic to the wrong project. To support simultaneous multi-project access, you'd need per-project subnet slicing (e.g. `fd12:1::/32` per project), which Railway doesn't support.

## Troubleshooting

### Auth Failures

**Symptoms:** Container restarts repeatedly, logs show "auth failed" or "unauthorized"

- Verify `TS_AUTHKEY` is set correctly (OAuth client secret, not client ID)
- Check the OAuth client still exists in Tailscale Admin Console
- Ensure the `tag:container` tag is defined in your ACL policy
- If using `TS_AUTH_ONCE=true` and auth state is corrupted, delete the volume and redeploy

### Route Not Approved

**Symptoms:** Router is online in Tailscale admin but `*.railway.internal` not reachable

- Check Machines → router node → verify `fd12::/16` is approved (not just advertised)
- Ensure no other router is advertising the same `fd12::/16` route

### DNS Not Resolving

**Symptoms:** `dig neo4j.railway.internal` returns `NXDOMAIN` or times out

- Verify split DNS is configured: DNS → Nameservers → `fd12::10` restricted to `railway.internal`
- Ensure `TS_ACCEPT_DNS=true` on the router
- Test from a tailnet device (not the router itself): `dig neo4j.railway.internal`
- Check that the target service actually has private networking enabled in Railway

### Service Not Reachable (but DNS resolves)

**Symptoms:** `dig` returns an address but `curl`/`nc` times out or connection refused

- Ensure the client device has accepted subnet routes (see Client Device Setup above)
- Check the target service is listening on `::` (all interfaces), not just `127.0.0.1`. Railway-managed databases already listen on `::`. Custom services may need configuration (e.g. `HOST=::` or `--host 0.0.0.0`)
- For legacy environments (created before October 2025), `*.railway.internal` resolves to IPv6 only — ensure your client supports IPv6

### Connectivity Test Commands

```bash
# Check if the router is reachable from your device
tailscale ping <router-hostname>

# Check router status and advertised routes
tailscale status

# Verify client accepts subnet routes
tailscale status --json | grep -A2 "AllowsSubnetRoutes"

# Test DNS resolution (from a tailnet device)
dig neo4j.railway.internal
dig +short redis.railway.internal

# Test actual connectivity
curl -v telnet://neo4j.railway.internal:7687
nc -zv neo4j.railway.internal 7687
```
