.pragma library

// ---------------------------------------------------------------------------
// Pure simulation core. No QML, no I/O — every function takes a plain state
// object and returns a new one (or a derived read-only value), so the whole
// creature is testable with node and reproducible from a saved JSON blob.
//
// The single invariant that makes this survive reboots, suspends and shell
// restarts: state carries `lastTick` (ms epoch) and decay is always computed
// from wall-clock elapsed time, never from tick count. A 20s timer and a
// three-day power-off go through exactly the same code path.
// ---------------------------------------------------------------------------

var VERSION = 2

// Stage thresholds in hours since birth. `scale` is the drawn body size
// relative to the panel's creature box, so growing up is literally visible.
var STAGES = [
  { key: "egg",   hours: 0,   scale: 0.62 },
  { key: "baby",  hours: 0.2, scale: 0.58 },
  { key: "kid",   hours: 24,  scale: 0.72 },
  { key: "teen",  hours: 72,  scale: 0.86 },
  { key: "adult", hours: 144, scale: 1.00 },
  { key: "elder", hours: 336, scale: 0.94 }
]

// Per-hour drift while awake. Fullness/happiness/hygiene fall; energy falls
// awake and climbs asleep. Tuned so a completely ignored creature reaches its
// first real distress in ~8h and bottoms out overnight — nagging, not brutal.
var DECAY = {
  fullness:  6.0,
  happiness: 5.0,
  hygiene:   3.5,
  energyAwake: 6.5,
  energySleep: -22.0
}

// Time away from the machine counts, but at a discount. Without this every
// morning starts with a starving pet, which stops being a game and starts
// being a chore.
var OFFLINE_FACTOR = 0.35
var OFFLINE_GAP_HOURS = 0.1      // gaps longer than 6 min count as "away"
var MAX_CATCHUP_HOURS = 48       // a month offline still only costs two days

var POOP_INTERVAL_HOURS = 3.5
var MAX_POOPS = 4

var NAMES = [
  "Blobbo", "Nugget", "Pixel", "Bubble", "Waffles", "Ziggy", "Mochi",
  "Tufty", "Pebble", "Squish", "Puddle", "Bear", "Snorkel", "Bean",
  "Froggy", "Fluffy", "Thunder", "Plum", "Bun", "Zappo",
  "Biscuit", "Noodle", "Pickle", "Sprout", "Taffy", "Gizmo", "Crumb",
  "Dumpling", "Kiwi", "Tofu", "Wobble", "Marble", "Pudding", "Button",
  "Clover", "Doodle", "Fig", "Gumdrop", "Nibble", "Moss", "Pesto",
  "Quark", "Sprocket", "Tater", "Yuzu", "Cosmo", "Echo", "Latte",
  "Kernel", "Grep", "Lint", "Cache", "Glitch", "Patch", "Bit"
]

// A different name from the list, for the reroll next to the naming field.
function suggestName(current) {
  var pick = current
  for (var i = 0; i < 8 && pick === current; i++)
    pick = NAMES[Math.floor(Math.random() * NAMES.length)]
  return pick
}

// Names travel to the community server, which only accepts 1–20 visible
// characters. Control and invisible formatting characters are dropped rather
// than rejected, and the length is counted in characters, not UTF-16 units.
function cleanName(raw) {
  var s = String(raw || "").replace(/[\u0000-\u001f\u007f-\u009f\u00ad\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]/g, "").trim()
  return Array.from(s).slice(0, 20).join("").trim()
}

function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v) }
function clamp100(v) { return clamp(v, 0, 100) }

// Deterministic per-generation PRNG. The creature's colour, name and personality
// are drawn from its seed, so generation 4 looks and reads differently from
// generation 3 — and looks the same every time the shell restarts.
function hashSeed(seed, salt) {
  var h = (seed ^ (salt * 2654435761)) >>> 0
  h ^= h >>> 16; h = (h * 2246822507) >>> 0
  h ^= h >>> 13; h = (h * 3266489909) >>> 0
  h ^= h >>> 16
  return h >>> 0
}

function seededUnit(seed, salt) { return hashSeed(seed, salt) / 4294967295 }
function seededPick(list, seed, salt) { return list[hashSeed(seed, salt) % list.length] }

