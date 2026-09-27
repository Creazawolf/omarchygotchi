# Omarchy Creature Community · 3.1

Friend codes and park presence are live. Migration `0003_invites.sql` and Worker 3.1.0 were deployed on 27 September 2026 (Europe/Stockholm), after a D1 export backup; the shared-history release (migration `0002_shared_history.sql`, Worker 3.0.0) went out on 15 September 2026.

## Upgrade to 3.1: friend codes and park presence

Apply `migrations/0003_invites.sql`, then deploy the 3.1 Worker. The migration only adds the `invites` table and an index on `pets(seen)`; nothing existing changes. Clients detect the `friendCodes` and `presence` capabilities, so 3.0 clients keep working and 3.1 clients hide friend codes on a 3.0 server.

```sh
npx wrangler d1 migrations apply omarchy-creature-community --remote
npm run deploy
```

Friend codes are eight characters from an alphabet without look-alikes (about 40 bits). The server stores only their SHA-256, each creature has at most one live code, codes expire after seven days, and redeeming is limited to 20 attempts per creature per day on top of the IP and user rate limits. A redeemed code creates a friendship directly: sharing it is one owner's consent and entering it is the other's. Blocks in either direction prevent it.

## Upgrade from 2.1

Apply `migrations/0002_shared_history.sql` before deploying the 3.0 Worker. Migration 0001 remains unchanged. Existing credentials, creatures, visits and friendships survive; retained visits seed durable relationship memory.

```sh
npx wrangler d1 migrations apply omarchy-creature-community --remote
npm run deploy
```

New `/v1/` JSON actions use the existing bearer authentication:

| Action | Payload | Requirements |
|---|---|---|
| `romance` | `target`, boolean `allow` | Adult friends with 3 encounters; both privately opt in |
| `egg-propose` | `target`, `name`, `home` (one parent ID) | Adult sweethearts with 6 encounters; capacity in both households |
| `egg-accept` | `family`, `home` | Other owner agrees to exactly the proposed primary home |
| `egg-cancel` | `family` | Either parent closes an unaccepted proposal |

Snapshots add capability flags `sharedHistory` and `families`, durable `bonds`, and shared `families`. Visits include a 15-minute `until` timestamp and an immutable `scene` with real participants. No old visit is fabricated into a scene. Personality comes from the existing appearance seed. Visit insertion and memory updates share a SQLite transaction; concurrent egg proposals are constrained by SQL and triggers.

One pending/growing child per owner, at most 12 album children per owner. Egg proposals expire after seven days. Accepted children hatch after one day and grow through baby/kid/teen/adult stages at days 1/3/7/14 without server-side care meters. Parents and inherited appearance are snapshotted. Accepted family history survives deletion of a parent in the remaining owner’s album; all other identity-linked friendships, bonds, blocks and visits are removed. Blocking removes social access and cancels pending eggs while preserving already agreed family history.

`npm test` covers consent, races, inheritance, growth, deletion, mature-stage requirements and the Python client contract in addition to the original community tests. `test/runtime-smoke.mjs` exercises the same family flow against actual localhost D1. To isolate that test’s SQL edits, set `TAMA_D1_STATE` to the same path used for Wrangler’s `--persist-to` option.

---

Deployed service: `https://omarchy-creature-community.omarchy-creature-community.workers.dev`


A Cloudflare Worker and persistent D1 database. No home server, tunnel, inbound desktop port, purchased domain, or always-on personal computer is required. The desktop plugin makes outgoing HTTPS requests to the Worker.

## Deploy

Use Node.js 22 or newer and your Cloudflare account. The Worker uses Workers/D1 free-tier-compatible features. Keep your account on Workers Free if you want hard free-tier limits rather than paid overages; inspect the dashboard before deploying. Free tiers are quota-limited, not unlimited hosting.

```sh
npm ci
npx wrangler login --device
npx wrangler d1 create omarchy-creature-community
```

Put the returned `database_id` in `wrangler.jsonc`, replacing the all-zero placeholder. If you have more than one Cloudflare account, also set the chosen `account_id`.

```sh
npx wrangler d1 migrations apply omarchy-creature-community --remote
npm run deploy
```

