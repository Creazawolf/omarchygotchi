# Alternative Python community server

Version 3.0 defaults to a deployed Cloudflare community. This guide describes the optional Python server for independent communities. Everyone must connect to the **same HTTPS server** to meet each other. Offline adventures and server-side roaming are Cloudflare-backend features; this Python alternative retains online-only encounters.

This legacy server does not implement 3.0 shared scenes, relationship memory, romance, or families. Its responses omit those capabilities, so the plugin hides the corresponding controls. Use the Cloudflare backend for the full product.

## Local development

Python 3 is the only server dependency. From the plugin directory:

```sh
python3 community/server.py --database /tmp/creature-community.sqlite3
```

Enter `http://127.0.0.1:8765` in the Community tab and select Connect. A single client sees an empty park until another client connects. Automated tests create two separate identities and verify the full encounter and friendship flow:

```sh
python3 -m unittest discover -s community -v
node community/test_sim.cjs
```

## Hosting for your community

Run the server as a dedicated unprivileged account with a private persistent working directory. Keep its default loopback binding and put a TLS reverse proxy in front of port 8765. Configure a real domain and HTTPS certificate, request body limits of 4 KB, connection timeouts, and per-source connection limits at the proxy. Do not cache API responses or log Authorization headers. The built-in server is a small-community implementation with serial request handling, not a high-volume hosting platform.

Example service unit (adjust paths to your installation):

```ini
[Unit]
Description=Omarchy Creature Community
After=network.target

[Service]
User=creature-community
WorkingDirectory=/var/lib/creature-community
ExecStart=/usr/bin/python3 /opt/creature-community/server.py --database /var/lib/creature-community/community.sqlite3
Restart=on-failure
UMask=0077
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/creature-community

[Install]
WantedBy=multi-user.target
```

Back up the SQLite database while the service is stopped. Keep the server address stable: client identities belong to one exact server origin. There is no account recovery; losing a local identity file loses access to that profile. Set up operator contact details and moderation before opening registration to the public. User blocking and profile deletion are included; an operator moderation dashboard and abuse reporting are not yet included. Registration is limited by the direct peer address, so a reverse proxy shares one registration allowance (10/hour); enforce source-IP limits at the proxy and tune this before wider launch.

## Behavior and privacy

- Explicit Connect creates an identity and publishes only creature name, appearance seed, life stage, and availability. A connected, healthy, awake, hatched creature can receive random playdates. Disconnect withdraws it; a failed disconnect expires its presence after two minutes.
- Each playdate is a server-recorded shared adventure, shown in both journals. It is not a real-time synchronized movement game. No creatures are invented when the park is empty.
- Auto-roam initiates an encounter about every six minutes. Both participants have a five-minute cooldown. Requests are manual, limited to creatures already encountered, and require acceptance.
- Friends can visit when both creatures are available. Decline, cancel, unfriend, block, unblock and delete-profile controls are included.
- Visits are retained for 30 days and the most recent 30 appear in each journal. Friendships persist until removed. Profile deletion removes that identity, its links and its visits from the server.
- Client bearer credentials stay in mode-0600 files under `~/.local/state/omarchy/tamagotchi-community/`, never QML settings or command arguments. The server stores token hashes. Only HTTPS is accepted remotely, and redirects are refused to protect credentials.
- Window titles, agent activity, track names, local save files and system usernames are never included in requests. The host still sees connection IP addresses.
- Multiplayer is optional. Gentle care simulation and evolution keep working offline. Playdates do not alter local care meters.

## API

All routes use JSON POST requests under `/v1/`. `register` accepts `name`, `seed`, and `stage` and returns an ID and a bearer token. Other routes require `Authorization: Bearer …`.

`sync` accepts the same public profile plus boolean `discover`. `visit` accepts an optional target ID; omitting it randomly selects an available unblocked creature. `request`, `accept`, `decline`, `remove`, `block`, and `unblock` accept `target`. `offline` withdraws presence; `delete` removes the account. Responses contain friends, incoming/outgoing requests, blocked profiles, recent visits and a status message. Errors use HTTP status codes and an English `error` field.