function newState(nowMs, generation, previousScore) {
  var seed = (Math.floor(Math.random() * 4294967295)) >>> 0
  return {
    version: VERSION,
    generation: generation || 1,
    seed: seed,
    name: seededPick(NAMES, seed, 7),
    // Until the owner has chosen (or kept) a name, the panel asks once after
    // hatching. The seeded name above is only the suggestion.
    named: false,
    bornAt: nowMs,
    diedAt: null,
    causeOfDeath: "",
    lastTick: nowMs,
    stats: { fullness: 70, happiness: 80, energy: 90, hygiene: 100, health: 100 },
    asleep: false,
    forcedAwake: false,
    sick: false,
    poops: 0,
    weight: 8,
    lastPoopAt: nowMs,
    care: { feeds: 0, pets: 0, plays: 0, cleans: 0, cures: 0, score: 100 },
    petStreak: 0,
    lastPetAt: 0,
    lastNagAt: 0,
    lastChatterAt: nowMs,
    nagCooldowns: {},
    bestScore: previousScore || 0,
    daily: { day: "", actions: [], streak: 0, completedDay: "" },
    reunionAt: 0,
    ancestors: []
  }
}

// Fill in anything a state written by an older version is missing, so an
// upgrade never has to reset the creature.
function normalize(raw, nowMs) {
  if (!raw || typeof raw !== "object") return newState(nowMs, 1, 0)
  var base = newState(nowMs, raw.generation || 1, raw.bestScore || 0)
  var out = {}
  for (var k in base) out[k] = base[k]
  for (var j in raw) if (raw[j] !== undefined && raw[j] !== null) out[j] = raw[j]
  out.stats = {
    fullness:  clamp100(Number((raw.stats || {}).fullness)  || 0),
    happiness: clamp100(Number((raw.stats || {}).happiness) || 0),
    energy:    clamp100(Number((raw.stats || {}).energy)    || 0),
    hygiene:   clamp100(Number((raw.stats || {}).hygiene)   || 0),
    health:    clamp100(Number((raw.stats || {}).health)    || 0)
  }
  out.care = raw.care || base.care
  out.nagCooldowns = raw.nagCooldowns || {}
  out.seed = (Number(raw.seed) >>> 0) || base.seed
  // Saves from before naming existed keep the name they have lived with.
  out.named = raw.named === undefined ? true : raw.named === true
  out.version = VERSION
  return out
}

function clone(state) { return JSON.parse(JSON.stringify(state)) }

// ---------------------------------------------------------------------- read

function ageHours(state, nowMs) { return Math.max(0, (nowMs - state.bornAt) / 3600000) }
function ageDays(state, nowMs) { return ageHours(state, nowMs) / 24 }
function isDead(state) { return !!state.diedAt }

function stage(state, nowMs) {
  if (isDead(state)) return "ghost"
  var h = ageHours(state, nowMs)
  var key = STAGES[0].key
  for (var i = 0; i < STAGES.length; i++) if (h >= STAGES[i].hours) key = STAGES[i].key
  return key
}

function stageScale(key) {
  for (var i = 0; i < STAGES.length; i++) if (STAGES[i].key === key) return STAGES[i].scale
  return 1.0
}

function stageIndex(key) {
  for (var i = 0; i < STAGES.length; i++) if (STAGES[i].key === key) return i
  return 0
}

// The stage that comes next, or "" when fully grown.
function nextStageKey(state, nowMs) {
  var h = ageHours(state, nowMs)
  for (var i = 0; i < STAGES.length; i++) if (STAGES[i].hours > h) return STAGES[i].key
  return ""
}

// Hours until the next evolution, or -1 when fully grown. Drives the panel's
// "growing up" progress hint.
function hoursToNextStage(state, nowMs) {
  var h = ageHours(state, nowMs)
  for (var i = 0; i < STAGES.length; i++) if (STAGES[i].hours > h) return STAGES[i].hours - h
  return -1
}

// One number for "how is it doing", used for the bar tint and the face.
function wellbeing(state) {
  var s = state.stats
  return clamp100((s.fullness * 0.28) + (s.happiness * 0.30) + (s.energy * 0.14) +
                  (s.hygiene * 0.13) + (s.health * 0.15))
}

