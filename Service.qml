import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Sim.js" as Sim
import "Messages.js" as Msg

// ---------------------------------------------------------------------------
// The one true owner of the creature.
//
// A bar widget is instantiated once per monitor, so none of this can live
// there: six screens would mean six creatures decaying in parallel over the
// same save file. This service is a singleton for the whole shell — it ticks
// the simulation, persists it, nags you about it, and hands the live object to
// every widget that wants to draw it.
// ---------------------------------------------------------------------------
Item {
  id: root

  // Injected by omarchy-shell's service loader.
  property var shell: null

  readonly property string pluginId: "creaza.tamagotchi"
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/tamagotchi.json"
  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"

  // `state` is taken by Item, so the creature is `pet`. Widgets bind straight
  // to this: a new object on every tick is what makes their bindings re-run.
  property var pet: null
  property bool ready: false

  // Bumped whenever the creature is replaced, so bindings that want to react
  // to *any* change (not just one field) have something cheap to watch.
  property int revision: 0

  // Fired for every action that lands, wherever it came from — panel button,
  // bar click, or a notification the user clicked ten minutes ago. Widgets
  // listen and play the matching particle burst, so all monitors celebrate
  // together and a click in a notification is visible on screen.
  signal reacted(string action, string effect, string note, bool ok)
  signal creatureEvent(string name)

  // ------------------------------------------------------------- settings

  property var config: ({})
  readonly property string language: "en"
  readonly property bool notificationsEnabled: configBool("notifications", true)
  readonly property bool chatterEnabled: configBool("chatter", true)
  readonly property int nagCooldownMs: Math.max(5, Number(configValue("nagCooldownMinutes", 45)) || 45) * 60000
  readonly property string quietHours: String(configValue("quietHours", "23-7"))
  readonly property bool canDie: configBool("canDie", false)
  readonly property bool gentleCare: configBool("gentleCare", true)
  readonly property bool careNotifications: configBool("careNotifications", false)
  readonly property bool awarenessEnabled: configBool("awareness", true)
  readonly property bool contextChatterEnabled: configBool("contextChatter", true)
  readonly property bool seasonalEnabled: configBool("seasonal", true)
  readonly property bool calmMotion: configBool("calmMotion", false)

  function configValue(key, fallback) {
    var v = config ? config[key] : undefined
    return (v === undefined || v === null) ? fallback : v
  }

  function configBool(key, fallback) {
    var v = configValue(key, fallback)
    if (typeof v === "boolean") return v
    var s = String(v).toLowerCase()
    return s === "true" || s === "1" || s === "on" || s === "yes"
  }

  // Settings live inline on the widget's shell.json entry (bar layout for a
  // bar widget, plugins[] otherwise). Services get no `settings` injection, so
  // we read the same file the shell does and follow it live.
  function applyConfig(raw) {
    var found = {}
    try {
      var json = JSON.parse(raw || "{}")
      var sections = ["left", "center", "right"]
      var layout = (json.bar && json.bar.layout) ? json.bar.layout : {}
      for (var i = 0; i < sections.length; i++) {
        var list = layout[sections[i]] || []
        for (var j = 0; j < list.length; j++)
          if (list[j] && list[j].id === root.pluginId) found = list[j]
      }
      var plugins = json.plugins || []
      for (var k = 0; k < plugins.length; k++)
        if (plugins[k] && plugins[k].id === root.pluginId)
          for (var key in plugins[k]) if (key !== "id") found[key] = plugins[k][key]
    } catch (e) {
      // Malformed shell.json is the shell's problem to report, not ours —
      // keep whatever settings we already had.
      return
    }
    root.config = found
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onFileChanged: reload()
    onLoadFailed: root.applyConfig("{}")
  }

  // --------------------------------------------------------------- senses
  //
  // Widgets read this straight off the service, the same way they read `pet`:
  // one observer for the whole shell, however many monitors are attached.

  property alias social: community
  Social { id: community; service: root }

  property alias awareness: senses

  Awareness {
    id: senses
    enabled: root.awarenessEnabled

    onAgentFinished: function(seconds) { root.celebrateAgent(seconds) }
    onTrackStarted: function(trackName, artistName) { root.commentOnTrack(trackName, artistName) }
  }

  // ---------------------------------------------------------------- state

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.adopt(text())
    onLoadFailed: root.adopt("")
  }

  function adopt(raw) {
    if (root.ready) return
    var now = Date.now()
    var parsed = null
    try { parsed = JSON.parse(raw || "null") } catch (e) { parsed = null }
    root.pet = parsed ? Sim.normalize(parsed, now) : Sim.newState(now, 1, 0)
    root.ready = true
    root.revision++
    // Catch up on everything that happened while the shell was down before
    // anyone gets to look at a stale creature.
    tick()
  }

  function persist() {
    if (!root.pet) return
    stateFile.setText(JSON.stringify(root.pet, null, 2) + "\n")
  }

  Timer {
    id: saveDebounce
    interval: 1200
    repeat: false
    onTriggered: root.persist()
  }

  function commit(next, immediate) {
    root.pet = next
    root.revision++
    if (immediate) { saveDebounce.stop(); root.persist() }
    else saveDebounce.restart()
  }

  // ----------------------------------------------------------------- tick

  // 15s is well under the finest thing the UI shows (a 1-point stat move takes
  // ~10 minutes), and it exists mostly so the *clock* stays honest — the sim
  // itself is driven by elapsed wall time, not by how often this fires.
  Timer {
    interval: 15000
    repeat: true
    running: root.ready
    triggeredOnStart: false
    onTriggered: root.tick()
  }

  function simOptions() {
    return {
      quietHours: root.quietHours,
      canDie: root.canDie,
      gentleCare: root.gentleCare,
      context: root.awarenessEnabled ? senses.context() : null
    }
  }

  function tick() {
    if (!root.pet) return
    var now = Date.now()
    var result = Sim.advance(root.pet, now, root.simOptions())
    var next = result.state

    for (var i = 0; i < result.events.length; i++) {
      announce(result.events[i], next)
      root.creatureEvent(result.events[i])
    }

    next = maybeNag(next, now)
    commit(next, result.events.length > 0)
  }

  // --------------------------------------------------------------- actions

  function perform(action) {
    if (!root.pet) return "not ready"
    var now = Date.now()

    if (action === "newEgg" || action === "reincarnate") {
      if (!Sim.isDead(root.pet)) return "alive"
      commit(Sim.reincarnate(root.pet, now), true)
      root.reacted("newEgg", "sparkle", "hatched", true)
      return "ok"
    }

    // Fold in elapsed time first: acting on a stale creature would silently
    // undo whatever decay happened since the last tick.
    var caught = Sim.advance(root.pet, now, root.simOptions()).state
    var res = Sim.act(caught, action, now)

    // A refused action still counts as an interaction — waking a sleeping pet
    // to tell it "no" is half the charm — so the caught-up state is kept.
    commit(res.state, res.ok)
    root.reacted(action, res.effect, res.note, res.ok)

    // Acting is an answer to the nag, so stop nagging about that need.
    if (res.ok) clearNagFor(action)
    return res.ok ? "ok" : res.note
  }

  function clearNagFor(action) {
    var map = {
      feed: ["hungry", "peckish"], snack: ["hungry", "peckish"],
      pet: ["lonely", "bored"], play: ["bored", "lonely"],
      clean: ["dirty", "poop"], medicine: ["sick"], sleep: ["tired"]
    }
    var keys = map[action]
    if (!keys || !root.pet) return
    var next = Sim.clone(root.pet)
    for (var i = 0; i < keys.length; i++) next.nagCooldowns[keys[i]] = Date.now()
    root.pet = next
  }

  function rename(name) {
    var clean = Sim.cleanName(name)
    if (!clean || !root.pet) return "invalid"
    var next = Sim.clone(root.pet)
    next.name = clean
    next.named = true
    commit(next, true)
    root.reacted("rename", "heart", "named", true)
    return clean
  }

  // --------------------------------------------------------- notifications

  // Toast ids are recycled through -r so a nagging creature never stacks up a
  // column of notifications; it edits the one it already put on screen.
  property int toastId: 0

  Process {
    id: notifier
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var id = parseInt(String(text || "").trim(), 10)
        if (isFinite(id) && id > 0) root.toastId = id
      }
    }
  }

  function notify(title, body, glyph, urgency, execArgs, replaceInPlace) {
    if (notifier.running) return
    var argv = ["omarchy-notification-send",
                "--app-name", "Omarchygotchi",
                "-u", urgency || "low",
                "-g", glyph || "✨",
                "-p"]
    if (replaceInPlace && root.toastId > 0) argv = argv.concat(["-r", String(root.toastId)])
    argv.push(title)
    argv.push(body)
    if (execArgs && execArgs.length > 0) argv = argv.concat(["--exec"]).concat(execArgs)
    notifier.command = argv
    notifier.running = true
  }

  readonly property var actionForNeed: ({
    hungry: "feed", peckish: "snack", bored: "play", lonely: "pet",
    dirty: "clean", poop: "clean", tired: "sleep", sick: "medicine", dead: "newEgg"
  })

  function needIsUrgent(need) {
    return need === "sick" || need === "dead" || need === "hungry"
  }

  // Nags are rate limited three ways: per need, globally, and by the quiet
  // window. Anything less and a neglected creature turns into a denial-of-
  // service attack on your notification centre.
  function maybeNag(candidate, now) {
    if (!root.notificationsEnabled) return candidate
    if (!root.careNotifications) return maybeChatter(candidate, now, Sim.inQuietHours(new Date(now).getHours(), root.quietHours))

    var need = Sim.primaryNeed(candidate, now)
    var quiet = Sim.inQuietHours(new Date(now).getHours(), root.quietHours)

    if (need === "fine" || need === "sleeping" || need === "egg")
      return maybeChatter(candidate, now, quiet)

    if (quiet && !needIsUrgent(need)) return candidate
    if (now - (candidate.lastNagAt || 0) < 8 * 60000) return candidate

    var cooldowns = candidate.nagCooldowns || {}
    var due = needIsUrgent(need) ? root.nagCooldownMs * 0.6 : root.nagCooldownMs
    if (now - (cooldowns[need] || 0) < due) return candidate

    var line = Msg.nag(need, root.language, now / 60000)
    if (!line) return candidate

    var action = root.actionForNeed[need] || "pet"
    notify(Msg.fill(line.t, candidate.name, candidate.generation),
           Msg.fill(line.b, candidate.name, candidate.generation),
           Msg.glyph(need),
           needIsUrgent(need) ? "normal" : "low",
           ["omarchy-shell", "tamagotchi", action],
           true)

    var next = Sim.clone(candidate)
    next.nagCooldowns[need] = now
    next.lastNagAt = now
    return next
  }

  // Unprompted good news, on a slow and deliberately irregular schedule. This
  // is the part that makes it a pet instead of an alarm clock.
  function maybeChatter(candidate, now, quiet) {
    if (!root.chatterEnabled || quiet) return candidate
    if (Sim.isDead(candidate) || Sim.stage(candidate, now) === "egg") return candidate

    var since = now - (candidate.lastChatterAt || candidate.bornAt)
    var wait = (90 + Sim.seededUnit(candidate.seed, Math.floor(now / 3600000)) * 120) * 60000
    if (since < wait) return candidate

    var line = Msg.chatter(root.language, now / 60000)
    notify(Msg.fill(line.t, candidate.name, candidate.generation),
           Msg.fill(line.b, candidate.name, candidate.generation),
           Msg.glyph("fine"), "low",
           ["omarchy-shell", "shell", "summon", root.pluginId],
           true)

    var next = Sim.clone(candidate)
    next.lastChatterAt = now
    return next
  }

  // ------------------------------------------------------- context notices
  //
  // The rarest tier of notification. Care nags ask you for something; these
  // exist only to prove the creature is watching the same screen you are, so
  // they run on their own long cooldowns and never borrow the nag budget.

  function contextCooldownOk(key, cooldownMs) {
    if (!root.pet) return false
    var last = (root.pet.nagCooldowns || {})["ctx:" + key] || 0
    return Date.now() - last >= cooldownMs
  }

  function markContext(key) {
    if (!root.pet) return
    var next = Sim.clone(root.pet)
    next.nagCooldowns["ctx:" + key] = Date.now()
    root.pet = next
    saveDebounce.restart()
  }

  function contextNotify(key, cooldownMs, minutes, track) {
    if (!root.notificationsEnabled || !root.contextChatterEnabled) return false
    if (!root.pet || Sim.isDead(root.pet) || root.pet.asleep) return false
    if (Sim.stage(root.pet, Date.now()) === "egg") return false
    if (!contextCooldownOk(key, cooldownMs)) return false

    var line = Msg.contextLine(key, root.language, Date.now() / 60000)
    if (!line) return false

    notify(Msg.fill(line.t, root.pet.name, root.pet.generation, minutes, track),
           Msg.fill(line.b, root.pet.name, root.pet.generation, minutes, track),
           Msg.modeGlyph(key === "track" ? "music" : (key === "agentDone" ? "agent" : "idle")),
           "low",
           ["omarchy-shell", "shell", "summon", root.pluginId],
           true)
    markContext(key)
    return true
  }

  property real lastCheerAt: 0

  function celebrateAgent(seconds) {
    // A hook and the title watcher can both report the same finish; one cheer
    // is plenty.
    if (Date.now() - root.lastCheerAt < 10000) return
    root.lastCheerAt = Date.now()
    // The creature cheers on every screen whether or not it says anything.
    root.reacted("watch", "star", "", true)
    if (seconds < 120) return
    contextNotify("agentDone", 15 * 60000, Math.max(1, Math.round(seconds / 60)), "")
  }

  function commentOnTrack(trackName, artistName) {
    root.reacted("dance", "note", "", true)
    // Most tracks pass without comment; the occasional one does not. Anything
    // more than that and a full album turns into a notification storm.
    if (Math.random() > 0.14) return
    contextNotify("track", 45 * 60000, 0, trackName)
  }

  // ----------------------------------------------------------- theme watch
  //
  // Switching Omarchy themes repaints the creature (its tint leans toward the
  // accent), and it notices, once per switch. The first seconds after start-up
  // are the theme loading, not you changing it, so they only set the baseline.

  property color seenAccent: "transparent"
  property bool themeSettled: false

  Timer {
    interval: 5000
    running: root.ready && !root.themeSettled
    onTriggered: { root.seenAccent = Color.accent; root.themeSettled = true }
  }

  // A theme switch can touch the accent more than once; react to where it
  // lands, not to each step.
  Timer {
    id: themeDebounce
    interval: 700
    onTriggered: {
      if (!root.themeSettled || Qt.colorEqual(Color.accent, root.seenAccent)) return
      root.seenAccent = Color.accent
      var p = root.pet
      if (!p || Sim.isDead(p) || p.asleep || Sim.stage(p, Date.now()) === "egg") return
      root.reacted("theme", "sparkle", "newTheme", true)
    }
  }

  Connections {
    target: Color
    function onAccentChanged() { themeDebounce.restart() }
  }

  // Uninterrupted focus, measured by the awareness mode rather than by the
  // clock: switching to the browser for ten seconds does not reset it, walking
  // away does.
  property real focusSince: 0

  Connections {
    target: senses
    function onModeChanged() {
      var m = senses.mode
      var focused = (m === "coding" || m === "agent" || m === "making")
      if (!focused || m === "away") {
        if (m === "away") root.focusSince = 0
        return
      }
      if (root.focusSince === 0) root.focusSince = Date.now()
    }
    function onLongGoneChanged() {
      if (senses.longGone) root.wasLongGone = true
      else if (root.wasLongGone) {
        root.wasLongGone = false
        root.contextNotify("welcomeBack", 60 * 60000, 0, "")
      }
    }
  }

  property bool wasLongGone: false

  Timer {
    interval: 60000
    repeat: true
    running: root.ready && root.awarenessEnabled
    onTriggered: {
      if (senses.away) { root.focusSince = 0; return }
      if (root.focusSince === 0) return
      var minutes = Math.round((Date.now() - root.focusSince) / 60000)
      if (minutes < 90) return
      if (root.contextNotify("longFocus", 3 * 3600000, minutes, "")) root.focusSince = Date.now()
    }
  }

  // Life events are worth interrupting for, and they never repeat, so they
  // skip the nag budget entirely.
  function announce(eventName, creature) {
    if (!root.notificationsEnabled) return
    if (eventName === "wake" || eventName === "sleep") return
    if (!root.careNotifications && ["poop", "sick", "collapse"].indexOf(eventName) >= 0) return

    var line = Msg.event(eventName, root.language)
    if (!line) return

    var isDeath = eventName === "death"
    var exec = isDeath
      ? ["omarchy-shell", "tamagotchi", "newEgg"]
      : (eventName === "sick" ? ["omarchy-shell", "tamagotchi", "medicine"]
      : (eventName === "poop" ? ["omarchy-shell", "tamagotchi", "clean"]
      : ["omarchy-shell", "shell", "summon", root.pluginId]))

    notify(Msg.fill(line.t, creature.name, creature.generation),
           Msg.fill(line.b, creature.name, creature.generation),
           isDeath ? Msg.glyph("dead") : (eventName.indexOf("evolve:") === 0 ? Msg.glyph("evolve") : Msg.glyph(eventName)),
           isDeath || eventName === "sick" ? "normal" : "low",
           exec,
           false)
  }

  // ------------------------------------------------------------------- IPC
  //
  // Everything the panel, the bar and every notification button can do goes
  // through here, so a click in a toast three hours from now takes exactly the
  // same path as a click on the panel.

  IpcHandler {
    target: "tamagotchi"

    function feed(): string { return root.perform("feed") }
    function snack(): string { return root.perform("snack") }
    function pet(): string { return root.perform("pet") }
    function play(): string { return root.perform("play") }
    function clean(): string { return root.perform("clean") }
    function medicine(): string { return root.perform("medicine") }
    function sleep(): string { return root.perform("sleep") }
    function wake(): string { return root.perform("wake") }
    function hatch(): string { return root.perform("hatch") }
    function newEgg(): string { return root.perform("newEgg") }
    function rename(name: string): string { return root.rename(name) }

    function status(): string {
      if (!root.pet) return "not ready"
      var now = Date.now()
      var s = root.pet.stats
      return root.pet.name
        + " · gen " + root.pet.generation
        + " · " + Msg.stageLabel(Sim.stage(root.pet, now), root.language)
        + " · " + (Sim.ageDays(root.pet, now)).toFixed(1) + "d"
        + " · " + Msg.statLabel("fullness", root.language) + " " + Math.round(s.fullness)
        + " · " + Msg.statLabel("happiness", root.language) + " " + Math.round(s.happiness)
        + " · " + Msg.statLabel("energy", root.language) + " " + Math.round(s.energy)
        + " · " + Msg.statLabel("hygiene", root.language) + " " + Math.round(s.hygiene)
        + " · " + Msg.statLabel("health", root.language) + " " + Math.round(s.health)
        + (root.pet.sick ? " · 🤒" : "")
        + (root.pet.asleep ? " · 💤" : "")
        + (root.pet.poops > 0 ? " · 💩×" + root.pet.poops : "")
        + (Sim.isDead(root.pet) ? " · 👻" : "")
    }

    function json(): string { return root.pet ? JSON.stringify(root.pet) : "{}" }

    // For agent CLIs that can run a command when they stop or need you. In
    // Claude Code's settings.json:
    //   "hooks": {
    //     "Stop":         [{"hooks": [{"type": "command", "command": "omarchy-shell tamagotchi cheer"}]}],
    //     "Notification": [{"hooks": [{"type": "command", "command": "omarchy-shell tamagotchi waiting"}]}]
    //   }
    function cheer(): string {
      if (!root.awarenessEnabled) return "awareness off"
      senses.markWaiting(null, "")
      root.celebrateAgent(0)
      return "ok"
    }
    // Your friend code, for pasting into a chat. Creates one when there is
    // none yet; the new code is ready a moment later.
    function invite(): string {
      if (!community.optedIn) return "Join the park first: Community → Join the park."
      if (!community.friendCodes) return "This community server has no friend codes."
      if (community.inviteCode !== "") return community.inviteCode
      community.createInvite()
      return "Creating your friend code. Run this again in a moment."
    }

    function waiting(): string {
      if (!root.awarenessEnabled) return "awareness off"
      senses.markWaiting(null, "")
      return "ok"
    }

    // What the creature currently believes about your session. Handy when a
    // new app isn't being recognised and you want to see what it saw.
    function sense(): string {
      if (!root.awarenessEnabled) return "awareness off"
      return "mode " + senses.mode
        + " · app " + (senses.appId || "-")
        + " · category " + (senses.category || "-")
        + " · music " + (senses.musicPlaying ? (senses.trackArtist + " - " + senses.trackTitle) : "no")
        + " · beat " + senses.beatMs + "ms"
        + " · agent " + (senses.agentBusy ? ("busy: " + senses.agentTask) : (senses.agentPresent ? "idle" : "no"))
        + (senses.agentWaiting ? " · waiting on you" : "")
        + " · away " + (senses.away ? "yes" : "no")
        + " · title " + (senses.title || "-")
    }

    // Escape hatch for testing a state you'd otherwise have to wait days for —
    // and, honestly, for cheating. It's your creature.
    //   omarchy-shell tamagotchi cheat fullness 5
    //   omarchy-shell tamagotchi cheat sick 1
    //   omarchy-shell tamagotchi cheat ageHours 200
    function cheat(field: string, value: string): string {
      if (!root.pet) return "not ready"
      var next = Sim.clone(root.pet)
      var num = Number(value)
      var key = String(field)

      if (key in next.stats) next.stats[key] = Math.max(0, Math.min(100, num))
      else if (key === "sick") next.sick = num > 0
      else if (key === "asleep") { next.asleep = num > 0; next.forcedAwake = num <= 0 }
      else if (key === "poops") next.poops = Math.max(0, Math.min(4, Math.round(num)))
      else if (key === "weight") next.weight = Math.max(1, Math.round(num))
      else if (key === "ageHours") next.bornAt = Date.now() - num * 3600000
      else if (key === "kill") { next.stats.health = 0; next.diedAt = Date.now(); next.causeOfDeath = "neglect" }
      else if (key === "revive") { next.diedAt = null; next.causeOfDeath = ""; next.stats.health = 100 }
      else return "unknown field: " + key

      commit(next, true)
      return "ok"
    }
  }

  Component.onCompleted: stateFile.reload()
  Component.onDestruction: persist()
}
