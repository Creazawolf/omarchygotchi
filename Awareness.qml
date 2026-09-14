import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

// ---------------------------------------------------------------------------
// What the creature knows about your day.
//
// Three independent senses, deliberately kept apart because they compose: what
// window you are in (`category`), whether music is playing (`musicPlaying`),
// and whether an AI agent is grinding away somewhere (`agentBusy`). The
// creature can wear headphones, hold a laptop and watch a propeller all at
// once, so none of these may be a single mutually-exclusive enum.
//
// Everything here is read-only observation of things already on your screen.
// Nothing is stored, sent, or written to disk.
// ---------------------------------------------------------------------------
Item {
  id: root
  visible: false

  property bool enabled: true

  // ------------------------------------------------------- focused window

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string appId: (enabled && toplevel && toplevel.appId) ? String(toplevel.appId) : ""
  readonly property string title: (enabled && toplevel && toplevel.title) ? String(toplevel.title) : ""

  // Matched against the app id first, then the window title. The lists are
  // substrings, not exact ids, because desktop entries vary wildly across
  // distros and PWAs invent their own ("chrome-discord.com__channels...").
  readonly property var appRules: [
    { key: "game",     ids: ["steam", "gamescope", "lutris", "heroic", "prismlauncher", "retroarch"] },
    { key: "video",    ids: ["mpv", "vlc", "celluloid", "totem", "netflix"] },
    { key: "music",    ids: ["spotify", "tidal", "rhythmbox", "youtube music", "ncspot"] },
    { key: "chat",     ids: ["discord", "slack", "signal", "telegram", "element", "whatsapp", "teams", "zoom"] },
    { key: "design",   ids: ["figma", "gimp", "inkscape", "blender", "krita", "darktable", "obs"] },
    { key: "editor",   ids: ["code", "vscodium", "cursor", "zed", "jetbrains", "sublime", "neovide", "emacs"] },
    { key: "browser",  ids: ["chromium", "chrome", "firefox", "brave", "zen", "vivaldi", "librewolf", "epiphany", "qutebrowser"] },
    { key: "terminal", ids: ["ghostty", "alacritty", "kitty", "foot", "wezterm", "konsole", "gnome-terminal"] },
    { key: "files",    ids: ["nautilus", "thunar", "dolphin", "nemo", "yazi"] }
  ]

  // Watching something in a browser is watching, not browsing.
  readonly property var videoTitleHints: ["youtube", "netflix", "twitch", "vimeo", "disney+", "hbo", "svt play", "viaplay"]

  function matchRule(haystack) {
    var s = String(haystack || "").toLowerCase()
    if (s === "") return ""
    for (var i = 0; i < appRules.length; i++) {
      var ids = appRules[i].ids
      for (var j = 0; j < ids.length; j++) if (s.indexOf(ids[j]) >= 0) return appRules[i].key
    }
    return ""
  }

  readonly property string category: {
    if (!enabled) return ""
    var byApp = matchRule(appId)
    if (byApp === "browser") {
      var t = title.toLowerCase()
      for (var i = 0; i < videoTitleHints.length; i++)
        if (t.indexOf(videoTitleHints[i]) >= 0) return "video"
      return "browser"
    }
    if (byApp !== "") return byApp
    return matchRule(title)
  }

  // ---------------------------------------------------------------- music

  readonly property var players: enabled && Mpris.players ? Mpris.players.values : []

  readonly property var activePlayer: {
    var list = root.players
    for (var i = 0; i < list.length; i++) if (list[i] && list[i].isPlaying) return list[i]
    return null
  }

  readonly property bool musicPlaying: activePlayer !== null
  readonly property string trackTitle: activePlayer && activePlayer.trackTitle ? String(activePlayer.trackTitle) : ""
  readonly property string trackArtist: activePlayer && activePlayer.trackArtist ? String(activePlayer.trackArtist) : ""
  readonly property string playerName: activePlayer && activePlayer.identity ? String(activePlayer.identity) : ""
  readonly property string trackKey: trackTitle + " " + trackArtist

  // No BPM is exposed over MPRIS, so the groove is invented — but it is
  // invented *per track*, deterministically. The same song always gets the
  // same tempo, which is enough for the dancing to feel intentional rather
  // than like a generic idle loop.
  readonly property int beatMs: {
    var key = root.trackKey
    if (key.length < 2) return 500
    var h = 0
    for (var i = 0; i < key.length; i++) h = ((h << 5) - h + key.charCodeAt(i)) | 0
    return 380 + (Math.abs(h) % 260)
  }

  property int beat: 0

  Timer {
    interval: root.beatMs
    repeat: true
    running: root.musicPlaying
    onTriggered: root.beat++
  }

  signal trackStarted(string trackName, string artistName)

  onTrackKeyChanged: {
    if (!musicPlaying || trackTitle === "") return
    trackStarted(trackTitle, trackArtist)
  }

  // --------------------------------------------------------------- agents
  //
  // Two separate questions. "Is an agent running at all" is a process check.
  // "Is it working right now" is the far more useful one, and the answer is
  // sitting in a window title: Claude Code (and friends) prefix the title with
  // a spinner glyph plus what they are doing while a turn is in flight, and
  // drop back to the plain directory when they are waiting on you.

  readonly property string busyGlyphs: "◐◑◒◓◔◕◖◗"
    + "✳✻✽✢"
    + "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    + "⣾⣽⣻⢿⡿⣟⣯⣷"

  readonly property var allToplevels: enabled && ToplevelManager.toplevels ? ToplevelManager.toplevels.values : []

  // Recomputed whenever any window title changes. `titleTick` is bumped by the
  // watcher below, because the collection's identity does not change when a
  // single title is edited in place.
  property int titleTick: 0

  readonly property var agentWindow: {
    root.titleTick // dependency: re-evaluate on every title change
    var list = root.allToplevels
    for (var i = 0; i < list.length; i++) {
      var t = list[i]
      if (!t || !t.title) continue
      var s = String(t.title)
      if (root.busyGlyphs.indexOf(s.charAt(0)) < 0) continue
      var rest = s.slice(1).replace(/^[\s·|—-]+/, "")
      if (rest.length > 0) return { task: rest, appId: String(t.appId || "") }
    }
    return null
  }

  // Titles mutate in place, so watching the collection is not enough — every
  // toplevel needs its own change hook.
  Instantiator {
    model: root.allToplevels
    delegate: QtObject {
      required property var modelData
      readonly property string watchedTitle: modelData && modelData.title ? String(modelData.title) : ""
      onWatchedTitleChanged: root.titleTick++
    }
  }

  readonly property bool agentBusy: enabled && agentWindow !== null
  readonly property string agentTask: agentWindow ? String(agentWindow.task) : ""

  // The process check is the slower, calmer signal: it says an agent session
  // exists even while it sits waiting for you to type.
  property bool agentPresent: false
  property string agentName: ""

  Process {
    id: agentProbe
    command: ["bash", "-lc", "pgrep -x -l 'claude|codex|aider|opencode|goose|crush|amp|gemini' 2>/dev/null | awk '{print $2}' | sort -u | paste -sd, -"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var names = String(text || "").trim()
        root.agentPresent = names.length > 0
        root.agentName = names.split(",")[0] || ""
      }
    }
  }

  Timer {
    interval: 12000
    repeat: true
    running: root.enabled
    triggeredOnStart: true
    onTriggered: if (!agentProbe.running) agentProbe.running = true
  }

  // A finished run is worth celebrating, but only if it was long enough to
  // have been worth waiting for. Two seconds of spinner is not an achievement.
  property real agentBusySince: 0

  signal agentFinished(int seconds)

  onAgentBusyChanged: {
    if (agentBusy) {
      agentBusySince = Date.now()
    } else if (agentBusySince > 0) {
      var seconds = Math.round((Date.now() - agentBusySince) / 1000)
      agentBusySince = 0
      if (seconds >= 45) agentFinished(seconds)
    }
  }

  // ----------------------------------------------------------------- idle

  IdleMonitor {
    id: shortIdle
    enabled: root.enabled
    timeout: 150
    respectInhibitors: false
  }

  IdleMonitor {
    id: longIdle
    enabled: root.enabled
    timeout: 900
    respectInhibitors: false
  }

  readonly property bool away: enabled && shortIdle.isIdle
  readonly property bool longGone: enabled && longIdle.isIdle

  // --------------------------------------------------------------- result
  //
  // One label for "what is going on", used for the gear the creature wears,
  // the pose it strikes, and the line in the panel. Music is deliberately not
  // in here — it layers on top of every one of these.

  readonly property string mode: {
    if (!enabled) return "idle"
    if (away) return "away"
    if (agentBusy) return "agent"
    if (category === "game") return "gaming"
    if (category === "video") return "video"
    if (category === "design") return "making"
    if (category === "editor" || category === "terminal") return "coding"
    if (category === "browser") return "browsing"
    if (category === "chat") return "chatting"
    if (category === "music") return "music"
    return "idle"
  }

  // Compact snapshot for the simulation, which only cares about the handful of
  // facts that change how fast a creature gets sad.
  function context() {
    return {
      mode: root.mode,
      music: root.musicPlaying,
      agentBusy: root.agentBusy,
      away: root.away,
      longGone: root.longGone,
      present: !root.away
    }
  }
}
