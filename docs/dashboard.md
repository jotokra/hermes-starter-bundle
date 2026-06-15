# Web Dashboard — LAN-only setup

The Hermes web dashboard is a browser-based admin panel for managing
your Hermes install: providers, models, API keys, MCP servers, the
gateway, sessions, logs, skills, and more. It's a built-in feature
of the agent — no separate install, just `hermes dashboard` and a
browser tab.

This document covers the **LAN-only setup** (the only safe default
for a starter-bundle user). For OAuth / public-internet exposure,
read the upstream docs and proceed with extreme caution.

## What you get

A single web server (built on the agent's own FastAPI + Vite SPA)
that exposes:

- **Providers + API keys** — add/edit providers, paste keys, see which
  model is the active default. (Reads + writes `~/.hermes/auth.json`.)
- **Models** — model picker, reasoning-effort slider, fallback chain.
- **Toolsets + MCP** — see what's installed, enable/disable, add a
  new MCP server.
- **Gateway** — start/stop the messaging gateway, see connected
  platforms, view per-platform channel configs.
- **Sessions** — list active + past sessions, jump back into one.
- **Logs** — tail `agent.log`, `errors.log`, gateway log.
- **Cron** — list scheduled jobs, run one ad-hoc, pause/resume.
- **Skills** — browse installed skills, see descriptions, install
  from the catalog.
- **Profile switcher** — if you have more than one profile, the
  sidebar lets you switch which profile the read/write pages
  target. Stays in the URL (`?profile=<name>`) so deep links survive
  refresh.

It's a **machine-level** management surface: one server manages
every profile on the box. The profile switcher is a UI choice, not
a separate server per profile.

## Quick start (loopback only — the default)

```bash
hermes dashboard
# → opens http://127.0.0.1:9119 in your browser
```

If you ran the bundle's `install.sh` and accepted the dashboard
prompt, the .env file already has basic-auth credentials and the
dashboard is running in the background. Just open the URL.

To start it manually:

```bash
hermes dashboard --no-open --host 127.0.0.1 --port 9119 &
# Log: tail -f ~/.hermes/logs/dashboard.log
```

Stop / restart / status:

```bash
hermes dashboard --stop
hermes dashboard --status
# `hermes dashboard --status` is misleading (shows multiple PIDs even
# when only one is serving). Verify with:
lsof -nP -iTCP:9119 -sTCP:LISTEN
```

## Quick start (LAN access from another device)

This is the typical home-LAN setup: dashboard on the Mac mini,
MacBook (or iPad, phone) on the same Wi-Fi visits it via
`http://your-host.local:9119` or `http://your-lan-ip:9119`.

```bash
# Bind to all interfaces. Required for LAN access.
hermes dashboard --no-open --host 0.0.0.0 --port 9119
```

**LAN access requires auth.** The dashboard auto-engages basic
auth when binding non-loopback. Set these three env vars in
`~/.hermes/.env` (mode 0600) before starting:

```bash
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=<<your-username>>
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=***HERMES_DASHBOARD_BASIC_AUTH_SECRET=***r -dc 'A-Za-z0-9' </dev/urandom | head -c 48)
chmod 600 ~/.hermes/.env
```

The install script can generate these for you automatically (just
answer "yes" to the dashboard prompt). Save the password to your
password manager — the install script will print it once on stdout.

**Restart the dashboard** to pick up the new env vars (the agent
reads them on startup, not per-request):

```bash
hermes dashboard --stop
hermes dashboard --no-open --host 0.0.0.0 --port 9119 &
```

## How to use from another LAN device

1. **mDNS hostname (preferred):** `http://<your-host>.local:9119`
   Most home routers + macOS machines handle `.local` resolution
   automatically. On Linux, install `avahi-daemon`; on Windows, the
   equivalent is built in.
2. **LAN IP (fallback):** `http://<your-lan-ip>:9119`. Find your
   LAN IP with `ipconfig getifaddr en0` (macOS) or `hostname -I`
   (Linux). Note: this can change if your router's DHCP lease
   rotates the address.

You'll see a "Sign in — Hermes Agent" page. Enter the username
and password from your `.env`. The session is two HttpOnly cookies
(an access token + a refresh token), signed with
`HERMES_DASHBOARD_BASIC_AUTH_SECRET`. They survive restarts (the
secret is stable); change the secret and all sessions invalidate.

## Why this is safe on the LAN

- **The dashboard is bound to `0.0.0.0:9119`** — your home router's
  NAT blocks inbound traffic from the public internet, so nothing
  outside your `192.168.x.x` (or `10.x.x.x`) network can reach it.
- **The auth gate engages automatically** when binding
  non-loopback. The Hermes built-in basic-auth provider is on by
  default.
- **Plain HTTP** on the LAN is acceptable for home Wi-Fi. If you
  need TLS, front it with nginx + certs (not covered here; the
  Hermes reverse-proxy example is in
  `~/.hermes/hermes-agent/website/docs/`).
- **The cookie session is HttpOnly and signed.** The browser won't
  expose the cookies to injected JavaScript; the signature prevents
  tampering.

## What this is NOT safe for

- **Public internet exposure.** The basic-auth provider is fine
  for trusted LANs, not for the open internet. For public
  exposure, the upstream docs recommend OAuth (Nous Portal) +
  a proper TLS-terminating reverse proxy. Don't run
  `hermes dashboard --host 0.0.0.0` on a machine with a
  public IP unless you know exactly what you're doing.
- **Untrusted Wi-Fi (cafes, hotels, conferences).** Even with auth,
  plain HTTP on a hostile network is a bad idea. Use a VPN
  (Tailscale, WireGuard) or just run the dashboard on loopback
  only (`--host 127.0.0.1`) and SSH-tunnel in.

## Common tasks

```bash
# Check it's running
hermes dashboard --status
# (the --status output is misleading; verify with lsof -nP -iTCP:9119)

# Stop it
hermes dashboard --stop

# Restart (after env-var change or config edit)
hermes dashboard --stop
hermes dashboard --no-open --host 0.0.0.0 --port 9119 &

# Change the password
# 1. Edit ~/.hermes/.env, update HERMES_DASHBOARD_BASIC_AUTH_PASSWORD
# 2. Restart the dashboard (env vars are read at startup, not per-request)
# 3. Sessions survive the password change as long as the SECRET doesn't

# Tail the log
tail -f ~/.hermes/logs/dashboard.log
```

## Gotchas

- **No auto-restart on reboot.** The dashboard was started manually
  in a background process. To survive reboots, register a launchd
  plist (macOS) or systemd user unit (Linux). The agent's
  `hermes gateway install` does this for the gateway; the
  dashboard doesn't have an equivalent built-in yet.
- **Cookies, not basic auth.** The login form POSTs JSON to
  `/auth/password-login` and gets back two HttpOnly cookies. Don't
  confuse "I'm sending basic auth" (you aren't, except as a
  pre-401 browser prompt for some clients) with "I'm using a
  cookie session."
- **The secret is load-bearing.** Change
  `HERMES_DASHBOARD_BASIC_AUTH_SECRET` and every active session
  immediately invalidates. Treat it like a JWT signing key: keep
  it stable, back it up, and only rotate on user-logout-everyone
  events.
- **`--status` is misleading.** It can show multiple PIDs even
  when only one is serving. Use `lsof -nP -iTCP:9119 -sTCP:LISTEN`
  to see the real process bound to the port.
- **DHCP may change the LAN IP.** If the mini's IP rotates, your
  `http://192.168.x.x:9119` bookmark breaks. mDNS (`<host>.local`)
  is more stable but not guaranteed; for permanent bookmarks, set
  a DHCP reservation on your router.
- **LAN access requires `--host 0.0.0.0`.** The default
  `--host 127.0.0.1` is loopback only. The install script's
  default is `127.0.0.1` for safety; the user has to opt in
  to LAN access by editing the start command.

## Verifying a clean install

After `install.sh` finishes (and you accepted the dashboard
prompt), verify:

```bash
# 1. The dashboard is running
lsof -nP -iTCP:9119 -sTCP:LISTEN
# Expected: one process listed, bound to *:9119 (or 127.0.0.1:9119)

# 2. The auth env vars are set
grep HERMES_DASHBOARD_ ~/.hermes/.env
# Expected: three lines, all values non-empty

# 3. The .env is chmod 600
ls -la ~/.hermes/.env
# Expected: -rw------- ... .env

# 4. The browser can reach it
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9119/
# Expected: 200, or 302 (redirect to /login)

# 5. The browser can sign in
# Open http://127.0.0.1:9119 in a browser, enter the username + password
# from .env. You should land on the dashboard home.
```

## See also

- Upstream docs: `~/.hermes/hermes-agent/website/docs/user-guide/features/web-dashboard.md`
- Upstream extension guide: `~/.hermes/hermes-agent/website/docs/user-guide/features/extending-the-dashboard.md`
- Hermes CLI subcommand: `hermes dashboard --help` (for flags + options)
- The bundle's `install.sh` — section 10b, the dashboard prompt +
  auto-setup. Skim lines ~430-500 of the install script.
- `docs/configuration.md` — the `dashboard:` block in `config.yaml`,
  including the env-var-override pattern (config values are
  placeholders; .env values take precedence at runtime).
