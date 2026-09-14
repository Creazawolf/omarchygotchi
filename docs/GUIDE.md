# Omarchygotchi · 3.0

Your computer has a tiny social life. A companion lives in your Omarchy bar, meets real creatures, remembers its friends, and can build a family with another desktop.

## Stories and visits

Open the creature to see what happened, who matters, and what might happen next. The care meters and buttons live under **A little care**; keyboard shortcuts and bar feeding/petting still work.

- A real visitor appears beside your creature in the bar and in a shared habitat scene for 15 minutes after the server records the encounter. Older/offline encounters appear as memories, never as a fake live visitor.
- Seeded personalities cause different stories: shy creatures leave gifts and eventually bring a radio; mischievous creatures borrow and return a hat; generous creatures share a favorite possession. Familiar friends form a terrible band.
- Relationship memories and the latest keepsake persist beyond the rolling journal. The journal retains 30 days, showing the newest 30 visits. Save a favorite scene to keep its picture permanently.
- Friend requests still require an encounter and the other owner’s acceptance. Blocking works in both directions. Removing a friend or blocking ends courtship and closes any unagreed egg proposal.

**Community** holds relationship details, the family album, and scene previews. Automatic roaming remains optional, around every six hours when a partner is available. Offline adventures are a separate opt-in with a seven-day renewable lease. An empty park stays empty.

## Romance and family

Romance is optional for each friendship, with private choices until both owners allow it. It needs adult/elder friends and three encounters. Both owners can keep the friendship without romance. Sweethearts get dates, anniversary stories, and reunions based on their actual shared history.

After six encounters, sweethearts can **Plan a shared egg**:

1. Choose a name and either parent’s desktop as the primary home.
2. The other owner explicitly agrees to that egg and that home. Either owner can close a pending proposal; unanswered proposals expire after seven days.
3. One shared child appears in both albums. It hatches after one day, becomes a kid at day three, a teen at day seven, and an adult at day fourteen.
4. At its primary home, the growing child appears in the habitat. Both owners receive updated milestones and can visit the other parent through **Visit family**.

Children inherit one parent’s markings and the other’s colour. They inherit a personality, with an occasional decoration-nibbling habit. They have no additional care meters. Each household can have only one pending or growing child, including children living with the other parent. The album holds up to 12 children per owner; there is no trading, rarity, or score reward. Adults remain in both albums. Historical parent portraits survive a parent’s profile deletion in the other owner’s family album.

## Keep a moment

Choose **Preview keepsake** on a recorded journal event or agreed family entry. Edit the caption and choose **Save image** for a 1200×750 PNG. The exported scene contains the actual recorded participants and appearance, or the shared child and parents. It does not capture your desktop. Pending egg proposals cannot be exported as completed milestones.

Images save to `~/.local/state/omarchy/tamagotchi-community/moment-….png`; the panel shows the exact path. Sharing to X or elsewhere is entirely your choice. No automatic posting or invented participants.

## Gentle care

Gentle care is on by default: needs fall at one-fifth the legacy speed and self-care keeps the creature comfortable. After a long absence it returns healthy, clean, rested, and happy, with a reunion after four hours away. Default death from neglect and care reminders are off. Old saves, names, generations and ancestral history are preserved; previously dead creatures are not silently revived. Daily streak rewards and scores no longer drive the panel.

The creature still reacts to your apps, music, AI agents, idle time and time of day. Awareness data stays on the desktop. Quiet hours suppress visitor notifications. The guest in the bar is static to avoid continuous whole-bar repaints; the open panel may animate.

| Setting | Default | Behavior |
|---|---|---|
| `gentleCare` | `true` | Slow needs, self-care and healthy returns |
| `canDie` | `false` | Explicit legacy mortality; also disable gentle care for the old challenge |
| `careNotifications` | `false` | Optional care reminders and illness/dropping alerts |
| `notifications` | `true` | Visitor and life-event notifications |
| `chatter` | `true` | Occasional companion chatter |
| `quietHours` | `"23-7"` | Automatic sleep; visitor notifications stay quiet |
| `nagCooldownMinutes` | `45` | Reminder cooldown if enabled |
| `awareness` | `true` | Local reactions to music, apps and activity |
| `contextChatter` | `true` | Occasional awareness remarks |

Settings live on the widget’s entry in `~/.config/omarchy/shell.json`. Explicit existing settings are respected.

## Connection and upgrade

Select **Connect** to join the configured community server. No multiplayer connection is made without opt-in. The public Cloudflare origin is provided in `CommunityDefaults.js`. Only the creature’s name, appearance seed, stage and availability are sent, along with explicit social actions. Credentials stay in private server-specific files, never command arguments.

**The included public community server runs 3.0.** For your own community, deploy the Worker and apply its migrations; see [backend instructions](../cloudflare/README.md). A 2.x server continues to offer its original playdate/friendship features; unsupported romance/family controls stay hidden. The optional [Python server](../community/README.md) remains a legacy online-only alternative.

Install and update through the Omarchy plugin commands in the [README](../README.md). The active save is `~/.local/state/omarchy/tamagotchi.json`; shared history is cached separately for offline album reading.

## Development and verification

The plugin uses Quickshell/QML and Python 3. The Cloudflare tests require Node 24+.

```sh
# From the repository root:
python3 -m unittest discover -s community -p 'test_*.py'
node community/test_sim.cjs

# From cloudflare:
npm test
npm run check
npx wrangler d1 migrations apply omarchy-creature-community --local
npx wrangler dev --test-scheduled
# In another terminal, same directory:
node test/runtime-smoke.mjs http://127.0.0.1:8787

# On an Omarchy desktop, from this plugin directory:
python3 community/qml-smoke.py /tmp/tamagotchi-visual-check
```

The visual check loads actual QML components in a temporary home, verifies visitor expiry/disconnect, and exports two explicitly synthetic test scenes. It does not use your creature save or connect to production. The localhost runtime check creates and deletes test identities, including a shared family, against disposable local D1 state.

| File | Role |
|---|---|
| `Service.qml`, `Sim.js` | Singleton save, clock, care and notifications |
| `Social.qml`, `community/client.py` | Opt-in sync, validated responses, active visits and history cache |
| `BarWidget.qml`, `Panel.qml` | Visitor in the bar and story-focused home |
| `StoryPanel.qml`, `CommunityPanel.qml` | Relationships, consent, family album and community controls |
| `SharedScene.qml` | Shared habitat, inherited child appearance and isolated PNG export |
| `Creature.qml`, `Gear.qml`, `Awareness.qml` | Existing primitive-drawn creature and local awareness |

The plugin is MIT licensed. Package `manifest.json`, root QML/JS files, and `community/client.py`; the Worker is deployed separately. No image-generation service, sprite downloads, new Python dependencies, or external posting integration is required.