// The single most pressing thing, in priority order. Everything user-facing —
// the bar badge, the speech bubble, the notification — reads from this so they
// can never disagree with each other.
function primaryNeed(state, nowMs) {
  if (isDead(state)) return "dead"
  if (stage(state, nowMs) === "egg") return "egg"
  if (state.sick) return "sick"
  var s = state.stats
  if (s.fullness < 22) return "hungry"
  if (state.poops >= 3) return "poop"
  if (s.hygiene < 22) return "dirty"
  if (s.energy < 18 && !state.asleep) return "tired"
  if (s.happiness < 25) return "bored"
  if (s.fullness < 40) return "peckish"
  if (state.poops >= 1) return "poop"
  if (s.happiness < 45) return "lonely"
  if (state.asleep) return "sleeping"
  return "fine"
}

var URGENT_NEEDS = { sick: 1, hungry: 1, dirty: 1, poop: 1, tired: 1, bored: 1, dead: 1 }
function needsAttention(state, nowMs) { return !!URGENT_NEEDS[primaryNeed(state, nowMs)] }

// Face expression, which is deliberately *not* the same as primaryNeed: a pet
// can be dirty and delighted at the same time, and the face should say so.
function mood(state, nowMs) {
  if (isDead(state)) return "dead"
  if (stage(state, nowMs) === "egg") return "egg"
  if (state.sick) return "sick"
  if (state.asleep) return "asleep"
  var s = state.stats
  if (s.health < 35) return "weak"
  if (s.fullness < 22) return "hungry"
  if (s.energy < 18) return "tired"
  if (s.happiness < 25) return "sad"
  if (s.happiness > 82 && s.fullness > 55) return "ecstatic"
  if (s.happiness > 60) return "happy"
  return "neutral"
}

// ------------------------------------------------------------------ context

// How what you are doing bends the creature's drift. These are multipliers on
// decay, not gifts of points: a creature that is kept company still needs
// feeding, it just stops getting lonely quite so fast.
//
// Only ever applied to live ticks. During an offline catch-up we know what you
// are doing *now*, which says nothing about the eight hours the machine spent
// asleep, so the caller drops the context for those.
function contextFactors(ctx) {
  var f = { happiness: 1, energy: 1, happinessGain: 0, wantsSleep: false }
  if (!ctx) return f

  // Music is the big one. A creature with something to dance to is simply
  // harder to bore, and slowly cheers up on its own.
  if (ctx.music) { f.happiness *= 0.45; f.happinessGain += 2.5 }

  // Watching an agent work is a spectator sport it genuinely enjoys.
  if (ctx.agentBusy) { f.happiness *= 0.65; f.happinessGain += 0.8 }

  // You being at the keyboard at all counts for something.
  if (ctx.present) f.happiness *= 0.85

  // Nobody home: it winds down rather than fretting.
  if (ctx.away) { f.energy *= 0.55; f.happiness *= 1.15 }
  if (ctx.longGone) f.wantsSleep = true

  return f
}

// ------------------------------------------------------------------- advance

// Auto-sleep window. A creature that puts itself to bed at night is far more
// pleasant than one that wakes you with "I'm tired" at 02:00; `forcedAwake`
// lets the user override it until the window ends.
function inQuietHours(hour, spec) {
  var m = String(spec || "23-7").match(/^\s*(\d{1,2})\s*-\s*(\d{1,2})\s*$/)
  if (!m) return false
  var from = clamp(parseInt(m[1], 10), 0, 23)
  var to = clamp(parseInt(m[2], 10), 0, 23)
  if (from === to) return false
  return from < to ? (hour >= from && hour < to) : (hour >= from || hour < to)
}

