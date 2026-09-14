import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Sim.js" as Sim
import "Messages.js" as Msg

// ---------------------------------------------------------------------------
// The bar slot, and the seam between the singleton simulation and the UI.
//
// One of these exists per monitor. None of them owns any state: they all read
// the same creature off the service and route every action back through it, so
// six screens show one animal rather than six.
// ---------------------------------------------------------------------------
BarWidget {
  id: root
  moduleName: "creaza.tamagotchi"

  readonly property string pluginId: "creaza.tamagotchi"

  // ------------------------------------------------------- state plumbing

  // The bar host is handed the shell root, which is where services live. Bar
  // widgets get no direct injection, so this is the one supported way across.
  property var service: null

  function resolveService() {
    if (!bar || !("shell" in bar) || !bar.shell) return
    if (typeof bar.shell.serviceFor !== "function") return
    var found = bar.shell.serviceFor(root.pluginId)
    if (found && found !== root.service) root.service = found
  }

  // Widgets can be constructed before the service loader has walked the
  // plugin list, so retry briefly instead of assuming a one-shot lookup won.
  Timer {
    interval: 400
    repeat: true
    running: root.service === null
    triggeredOnStart: true
    onTriggered: root.resolveService()
  }

  onBarChanged: resolveService()

  // Fallback for an exotic setup where the service is genuinely unreachable —
  // a third-party bar that doesn't forward `shell`, say. Reading the save file
  // gives a correct, if slightly stale, creature and keeps the widget honest
  // rather than blank.
  property var filePet: null

  FileView {
    id: fallbackState
    path: Quickshell.env("HOME") + "/.local/state/omarchy/tamagotchi.json"
    watchChanges: root.service === null
    printErrors: false
    onLoaded: { try { root.filePet = JSON.parse(text()) } catch (e) { root.filePet = null } }
    onFileChanged: reload()
  }

  readonly property var pet: service ? service.pet : filePet
  readonly property var visitor: service && service.social.activeVisit ? service.social.activeVisit.creature : null
  readonly property bool live: service !== null

  // ------------------------------------------------------------- awareness
  //
  // Same singleton story as the creature: one observer in the service, read by
  // every bar slot and by the panel. Null-safe throughout, because a widget
  // can render a frame or two before the service resolves.

  readonly property var senses: service && service.awareness ? service.awareness : null
  readonly property string activityMode: senses ? senses.mode : "idle"
  readonly property bool musicPlaying: senses ? senses.musicPlaying : false
  readonly property int musicBeat: senses ? senses.beat : 0
  readonly property int musicBeatMs: senses ? senses.beatMs : 500
  readonly property string trackTitle: senses ? senses.trackTitle : ""
  readonly property string trackArtist: senses ? senses.trackArtist : ""
  readonly property string agentTask: senses ? senses.agentTask : ""
  readonly property bool agentBusy: senses ? senses.agentBusy : false

  // What the creature thinks you are up to, as one line.
  readonly property string activityLine: {
    var label = Msg.modeLabel(activityMode, language)
    if (label === "") return ""
    var glyph = musicPlaying ? Msg.modeGlyph("music") : Msg.modeGlyph(activityMode)
    var detail = ""
    if (musicPlaying && trackTitle !== "")
      detail = trackArtist !== "" ? (trackArtist + " — " + trackTitle) : trackTitle
    else if (activityMode === "agent" && agentTask !== "")
      detail = agentTask
    var primary = (musicPlaying && (activityMode === "idle" || activityMode === "music"))
      ? Msg.modeLabel("music", language)
      : label
    return glyph + " " + primary + (detail === "" ? "" : " · " + detail)
  }

  function perform(action) {
    if (service) service.perform(action)
    else if (bar) bar.run("omarchy-shell -q tamagotchi " + action)
  }

  // --------------------------------------------------------- derived view

  property real now: Date.now()
  Timer { interval: 10000; repeat: true; running: true; onTriggered: root.now = Date.now() }

  readonly property string language: Msg.lang(setting("language", "en"))
  readonly property var strings: Msg.ui(language)

  readonly property string stageKey: pet ? Sim.stage(pet, now) : "egg"
  readonly property string moodKey: pet ? Sim.mood(pet, now) : "neutral"
  readonly property string needKey: pet ? Sim.primaryNeed(pet, now) : "egg"
  readonly property bool attention: pet ? Sim.needsAttention(pet, now) : false
  readonly property real wellbeing: pet ? Sim.wellbeing(pet) : 50

  // Each generation gets its own hue, mixed a third of the way toward the
  // theme accent so a wild creature still belongs to the desktop it lives on.
  readonly property color creatureTint: {
    var hue = pet ? Sim.seededUnit(pet.seed, 11) : 0.42
    var own = Qt.hsla(hue, 0.52, 0.62, 1)
    return Qt.tint(own, Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18))
  }

  readonly property string statusLine: {
    if (!pet) return "Omarchygotchi"
    var s = pet.stats
    return pet.name + " · " + Msg.stageLabel(stageKey, language)
      + "\n" + Msg.glyph("hungry") + " " + Math.round(s.fullness)
      + "   " + Msg.glyph("lonely") + " " + Math.round(s.happiness)
      + "   " + Msg.glyph("tired") + " " + Math.round(s.energy)
      + "   " + Msg.glyph("dirty") + " " + Math.round(s.hygiene)
      + (pet.sick ? "\n" + Msg.glyph("sick") + " " + strings.sick : "")
      + (activityLine === "" ? "" : "\n" + activityLine)
      + "\n" + strings.hint
  }

  // ------------------------------------------------------------- reactions

  property string reactionText: ""

  // Ids inside an inline Component are scoped to that Component, so the bar
  // slot's particle layer can't be poked from out here. A signal crosses the
  // boundary cleanly and works for however many slots exist.
  signal effectBurst(string effect)

  // A burst plays on every monitor, however the action arrived — panel button,
  // bar click, or a notification the user clicked from another workspace.
  Connections {
    target: root.service
    ignoreUnknownSignals: true
    function onReacted(action, effect, note, ok) { root.playReaction(effect, note, ok) }
    function onCreatureEvent(name) {
      if (name.indexOf("evolve:") === 0) root.playReaction("sparkle", "", true)
    }
  }

  function playReaction(effect, note, ok) {
    if (effect && effect !== "") {
      root.effectBurst(effect)
      if (panelLoader.item) panelLoader.item.burst(effect)
    }
    if (note && note !== "") {
      reactionText = Msg.reaction(note, language, Date.now() / 700)
      reactionTimer.restart()
    }
    if (ok && effect === "star" && panelLoader.item) panelLoader.item.jump()
  }

  Timer { id: reactionTimer; interval: 2600; onTriggered: root.reactionText = "" }

  // ------------------------------------------------------- panel lifecycle
  //
  // Same shape contract the first-party popup widgets implement, so
  // `omarchy-shell shell summon creaza.tamagotchi` and the bar's one-popup-at-
  // a-time coordinator both work without special-casing this plugin.

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.openFromHotkey() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("host" in target) target.host = root
  }

  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  // ------------------------------------------------------------- bar slot

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot + Style.space(root.visitor ? 28 : 4)
    opticalSize: Style.bar.iconCanvas + Style.space(4)
    tooltipText: root.opened ? "" : (root.visitor ? root.visitor.name + " is visiting " + root.pet.name : root.statusLine)

    iconComponent: Item {
      anchors.fill: parent

      Creature {
        id: barCreature
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.visitor && !root.vertical ? -Style.space(12) : 0
        anchors.verticalCenterOffset: root.visitor && root.vertical ? -Style.space(12) : 0
        // Deliberately larger than the icon canvas: the body is 60% of `size`,
        // so matching the canvas exactly would draw a 10px creature in a 26px
        // bar. Nothing clips here, and the slot reserves the width.
        size: parent.width * 1.55
        detail: false
        mood: root.moodKey
        stageKey: root.stageKey
        bodyScale: Sim.stageScale(root.stageKey) * 0.55 + 0.55
        seed: root.pet ? root.pet.seed : 1
        happiness: root.pet ? root.pet.stats.happiness : 60
        tint: root.creatureTint
        inkColor: Color.bar.background
        glowColor: root.creatureTint

        // The bar creature dances too. A 26px pet bobbing in time with your
        // music is the whole reason to put it up there.
        activity: root.activityMode
        music: root.musicPlaying
        beat: root.musicBeat
        beatMs: root.musicBeatMs
      }

      Creature {
        visible: root.visitor !== null
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.vertical ? 0 : Style.space(12)
        anchors.verticalCenterOffset: root.vertical ? Style.space(12) : 0
        size: parent.width * 1.55; detail: false; animated: false
        seed: root.visitor ? root.visitor.seed : 0
        stageKey: root.visitor ? root.visitor.stage : "adult"
        bodyScale: Sim.stageScale(stageKey) * 0.55 + 0.55
        mood: "happy"
        tint: Qt.hsla(Sim.seededUnit(seed, 11), 0.52, 0.62, 1)
        inkColor: Color.bar.background
      }

      // Attention badge. Placed at the top-right of the slot and pulsing, so a
      // hungry creature is visible from across the room without reading text.
      Rectangle {
        id: badge
        visible: root.attention
        width: Math.max(5, parent.width * 0.30)
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -width * 0.18
        anchors.topMargin: -height * 0.10
        color: root.needKey === "dead" ? Qt.darker(Color.bar.text, 1.2) : Color.bar.active
        border.width: 1
        border.color: Color.bar.background

        // Two quick beats, then a long rest. An always-animating badge would
        // repaint the whole bar every frame for as long as the creature is
        // hungry, which could be hours.
        SequentialAnimation on scale {
          running: badge.visible
          loops: Animation.Infinite
          NumberAnimation { to: 1.4; duration: 190; easing.type: Easing.OutCubic }
          NumberAnimation { to: 1.0; duration: 260; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1.3; duration: 170; easing.type: Easing.OutCubic }
          NumberAnimation { to: 1.0; duration: 240; easing.type: Easing.InOutSine }
          PauseAnimation { duration: 3200 }
        }
      }

      Sparkles {
        id: barSparkles
        anchors.fill: parent
        originX: width / 2
        originY: height / 2
        spread: parent.width * 0.9
        glyphSize: Math.max(7, parent.width * 0.42)
        inkColor: Color.bar.text

        Connections {
          target: root
          function onEffectBurst(effect) { barSparkles.burst(effect) }
        }
      }
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) root.perform("feed")
      else if (b === Qt.MiddleButton) root.perform("pet")
      else root.togglePanel()
    }
  }
}