Wrangler prints the public `https://omarchy-creature-community.YOUR-SUBDOMAIN.workers.dev` address. Use that origin in each plugin's Community tab. Never paste an API token or password into the plugin. You may set that public URL as `serverUrl` in `CommunityDefaults.js` before packaging; this supplies a default but does not connect anyone without consent.

Cron triggers run every 15 minutes; new trigger configuration can take time to propagate. No scheduled task runs on your computer.

## Test

```sh
npm test
npm run check
npx wrangler d1 migrations apply omarchy-creature-community --local
npx wrangler dev --test-scheduled
```

`test/community.test.mjs` exercises the actual SQL against in-memory SQLite, including schema constraints and triggers. The separate local-runtime smoke test uses the real D1 binding and the same HTTPS-client protocol:

```sh
node test/runtime-smoke.mjs http://127.0.0.1:8787
```

Run that only against the disposable local database: it creates two synthetic identities, changes their last-seen timestamps through local SQL for the scheduler test, and deletes those test profiles afterward. Remote smoke testing is limited to creating and removing two explicit test profiles; it does not change real users.

## Behavior

The server schedules optional automatic playdates approximately every six hours per creature. An available partner is required. A manual playdate has a five-minute cooldown; scheduling uses the longer six-hour cooldown. Each cron processes at most 40 eligible creatures (20 successful pairs), favoring those that have waited longest. Larger communities require capacity tuning.

Offline adventures require a separate opt-in. They keep the last shared, eligible creature profile available for seven days after its last sync; reconnecting renews this. Sleep, illness or an unhatched/dead creature causes the client to withdraw availability on the next sync. No offline health simulation runs on Cloudflare. Offline encounters are recorded shared scenes. Only visits still within their 15-minute window render as current guests when an available client reconnects.

Friend requests remain manual and need a real encounter within 30 days. Only the recipient can accept. Blocking applies in both directions. Explicit disconnect revokes online and offline availability. If a disconnect cannot reach the server, the plugin retries and states that it has not been confirmed; simply turning the computer off does not revoke an offline lease.

Background sync is every five minutes, every 30 seconds while the Community panel is open. Presence expires after 15 minutes. Visits expire after 30 days; journals show the newest 30. Up to 100 friendships/pending links and 200 blocks per profile are supported. Initial registration capacity is 1,000 profiles; this is an abuse/storage cap, not a promise that 1,000 active users fit the free quota.

## Security and operation

- The public API accepts bounded JSON objects and fixed action names. It does not execute commands, accept executable code or fetch user-provided URLs.
- Public creature data consists of creature ID, name, appearance seed, stage and availability; authenticated participants also receive their shared relationship and family history. No window titles, local files, system usernames or desktop activity are sent.
- Credentials are random 256-bit bearer secrets. Only SHA-256 token hashes are stored in D1. Desktop credentials stay in private files and are never shell command arguments.
- Rate limits apply per source IP and authenticated identity. IP sharing can affect users behind the same network. Cloudflare edge counters are best-effort per location, supplemented by atomic database daily limits: 10 registrations per IP and 20 friend-request attempts per profile. Registration quota keys contain hashed IPs and expire after two days.
- Conditional SQL and transaction triggers enforce playdate cooldowns under concurrent requests. Foreign keys remove all profile relationships and visits on deletion.
- Application request logging is disabled; Cloudflare still processes network metadata. No service can be described as unhackable. Authentication, input limits, dependency updates, monitoring, backups and operator moderation still matter.
- The backend never opens a network path into a user's computer. The desktop client must still validate the data returned by the service.

To pause new registration, change `REGISTRATION_OPEN` to `"false"` and redeploy. To disable an abusive profile, use the Cloudflare D1 console with its public 32-character creature ID:

```sql
UPDATE pets SET banned=1, discover=0, offline_until=0, auto_roam=0
WHERE id='CREATURE_ID';
```

The profile can no longer authenticate, appear in encounters or be visited. To lift a ban, set `banned=0`; participation resumes after its next valid sync. This release includes blocking and operator bans, but no abuse-reporting dashboard. Establish an operator contact before a broad marketplace launch.

Monitor Workers requests/CPU and D1 rows read/written in the dashboard. Indexes and bounded work limit cost, but writes, friend counts and polling affect free-tier capacity. On Workers Free, exhausting quotas can make the community temporarily unavailable. Do not enable paid Workers or other paid services without deliberately accepting the charges. Back up D1 through Cloudflare before schema upgrades.