// Applies wall-clock elapsed time to a state. Returns { state, events } where
// events are one-shot things the caller may want to react to (fell asleep,
// got sick, evolved, died) — the sim never notifies, it only reports.
//
// Long gaps are integrated in chunks rather than as one lump: the drains that
// only start once a stat bottoms out have to see the stats bottom out first.
// A lump-sum weekend would otherwise bill full starvation damage for hours the
// creature actually spent well fed.
function advance(state, nowMs, opts) {
  var out = clone(state)
  var events = []
  var options = opts || {}

  function emit(name) { if (events.indexOf(name) < 0) events.push(name) }

  var startMs = out.lastTick
  var rawHours = (nowMs - startMs) / 3600000
  if (!(rawHours > 0)) { out.lastTick = nowMs; return { state: out, events: events } }
  if (isDead(out)) { out.lastTick = nowMs; return { state: out, events: events } }

  var wasStage = stage(out, startMs)
  var away = rawHours > OFFLINE_GAP_HOURS
  var budget = Math.min(rawHours, MAX_CATCHUP_HOURS) * (away ? OFFLINE_FACTOR : 1)

  // Gentle care lets a busy owner return to company, with no accumulated debt.
  if (options.gentleCare !== false && away) {
    out.stats = {fullness: 75, happiness: 85, energy: 90, hygiene: 90, health: 100}
    out.sick = false; out.poops = 0; out.lastPoopAt = nowMs
    out.asleep = false; out.forcedAwake = false
    out.lastTick = nowMs
    if (rawHours >= 4) { out.reunionAt = nowMs; emit("reunion") }
    if (stage(out, nowMs) !== wasStage) emit("evolve:" + stage(out, nowMs))
    return {state: out, events: events}
  }
  if (options.gentleCare !== false) budget *= 0.2

  var steps = clamp(Math.ceil(budget / 0.25), 1, 400)
  var dt = budget / steps
  var spanMs = nowMs - startMs

  // What you are doing right now describes the last few seconds, not the last
  // few hours, so a catch-up after a gap runs without any context at all.
  var factors = contextFactors(away ? null : options.context)

  for (var i = 0; i < steps && !isDead(out); i++) {
    stepOnce(out, dt, startMs + spanMs * ((i + 1) / steps), options, emit, factors)
  }

  out.lastTick = nowMs

  var nowStage = stage(out, nowMs)
  if (nowStage !== wasStage && !isDead(out)) emit("evolve:" + nowStage)

  return { state: out, events: events }
}

// One integration step of `dt` simulated hours, landing at wall-clock `atMs`.
// Mutates `out` in place; `emit` dedupes events for the caller.
function stepOnce(out, dt, atMs, options, emit, factors) {
  var s = out.stats
  var f = factors || contextFactors(null)

  // --- sleep window -------------------------------------------------------
  // Two reasons to nod off: the configured quiet hours, and you having walked
  // away for a quarter of an hour. Either one counts as "nothing is happening".
  var quiet = inQuietHours(new Date(atMs).getHours(), options.quietHours) || f.wantsSleep
  if (!quiet && out.forcedAwake) out.forcedAwake = false
  if (quiet && !out.asleep && !out.forcedAwake) { out.asleep = true; emit("sleep") }
  if (!quiet && out.asleep && s.energy > 92) { out.asleep = false; emit("wake") }
  if (!out.asleep && s.energy <= 5) { out.asleep = true; out.forcedAwake = false; emit("collapse") }

  // --- drift --------------------------------------------------------------
  var sickMul = out.sick ? 1.5 : 1
  var poopMul = 1 + (out.poops * 0.35)

  if (out.asleep) {
    s.energy = clamp100(s.energy - DECAY.energySleep * dt)
    s.fullness = clamp100(s.fullness - DECAY.fullness * 0.5 * dt * sickMul)
    s.happiness = clamp100(s.happiness - DECAY.happiness * 0.25 * dt * f.happiness)
  } else {
    s.energy = clamp100(s.energy - DECAY.energyAwake * dt * f.energy)
    s.fullness = clamp100(s.fullness - DECAY.fullness * dt * sickMul)
    s.happiness = clamp100(s.happiness - (DECAY.happiness * f.happiness - f.happinessGain) * dt)
  }
  s.hygiene = clamp100(s.hygiene - DECAY.hygiene * poopMul * dt)

  // --- poop ---------------------------------------------------------------
  var sinceP = (atMs - (out.lastPoopAt || out.bornAt)) / 3600000
  if (!out.asleep && stage(out, atMs) !== "egg" && sinceP >= POOP_INTERVAL_HOURS) {
    var made = Math.min((options.gentleCare !== false ? 1 : MAX_POOPS) - out.poops, Math.floor(sinceP / POOP_INTERVAL_HOURS))
    if (made > 0) { out.poops += made; emit("poop") }
    out.lastPoopAt = atMs
  }

  // --- illness ------------------------------------------------------------
  // Risk accumulates continuously with squalor and starvation, so illness
  // reads as "you let this happen" rather than as a dice roll out of nowhere.
  if (options.gentleCare === false && !out.sick && stage(out, atMs) !== "egg") {
    var risk = 0
    if (s.hygiene < 25) risk += (25 - s.hygiene) / 25 * 0.55
    if (s.fullness < 15) risk += (15 - s.fullness) / 15 * 0.45
    if (out.poops >= 3) risk += 0.30
    if (risk > 0 && Math.random() < 1 - Math.pow(1 - Math.min(0.9, risk), dt)) {
      out.sick = true
      emit("sick")
    }
  }

  // --- health -------------------------------------------------------------
  var drain = 0
  if (s.fullness <= 0) drain += 5.5
  if (s.hygiene <= 0) drain += 2.5
  if (s.happiness <= 0) drain += 2.0
  if (out.sick) drain += 3.5
  if (drain > 0 && options.canDie === true) {
    s.health = clamp100(s.health - drain * dt)
  } else if (drain === 0 && s.fullness > 35 && s.hygiene > 35 && s.happiness > 35 && !out.sick) {
    s.health = clamp100(s.health + 6 * dt)
  }

  if (options.gentleCare !== false) {
    s.fullness = Math.max(45, s.fullness); s.happiness = Math.max(55, s.happiness)
    s.hygiene = Math.max(50, s.hygiene); s.health = Math.max(75, s.health)
    out.poops = Math.min(1, out.poops); out.sick = false
  }

  // --- care score ---------------------------------------------------------
  // A slow-moving reputation number: it drifts toward current wellbeing, so a
  // long healthy stretch is worth more than a frantic burst of button mashing.
  var target = wellbeing(out)
  out.care.score = clamp100(out.care.score + (target - out.care.score) * Math.min(1, dt * 0.25))
  if (out.care.score > (out.bestScore || 0)) out.bestScore = out.care.score

  // --- death --------------------------------------------------------------
  if (s.health <= 0 && options.canDie === true) {
    out.diedAt = atMs
    out.causeOfDeath = out.sick ? "sick" : (s.fullness <= 0 ? "hunger" : "neglect")
    emit("death")
  }
}

