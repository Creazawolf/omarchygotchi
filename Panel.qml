import QtQuick
import qs.Commons
import qs.Ui
import "Sim.js" as Sim
import "Messages.js" as Msg

// ---------------------------------------------------------------------------
// The habitat. A framed little world with the creature living in it, its care
// meters underneath, and the buttons that keep it alive.
//
// This file holds no state of its own beyond presentation: everything it draws
// comes off `host.pet`, and every button routes back through `host.perform()`
// so the panel, the bar and a clicked notification are all the same action.
// ---------------------------------------------------------------------------
Panel {
  id: root
  moduleName: "creaza.tamagotchi"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var host: null
  property bool communityTab: false
  property bool careExpanded: false
  readonly property var social: host && host.service ? host.service.social : null
  readonly property var activeVisit: social ? social.activeVisit : null
  readonly property var latestVisit: social && (social.snapshot.visits || []).length ? social.snapshot.visits[0] : null
  readonly property var householdChild: social ? social.householdChild : null
  onCommunityTabChanged: if (typeof scroll !== "undefined") scroll.contentY = 0

  readonly property var barIdentity: hostWidget || root

  // ------------------------------------------------------------- lifecycle

  function openFromHotkey() { root.controller.show() }
  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? close() : open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function burst(effect) { sparkles.burst(effect) }
  function jump() { creature.jump() }

  // ------------------------------------------------------------ view model

  readonly property var pet: host ? host.pet : null
  readonly property real now: host ? host.now : Date.now()
  readonly property string language: host ? host.language : "en"
  readonly property var strings: Msg.ui(language)
  readonly property string stageKey: host ? host.stageKey : "egg"
  readonly property string moodKey: host ? host.moodKey : "neutral"
  readonly property string needKey: host ? host.needKey : "egg"
  readonly property color tint: host ? host.creatureTint : Color.accent

  readonly property bool dead: pet ? Sim.isDead(pet) : false
  readonly property bool asleep: pet ? pet.asleep === true : false
  readonly property bool sick: pet ? pet.sick === true : false
  readonly property bool isEgg: stageKey === "egg"
  readonly property var stats: pet ? pet.stats : ({ fullness: 0, happiness: 0, energy: 0, hygiene: 0, health: 0 })

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.4)

  // ------------------------------------------------------------- awareness

  readonly property string activityMode: host ? host.activityMode : "idle"
  readonly property bool musicPlaying: host ? host.musicPlaying : false
  readonly property int musicBeat: host ? host.musicBeat : 0
  readonly property int musicBeatMs: host ? host.musicBeatMs : 500
  readonly property string activityLine: host ? host.activityLine : ""
  readonly property bool attention: host ? host.attention : false

  // ---------------------------------------------------------- time of day
  //
  // The habitat is lit by your actual clock. Nothing in the simulation depends
  // on it — it exists so that glancing at the panel at 23:40 feels different
  // from glancing at it at 09:00.

  readonly property real hourFrac: {
    var d = new Date(now)
    return d.getHours() + d.getMinutes() / 60
  }

  readonly property real nightness: {
    var h = hourFrac
    if (h >= 21 || h < 5) return 1
    if (h < 7) return 1 - (h - 5) / 2
    if (h < 19) return 0
    return (h - 19) / 2
  }

  // Peaks at sunrise and sunset, and only then.
  readonly property real warmth: {
    var h = hourFrac
    if (h >= 5 && h < 8) return Math.max(0, 1 - Math.abs(h - 6.5) / 1.5)
    if (h >= 18 && h < 21) return Math.max(0, 1 - Math.abs(h - 19.5) / 1.5)
    return 0
  }

  function mixColor(a, b, t) {
    var k = Math.max(0, Math.min(1, t))
    return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1)
  }

  readonly property color sunsetColor: Qt.rgba(0.74, 0.38, 0.24, 1)
  readonly property color skyBase: Color.popups.background

  readonly property color skyTop: mixColor(
    mixColor(Qt.lighter(skyBase, 1.12), Qt.darker(skyBase, 1.32), nightness),
    sunsetColor, warmth * 0.20)

  readonly property color skyBottom: mixColor(
    mixColor(Qt.lighter(skyBase, 1.26), Qt.lighter(skyBase, 1.04), nightness),
    sunsetColor, warmth * 0.34)

  readonly property bool isNight: nightness > 0.5

  // One body crosses the sky: the sun between 06 and 18, the moon overnight.
  readonly property real skyBodyT: {
    var h = hourFrac
    if (!isNight) return Math.max(0, Math.min(1, (h - 6) / 12))
    var nh = h >= 21 ? h - 21 : h + 3
    return Math.max(0, Math.min(1, nh / 8))
  }

  // A reaction to whatever the user just did wins the bubble for a couple of
  // seconds; the rest of the time the creature comments on its own condition.
  readonly property string bubbleText: {
    if (host && host.reactionText !== "") return host.reactionText
    // A complaint outranks small talk; otherwise it comments on whatever you
    // are doing, and only falls back to generic contentment when nothing is.
    if (attention || asleep || isEgg) return Msg.bubble(needKey, language, Math.floor(now / 45000))
    var mode = musicPlaying && activityMode === "idle" ? "music" : activityMode
    var line = Msg.bubbleMode(mode, language, Math.floor(now / 45000))
    return line !== "" ? line : Msg.bubble(needKey, language, Math.floor(now / 45000))
  }

  function ageText() {
    if (!pet) return ""
    // A dead creature's age is how long it lived, not how long ago it was
    // born — a headstone that keeps counting is just cruel.
    var h = ((pet.diedAt || now) - pet.bornAt) / 3600000
    if (h < 1) return Math.max(1, Math.round(h * 60)) + strings.minutes
    if (h < 48) return (Math.round(h * 10) / 10) + strings.hours
    return (Math.round(h / 24 * 10) / 10) + strings.days
  }

  function growthText() {
    if (!pet || dead) return ""
    var h = Sim.hoursToNextStage(pet, now)
    if (h < 0) return strings.fullyGrown
    return strings.growsIn + " " + (h < 1 ? Math.round(h * 60) + strings.minutes
                                          : (Math.round(h * 10) / 10) + strings.hours)
  }

  function act(action) { if (host) host.perform(action) }

  // ------------------------------------------------------------- wandering
  //
  // With nothing else going on the creature strolls around its box. This is
  // the single cheapest thing that stops the habitat reading as a portrait.
  // It is suppressed whenever it is doing something that implies standing
  // still — dancing, or holding a laptop.

  property real walkOffset: 0
  property real walkDir: 1
  property bool wandering: false

  readonly property bool canWander: opened && !dead && !isEgg && !asleep && !musicPlaying
    && (activityMode === "idle" || activityMode === "chatting" || activityMode === "browsing")

  Timer {
    id: wanderTimer
    interval: 3200
    repeat: true
    running: root.canWander
    onTriggered: {
      interval = 3200 + Math.random() * 5200
      var span = terrarium.width * 0.28
      var target = (Math.random() * 2 - 1) * span
      if (Math.abs(target - root.walkOffset) < span * 0.25) return
      root.walkDir = target > root.walkOffset ? 1 : -1
      walkAnim.to = target
      walkAnim.duration = Math.max(900, Math.abs(target - root.walkOffset) * 24)
      walkAnim.restart()
    }
  }

  NumberAnimation {
    id: walkAnim
    target: root
    property: "walkOffset"
    easing.type: Easing.InOutSine
    onRunningChanged: root.wandering = running
  }

  NumberAnimation {
    id: walkHomeAnim
    target: root
    property: "walkOffset"
    to: 0
    duration: 700
    easing.type: Easing.InOutSine
  }

  onCanWanderChanged: {
    if (canWander) return
    walkAnim.stop()
    wandering = false
    if (Math.abs(walkOffset) > 1) walkHomeAnim.restart()
  }

  // The button that answers the current complaint is highlighted, so the
  // panel says what to do next without a line of instructions.
  readonly property var needAction: ({
    hungry: "feed", peckish: "snack", bored: "play", lonely: "pet",
    dirty: "clean", poop: "clean", tired: "sleep", sick: "medicine", egg: "hatch"
  })
  function isSuggested(action) { return !dead && needAction[needKey] === action }

  // Buttons that would only ever be refused are disabled rather than hidden:
  // a stable grid you can learn beats one that reshuffles every time the
  // creature falls asleep.
  function canAct(action) {
    if (!pet || dead) return false
    if (isEgg) return action === "hatch"
    if (action === "medicine") return sick
    if (action === "wake") return asleep
    if (action === "sleep") return !asleep
    if (action === "clean") return true
    return !asleep
  }

  // ------------------------------------------------------------------ view

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(410))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      blocked: communityPanel.editing
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (root.communityTab) return
        var map = { f: "feed", s: "snack", p: "pet", l: "play", c: "clean", m: "medicine", z: root.asleep ? "wake" : "sleep" }
        var action = map[String(t).toLowerCase()]
        if (action && root.canAct(action)) root.act(action)
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        Flow {
          width: parent.width
          spacing: Style.space(6)
          Button { text: "Creature"; selected: !root.communityTab; bordered: true; foreground: root.fg; onClicked: root.communityTab = false }
          Button { text: "Community"; selected: root.communityTab; bordered: true; foreground: root.fg; onClicked: root.communityTab = true }
        }
        CommunityPanel {
          id: communityPanel
          onRevealRequested: function(offset) { Qt.callLater(function() { scroll.contentY = Math.max(0, Math.min(communityPanel.y + offset, scroll.contentHeight - scroll.height)) }) }
          active: root.opened
          width: parent.width
          visible: root.communityTab
          social: root.host && root.host.service ? root.host.service.social : null
          foreground: root.fg
        }
        Column {
          width: parent.width
          spacing: Style.space(12)
          visible: !root.communityTab
        // ---------------------------------------------------- the habitat
        Rectangle {
          id: terrarium
          width: parent.width
          height: root.activeVisit ? width * 0.625 : Style.space(210)
          radius: Math.max(Style.cornerRadius, Style.space(6))
          clip: true
          border.width: 1
          border.color: Style.normalBorderFor(root.fg, Color.accent)

          gradient: Gradient {
            GradientStop { position: 0.0; color: root.skyTop }
            GradientStop { position: 1.0; color: root.skyBottom }
          }

          // Sun by day, moon by night, on the arc your clock says it should be
          // on. The moon gets a bite taken out of it in the sky colour, which
          // is the cheapest crescent there is.
          Item {
            id: skyBody
            width: Style.space(root.isNight ? 22 : 26)
            height: width
            x: terrarium.width * (0.10 + root.skyBodyT * 0.80) - width / 2
            y: terrarium.height * 0.40 - Math.sin(root.skyBodyT * Math.PI) * terrarium.height * 0.30 - height / 2
            opacity: 0.85

            Behavior on x { NumberAnimation { duration: 1200; easing.type: Easing.InOutSine } }
            Behavior on y { NumberAnimation { duration: 1200; easing.type: Easing.InOutSine } }

            Rectangle {
              anchors.centerIn: parent
              width: parent.width * 2.1
              height: width
              radius: width / 2
              color: root.isNight ? "#c9d6ea" : "#f6c85a"
              opacity: 0.10
            }

            Rectangle {
              id: disc
              anchors.fill: parent
              radius: width / 2
              color: root.isNight ? "#dfe6f0" : "#f6c85a"
            }

            Rectangle {
              visible: root.isNight
              width: parent.width * 0.86
              height: width
              radius: width / 2
              x: parent.width * 0.30
              y: -parent.height * 0.14
              color: root.skyTop
            }
          }

          // Faint columns of nonsense syntax drifting down behind the creature
          // while an agent is working. Deliberately barely there — it is
          // atmosphere, not a readout.
          Item {
            id: agentRain
            visible: root.opened && root.activityMode === "agent" && !root.dead
            anchors.fill: parent
            clip: true
            opacity: 0.15

            Repeater {
              model: 7
              Text {
                id: rainCol
                required property int index
                readonly property string glyphs: "01{}</>=;:*+#$&|~"
                text: {
                  var out = ""
                  for (var i = 0; i < 16; i++) out += glyphs.charAt((index * 5 + i * 3) % glyphs.length) + "\n"
                  return out
                }
                x: (index + 0.5) * agentRain.width / 7
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.caption

                NumberAnimation on y {
                  running: agentRain.visible
                  from: -rainCol.implicitHeight
                  to: agentRain.height
                  duration: 5200 + rainCol.index * 900
                  loops: Animation.Infinite
                }
              }
            }
          }

          // Twinkling backdrop. Positions come from a fixed hash so the sky
          // doesn't reshuffle every time the panel opens.
          Repeater {
            model: 22
            Rectangle {
              id: star
              required property int index
              readonly property real rx: ((index * 2654435761) % 997) / 997
              readonly property real ry: ((index * 40503 + 17) % 641) / 641
              width: 1 + (index % 3)
              height: width
              radius: width / 2
              x: rx * terrarium.width
              y: ry * terrarium.height * 0.72
              color: root.fg
              opacity: 0
              visible: root.nightness > 0.02

              // Twinkle amplitude rides the clock, so the sky empties out over
              // breakfast instead of switching off.
              SequentialAnimation on opacity {
                running: root.opened && star.visible
                loops: Animation.Infinite
                PauseAnimation { duration: star.index * 190 }
                NumberAnimation { to: 0.42 * root.nightness; duration: 1200 + star.index * 40 }
                NumberAnimation { to: 0.10 * root.nightness; duration: 1400 + star.index * 30 }
              }
            }
          }

          // Ground: one soft ellipse the creature stands on, which is what
          // turns a floating drawing into a scene.
          Rectangle {
            width: terrarium.width * 1.5
            height: Style.space(84)
            radius: width / 2
            anchors.horizontalCenter: parent.horizontalCenter
            y: terrarium.height - Style.space(38)
            color: Qt.lighter(root.tint, 1.05)
            opacity: 0.13
          }

          // Music makes the floor light up. Each bar's height is a pure hash of
          // (beat, index), so the whole row re-rolls exactly on the beat with
          // no timers of its own — the Behavior does the animating.
          Row {
            id: equalizer
            visible: root.opened && root.musicPlaying && !root.dead
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: terrarium.width
            height: Style.space(20)
            spacing: Style.space(3)
            opacity: 0.32

            Repeater {
              model: 15
              Rectangle {
                id: eqBar
                required property int index
                readonly property real level: {
                  var h = Math.sin(root.musicBeat * 12.9898 + index * 78.233) * 43758.5453
                  return Math.abs(h - Math.floor(h))
                }
                anchors.bottom: parent.bottom
                width: (equalizer.width - equalizer.spacing * 14) / 15
                height: Style.space(3) + level * Style.space(16)
                radius: Style.space(2)
                color: Qt.lighter(root.tint, 1.25)

                Behavior on height {
                  NumberAnimation { duration: Math.max(90, root.musicBeatMs * 0.42); easing.type: Easing.OutQuad }
                }
              }
            }
          }

          Creature {
            id: creature
            size: Style.space(168)
            x: terrarium.width / 2 - width / 2 + (root.householdChild ? -Style.space(44) : root.walkOffset)
            // A ghost floats clear of the epitaph beneath it; everything else
            // stands on the ground.
            y: terrarium.height - size * (root.dead ? 1.12 : 0.93)
            Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
            detail: true
            mood: root.moodKey
            stageKey: root.stageKey
            bodyScale: Sim.stageScale(root.stageKey)
            seed: root.pet ? root.pet.seed : 1
            happiness: root.stats.happiness
            tint: root.tint
            inkColor: Qt.darker(Color.popups.background, 1.6)
            glowColor: root.tint
            animated: root.opened

            activity: root.activityMode
            music: root.musicPlaying
            beat: root.musicBeat
            beatMs: root.musicBeatMs
            walking: root.wandering
            walkDir: root.walkDir
          }

          Sparkles {
            id: sparkles
            anchors.fill: parent
            originX: terrarium.width / 2
            originY: terrarium.height * 0.52
            spread: Style.space(78)
            glyphSize: Style.font.title
            inkColor: root.fg
          }

          // Petting the creature directly is the interaction people try first.
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: root.canAct("pet") ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
              if (root.dead) root.act("newEgg")
              else if (root.isEgg) root.act("hatch")
              else if (root.canAct("pet")) root.act("pet")
              else root.act("wake")
            }
          }

          // ---- name plate
          Column {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Style.space(10)
            spacing: Style.space(1)

            Text {
              text: root.pet ? root.pet.name : "—"
              textFormat: Text.PlainText
              color: root.fg
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: Msg.stageLabel(root.stageKey, root.language) + " · " + root.ageText()
              textFormat: Text.PlainText
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.8
            }

            // What it thinks you are doing. The line the whole awareness layer
            // exists to be able to write.
            Text {
              text: root.activityLine
              visible: text !== "" && !root.dead
              textFormat: Text.PlainText
              width: terrarium.width * 0.56
              elide: Text.ElideRight
              color: root.dim
              opacity: 0.85
              topPadding: Style.space(3)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          // ---- generation chip
          Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(10)
            text: "GEN " + (root.pet ? root.pet.generation : 1)
            textFormat: Text.PlainText
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
          }

          // ---- speech bubble
          Item {
            id: bubble
            visible: !root.dead && root.bubbleText !== ""
            anchors.right: parent.right
            anchors.rightMargin: Style.space(14)
            y: Style.space(46)
            width: bubbleBg.width
            height: bubbleBg.height + tail.height

            opacity: 0
            scale: 0.9
            states: State {
              name: "shown"
              when: bubble.visible
              PropertyChanges { target: bubble; opacity: 1; scale: 1 }
            }
            transitions: Transition {
              NumberAnimation { properties: "opacity,scale"; duration: 220; easing.type: Easing.OutBack }
            }

            Rectangle {
              id: bubbleBg
              width: bubbleText.implicitWidth + Style.space(20)
              height: bubbleText.implicitHeight + Style.space(11)
              radius: height / 2
              color: root.fg
              opacity: 0.92

              Text {
                id: bubbleText
                anchors.centerIn: parent
                text: root.bubbleText
                textFormat: Text.PlainText
                color: Color.popups.background
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
            }

            // Tail, drawn as a rotated square poking out of the bubble's
            // bottom-left — cheaper than a path and pixel-identical.
            Rectangle {
              id: tail
              width: Style.space(9)
              height: width
              x: Style.space(14)
              y: bubbleBg.height - height * 0.55
              rotation: 45
              color: root.fg
              opacity: 0.92
            }
          }

          // ---- droppings
          Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Style.space(10)
            spacing: Style.space(3)
            visible: root.pet && root.pet.poops > 0 && !root.dead

            Repeater {
              model: root.pet ? root.pet.poops : 0
              Text {
                required property int index
                text: "💩"
                font.pixelSize: Style.font.body
                opacity: 0.9
              }
            }
          }

          // ---- status corner
          Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Style.space(10)
            spacing: Style.space(6)

            Text {
              visible: root.sick && !root.dead
              text: "🤒"
              font.pixelSize: Style.font.body
            }
            Text {
              visible: root.asleep && !root.dead
              text: "💤"
              font.pixelSize: Style.font.body
            }
            Text {
              text: root.growthText()
              visible: text !== "" && !root.dead
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          // ---- memorial
          // The scrim fades in from the bottom rather than covering the whole
          // frame: the ghost stays the picture, and the epitaph sits under it.
          Rectangle {
            anchors.fill: parent
            visible: root.dead

            gradient: Gradient {
              GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.00) }
              GradientStop { position: 0.48; color: Qt.rgba(0, 0, 0, 0.12) }
              GradientStop { position: 0.74; color: Qt.rgba(0, 0, 0, 0.58) }
              GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.86) }
            }

            Column {
              anchors.bottom: parent.bottom
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottomMargin: Style.space(12)
              spacing: Style.space(5)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (root.pet ? root.pet.name : "") + " · " + root.strings.generation + " " + (root.pet ? root.pet.generation : 1)
                textFormat: Text.PlainText
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.ageText() + "  ·  " + root.strings.cause + ": "
                      + (root.pet ? (root.strings.causes[root.pet.causeOfDeath] || root.pet.causeOfDeath) : "")
                textFormat: Text.PlainText
                color: root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
              Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.strings.newEgg
                iconText: "🥚"
                bordered: true
                focusable: true
                foreground: root.fg
                accent: root.tint
                onClicked: root.act("newEgg")
              }
            }
          }
          SharedScene {
            anchors.fill: parent
            visible: root.activeVisit !== null
            scene: root.activeVisit ? root.activeVisit.scene : null
            caption: root.activeVisit ? root.activeVisit.scene.participants.map(function(p) { return p.name }).join(" & ") + " " + root.activeVisit.activity + "." : ""
            eyebrow: "A VISITOR IS HERE"
            animated: root.opened && visible
            child: root.householdChild
          }
          Creature {
            visible: root.householdChild !== null && !root.activeVisit
            x: parent.width * 0.60; y: parent.height - size * 0.92; size: Style.space(95)
            seed: root.householdChild ? root.householdChild.seed : 0
            stageKey: root.householdChild ? root.householdChild.stage : "egg"
            bodyScale: Sim.stageScale(stageKey); mood: "happy"; animated: root.opened && visible
            tint: Qt.hsla(Sim.seededUnit(root.householdChild ? root.householdChild.colorSeed : 0, 11), 0.52, 0.62, 1)
          }
        }
        Text {
          width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
          text: root.pet ? root.pet.name + " · " + Sim.personality(root.pet) + (root.pet.reunionAt && root.now - root.pet.reunionAt < 3600000 ? "\nYou’re back. I saved your spot." : "") : ""
          color: root.fg; font.pixelSize: Style.font.body
        }
        Text {
          width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
          text: root.latestVisit ? "Last time: " + root.latestVisit.creature.name + " and " + root.pet.name + " " + root.latestVisit.activity + "." + (root.latestVisit.scene ? "\nKept: " + root.latestVisit.scene.keepsake + "." : "") : "A quiet moment at home. The park is where shared stories begin."
          color: root.fg; font.pixelSize: Style.font.caption
        }
        Text {
          width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
          text: {
            var bonds = root.social ? root.social.snapshot.bonds || [] : []
            return bonds.length ? "Who matters: " + bonds.slice(0,3).map(function(b) { return b.creature.name + " (" + b.level + ")" }).join(", ") + "." : "There’s room for a friend beside me."
          }
          color: Color.accent; font.pixelSize: Style.font.caption
        }
        Text {
          width: parent.width; wrapMode: Text.WordWrap
          text: root.activeVisit ? "Stay a while. This visit lasts about fifteen minutes." : root.social && root.social.roaming ? "Next: another visit when a playmate is available. Your album keeps the memories." : "Next: invite a familiar face or meet someone new in the park."
          color: root.fg; opacity: 0.7; font.pixelSize: Style.font.caption
        }
        Flow {
          width: parent.width; spacing: Style.space(6)
          Button { text: "Stories & family"; bordered: true; foreground: root.fg; onClicked: root.communityTab = true }
          Button { text: root.careExpanded ? "Close care" : "A little care"; bordered: true; foreground: root.fg; onClicked: root.careExpanded = !root.careExpanded }
        }

        // ------------------------------------------------------- the meters
        Column {
          visible: root.careExpanded
          width: parent.width
          spacing: Style.space(1)
          opacity: root.dead ? 0.35 : 1
          Behavior on opacity { NumberAnimation { duration: 300 } }

          StatBar {
            width: parent.width
            glyph: "🍖"; label: Msg.statLabel("fullness", root.language)
            value: root.stats.fullness; foreground: root.fg; urgent: root.bar ? root.bar.urgent : Color.urgent
            dimmed: root.dead
          }
          StatBar {
            width: parent.width
            glyph: "💛"; label: Msg.statLabel("happiness", root.language)
            value: root.stats.happiness; foreground: root.fg; urgent: root.bar ? root.bar.urgent : Color.urgent
            dimmed: root.dead
          }
          StatBar {
            width: parent.width
            glyph: "⚡"; label: Msg.statLabel("energy", root.language)
            value: root.stats.energy; foreground: root.fg; urgent: root.bar ? root.bar.urgent : Color.urgent
            dimmed: root.dead
          }
          StatBar {
            width: parent.width
            glyph: "🧼"; label: Msg.statLabel("hygiene", root.language)
            value: root.stats.hygiene; foreground: root.fg; urgent: root.bar ? root.bar.urgent : Color.urgent
            dimmed: root.dead
          }
          StatBar {
            width: parent.width
            glyph: "❤️"; label: Msg.statLabel("health", root.language)
            value: root.stats.health; foreground: root.fg; urgent: root.bar ? root.bar.urgent : Color.urgent
            dimmed: root.dead
          }
        }

        PanelSeparator { visible: root.careExpanded; width: parent.width; foreground: root.fg }

        // ------------------------------------------------------- the buttons
        Flow {
          visible: root.careExpanded
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: [
              { key: "feed",     label: root.strings.feed },
              { key: "snack",    label: root.strings.snack },
              { key: "pet",      label: root.strings.pet },
              { key: "play",     label: root.strings.play },
              { key: "clean",    label: root.strings.clean },
              { key: "medicine", label: root.strings.medicine },
              { key: root.asleep ? "wake" : "sleep",
                label: root.asleep ? root.strings.wake : root.strings.sleep }
            ]

            Button {
              required property var modelData
              text: modelData.label
              iconText: Msg.actionGlyph(modelData.key)
              bordered: true
              focusable: true
              foreground: root.fg
              accent: root.tint
              enabled: root.canAct(modelData.key)
              selected: root.isSuggested(modelData.key)
              opacity: enabled ? 1 : 0.38
              onClicked: root.act(modelData.key)
            }
          }

          Button {
            visible: root.isEgg && !root.dead
            text: root.strings.hatch
            iconText: "🥚"
            bordered: true
            focusable: true
            foreground: root.fg
            accent: root.tint
            onClicked: root.act("hatch")
          }
        }

        }
      }
      }
    }
  }
}