// -------------------------------------------------------------------- actions

// Every action returns { state, ok, effect, note } — `effect` names the burst
// the UI should play, `note` is a message key. Refusals are first-class: a
// sleeping creature declining food is part of the character.
function reject(state, note) { return { state: state, ok: false, effect: "", note: note } }

function careAction(state, action, nowMs) {
  if (isDead(state)) return reject(state, "isDead")
  var out = clone(state)
  var s = out.stats
  var st = stage(out, nowMs)

  if (st === "egg" && action !== "hatch") return reject(out, "isEgg")

  if (out.asleep && action !== "wake" && action !== "clean") return reject(out, "isAsleep")

  switch (action) {
  case "feed":
    if (s.fullness >= 95) { s.happiness = clamp100(s.happiness - 8); out.weight += 2; return { state: out, ok: false, effect: "sick", note: "tooFull" } }
    s.fullness = clamp100(s.fullness + 28)
    s.happiness = clamp100(s.happiness + 4)
    s.hygiene = clamp100(s.hygiene - 2)
    out.weight = Math.min(60, out.weight + 1)
    out.care.feeds++
    return { state: out, ok: true, effect: "food", note: "fed" }

  case "snack":
    if (s.fullness >= 98) return reject(out, "tooFull")
    s.fullness = clamp100(s.fullness + 10)
    s.happiness = clamp100(s.happiness + 10)
    out.weight = Math.min(60, out.weight + 2)
    out.care.feeds++
    return { state: out, ok: true, effect: "food", note: "snacked" }

  case "pet":
    // Spamming the button is allowed but pays less each time; the streak
    // resets after two quiet minutes.
    var gap = nowMs - (out.lastPetAt || 0)
    out.petStreak = gap > 120000 ? 0 : (out.petStreak + 1)
    out.lastPetAt = nowMs
    var gain = Math.max(2, 13 - out.petStreak * 3)
    s.happiness = clamp100(s.happiness + gain)
    out.care.pets++
    return { state: out, ok: true, effect: "heart", note: out.petStreak > 3 ? "pettedLots" : "petted" }

  case "play":
    if (s.energy < 12) return reject(out, "tooTired")
    s.happiness = clamp100(s.happiness + 20)
    s.energy = clamp100(s.energy - 13)
    s.fullness = clamp100(s.fullness - 6)
    out.weight = Math.max(4, out.weight - 1)
    out.care.plays++
    return { state: out, ok: true, effect: "star", note: "played" }

  case "clean":
    if (s.hygiene >= 99 && out.poops === 0) return reject(out, "alreadyClean")
    s.hygiene = 100
    out.poops = 0
    out.lastPoopAt = nowMs
    s.happiness = clamp100(s.happiness + 3)
    out.care.cleans++
    return { state: out, ok: true, effect: "sparkle", note: "cleaned" }

  case "medicine":
    if (!out.sick) return reject(out, "notSick")
    out.sick = false
    s.health = clamp100(s.health + 22)
    s.happiness = clamp100(s.happiness - 6)
    out.care.cures++
    return { state: out, ok: true, effect: "sparkle", note: "cured" }

  case "sleep":
    if (out.asleep) return reject(out, "alreadyAsleep")
    out.asleep = true
    out.forcedAwake = false
    return { state: out, ok: true, effect: "zzz", note: "tuckedIn" }

  case "wake":
    if (!out.asleep) return reject(out, "alreadyAwake")
    out.asleep = false
    out.forcedAwake = true
    s.happiness = clamp100(s.happiness - (s.energy < 40 ? 8 : 0))
    return { state: out, ok: true, effect: "star", note: s.energy < 40 ? "grumpyWake" : "woke" }

  case "hatch":
    if (st !== "egg") return reject(out, "notEgg")
    out.bornAt = nowMs - (STAGES[1].hours * 3600000) - 1000
    return { state: out, ok: true, effect: "sparkle", note: "hatched" }
  }

  return reject(out, "unknown")
}

// A funeral, then a new egg that remembers its line.
function reincarnate(state, nowMs) {
  var ancestors = (state.ancestors || []).slice(-9)
  ancestors.push({
    name: state.name,
    generation: state.generation,
    days: Math.round(ageDays(state, state.diedAt || nowMs) * 10) / 10,
    score: Math.round(state.care.score),
    cause: state.causeOfDeath || "neglect"
  })
  var next = newState(nowMs, (state.generation || 1) + 1, state.bestScore || 0)
  next.ancestors = ancestors
  return next
}


function dayKey(nowMs) {
  var d = new Date(nowMs)
  return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate()
}
function dailyProgress(state, nowMs) {
  var d = state.daily || {day: "", actions: [], streak: 0, completedDay: ""}
  return {count: d.day === dayKey(nowMs) ? d.actions.length : 0, streak: d.streak || 0}
}
function act(state, action, nowMs) {
  return careAction(state, action, nowMs)
}

// ------------------------------------------------------------------ traits
//
// What makes a creature look like itself beyond its colour: a body shape,
// ears, a marking, eyes and cheeks, all drawn from its seed. Every option is
// equally likely, so there is nothing rare to chase, only creatures that look
// like themselves. The look is a pure function of the public seed, so every
// desktop that meets a creature draws it the same way.

var SHAPES = ["round", "bean", "chunky"]
var EARS = ["none", "round", "pointy", "floppy"]
var MARKINGS = ["none", "spots", "stripes", "patch", "freckles"]
var EYES = ["round", "big", "narrow", "sparkle"]
var CHEEKS = ["#f08fa8", "#f5a37a", "#c9a0f0"]

// `ownSeed` gives a family's child eyes of its own; everything else comes
// from the parent whose seed it carries (its colour comes from the other).
function traits(seed, ownSeed) {
  var s = Number(seed) >>> 0
  var t = {
    shape: seededPick(SHAPES, s, 101),
    ears: seededPick(EARS, s, 103),
    marking: seededPick(MARKINGS, s, 107),
    eyes: seededPick(EYES, s, 109),
    cheek: seededPick(CHEEKS, s, 113),
    side: hashSeed(s, 127) % 2 === 0 ? -1 : 1
  }
  var own = Number(ownSeed) >>> 0
  if (own) t.eyes = seededPick(EYES, own, 109)
  return t
}

// A number from a server id (hex), for seeding a child's own features.
function seedFromId(id) {
  var n = parseInt(String(id || "").slice(0, 8), 16)
  return isFinite(n) ? (n >>> 0) : 0
}

// Seasonal dress-up, by the local calendar. Purely cosmetic: nothing in the
// simulation reads it, and it can be switched off in the widget settings.
function season(nowMs) {
  var d = new Date(nowMs)
  if (d.getMonth() === 9 && d.getDate() >= 24) return "halloween"
  return ""
}

function personality(state) { return ["shy", "generous", "mischievous", "outgoing"][state.seed % 4] }
