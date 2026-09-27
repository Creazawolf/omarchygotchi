pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "Sim.js" as Sim

// ---------------------------------------------------------------------------
// The creature itself. Drawn entirely from primitives — no images, no fonts,
// no emoji — so it scales from a 16px bar slot to a 190px panel hero without
// a single blurry pixel, and picks up theme colours as they change.
//
// Everything is expressed in `u` (one hundredth of `size`), so the whole body
// is one number away from any size. Set `detail: false` for the bar, where
// feet, arms, crowns and shadows just turn into mud.
// ---------------------------------------------------------------------------
Item {
  id: root

  property real size: 120
  property bool detail: true

  // Simulation inputs.
  property string mood: "neutral"        // neutral happy ecstatic sad hungry tired asleep sick weak egg dead
  property string stageKey: "adult"      // egg baby kid teen adult elder ghost
  property real bodyScale: 1.0           // from Sim.stageScale()
  property int seed: 12345
  // A family's child: seeds the eyes it has of its own (Sim.traits).
  property int ownSeed: 0
  property real happiness: 70            // 0..100, drives the mouth curve
  property bool animated: true
  // Calm motion: the creature keeps its expressions and props but stops
  // dancing, and hatches with a fade instead of knocks and flying shell.
  property bool calm: false

  // Awareness inputs. `activity` is Awareness.mode; `music` layers on top of
  // it, because a creature can dance and hold a laptop at the same time.
  property string activity: "idle"
  property bool music: false
  property int beat: 0
  property int beatMs: 500

  // Set by the panel while it walks the creature across the habitat; the
  // creature owns the gait, the panel owns where it is going.
  property bool walking: false
  property real walkDir: 1

  // Seasonal dress-up from Sim.season(); "" most of the year.
  property string costume: ""

  // Theme inputs.
  property color tint: "#7fd1c1"         // creature's own colour, derived per generation
  property color inkColor: "#101315"     // eyes, mouth, outlines
  property color glowColor: tint

  readonly property real u: size / 100

  // Stable per-creature randomness for decorative placement. Same seed, same
  // freckles, every restart — the creature has to look like itself.
  function seededRand(salt) {
    var h = (seed ^ ((salt + 1) * 2654435761)) >>> 0
    h ^= h >>> 15; h = (h * 2246822507) >>> 0
    h ^= h >>> 13
    return (h >>> 8) / 16777215
  }
  readonly property bool isEgg: stageKey === "egg"
  readonly property bool isGhost: mood === "dead" || stageKey === "ghost"
  readonly property bool asleep: mood === "asleep"

  // What the gear layer is asked to show. An egg wears nothing, a ghost has no
  // hands, and a sleeping creature puts its things down — except the nightcap
  // it went to bed in.
  readonly property string gearActivity: (isEgg || isGhost) ? ""
                                       : (asleep && activity !== "away") ? ""
                                       : activity
  // A costume hat gives way to the hats that mean something: the propeller
  // (an agent is working) and the nightcap.
  readonly property bool costumeHat: costume === "witch" && !isEgg && !isGhost
                                     && gearActivity !== "agent" && gearActivity !== "away"

  implicitWidth: size
  implicitHeight: size

  // --------------------------------------------------------------- palette

  readonly property color bodyLight: Qt.lighter(tint, 1.22)
  readonly property color bodyDark: Qt.darker(tint, 1.30)
  readonly property color sickTint: Qt.rgba(0.55, 0.80, 0.45, 1)
  readonly property color effectiveTint: mood === "sick" ? Qt.tint(tint, Qt.rgba(sickTint.r, sickTint.g, sickTint.b, 0.55)) : tint

  // ------------------------------------------------------------ animation
  //
  // Four cheap oscillators drive everything. Keeping them as plain numbers
  // (instead of animating geometry directly) means the body, arms, ears and
  // shadow can all read the same breath and stay in phase.

  property real breath: 0        // -1..1 slow body swell
  property real bob: 0           // -1..1 vertical float
  property real sway: 0          // -1..1 horizontal lean
  property real blink: 1         // 1 open, 0 shut
  property real hop: 0           // 0..1 one-shot excitement bounce
  property real lookX: 0         // -1..1 pupil drift
  property real lookY: 0

  // ------------------------------------------------------- animation budget
  //
  // Any animating item repaints its whole window that frame, and a bar spans
  // the entire monitor. Measured on this machine: one continuously animating
  // 6x6 rectangle in the bar costs ~10% of a core all by itself, whatever else
  // is on screen — so the cost is the *fraction of frames that change*, not the
  // creature's complexity.
  //
  // So the bar creature only animates what is actually visible at 20px: it
  // blinks, it bounces on the beat, it hops when delighted, and it is perfectly
  // still the rest of the time. Breathing (a 0.4px swell) and pupil drift
  // (under a pixel) are panel-only. Changes that land on the same frame share
  // one repaint, which is why the dance bounce and the headphone pulse are both
  // driven off the beat rather than off their own clocks.
  readonly property bool smooth: detail

  readonly property real energyRate: mood === "ecstatic" ? 0.55 : (asleep ? 1.9 : (mood === "tired" || mood === "weak" ? 1.7 : 1.0))

  SequentialAnimation on breath {
    running: root.animated && root.smooth
    loops: Animation.Infinite
    NumberAnimation { to:  1; duration: Math.round(1400 * root.energyRate); easing.type: Easing.InOutSine }
    NumberAnimation { to: -1; duration: Math.round(1400 * root.energyRate); easing.type: Easing.InOutSine }
  }

  SequentialAnimation on bob {
    running: root.animated && root.smooth
    loops: Animation.Infinite
    NumberAnimation { to:  1; duration: Math.round(1900 * root.energyRate); easing.type: Easing.InOutSine }
    NumberAnimation { to: -1; duration: Math.round(1900 * root.energyRate); easing.type: Easing.InOutSine }
  }

  SequentialAnimation on sway {
    running: root.animated && root.smooth
    loops: Animation.Infinite
    NumberAnimation { to:  1; duration: Math.round(2600 * root.energyRate); easing.type: Easing.InOutSine }
    NumberAnimation { to: -1; duration: Math.round(2600 * root.energyRate); easing.type: Easing.InOutSine }
  }

  // Blinking is the single cheapest trick that makes a drawing look alive, so
  // it gets randomised intervals and the occasional double blink.
  Timer {
    running: root.animated && !root.asleep && !root.isGhost && !root.isEgg && !root.hatching
    interval: 1600 + Math.random() * 4200
    repeat: true
    onTriggered: { blinkAnim.restart(); interval = 1600 + Math.random() * 4200 }
  }

  SequentialAnimation {
    id: blinkAnim
    NumberAnimation { target: root; property: "blink"; to: 0.06; duration: root.smooth ? 70 : 0; easing.type: Easing.OutQuad }
    PauseAnimation { duration: root.smooth ? 0 : 95 }
    NumberAnimation { target: root; property: "blink"; to: 1;    duration: root.smooth ? 110 : 0; easing.type: Easing.InQuad }
    PauseAnimation { duration: 90 }
    ScriptAction { script: if (Math.random() < 0.22) doubleBlink.start() }
  }

  SequentialAnimation {
    id: doubleBlink
    NumberAnimation { target: root; property: "blink"; to: 0.06; duration: root.smooth ? 70 : 0 }
    PauseAnimation { duration: root.smooth ? 0 : 95 }
    NumberAnimation { target: root; property: "blink"; to: 1;    duration: root.smooth ? 110 : 0 }
  }

  // Eyes wander. Without this the creature stares straight through you, which
  // reads as a sprite; with it, it reads as a thing that noticed you.
  Timer {
    running: root.animated && root.smooth && !root.asleep && !root.isGhost
    interval: 900 + Math.random() * 2600
    repeat: true
    onTriggered: {
      root.lookX = (Math.random() * 2 - 1) * 0.8
      root.lookY = (Math.random() * 2 - 1) * 0.55
      interval = 900 + Math.random() * 2600
    }
  }

  Behavior on lookX { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
  Behavior on lookY { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

  // ----------------------------------------------------------- choreography
  //
  // Dancing is not one loop. Every eight beats the creature picks a different
  // move — bounce, side-step, spin, arms up — which is the whole difference
  // between "an animation is playing" and "it is dancing".

  readonly property bool dancing: music && animated && !calm && !asleep && !isGhost && !isEgg && mood !== "sick"

  property real danceHop: 0        // 0..1, one impulse per beat
  property real danceLean: 1       // -1/1, flips every other beat
  property real spinAngle: 0       // the spin move, degrees
  property int danceMove: 0        // 0 bounce · 1 side-step · 2 spin · 3 arms up
  property int beatIndex: 0

  onBeatChanged: {
    if (!dancing) return
    beatIndex++
    if (beatIndex % 8 === 0) danceMove = Math.floor(Math.random() * 4)
    if (beatIndex % 2 === 0) danceLean = danceLean > 0 ? -1 : 1
    danceHopAnim.restart()
    if (danceMove === 2 && beatIndex % 8 === 1) spinAnim.restart()
  }

  onDancingChanged: if (!dancing) { danceHop = 0; spinAngle = 0 }

  // Smooth where it can be seen, snapped where it cannot: in the bar this is
  // two property changes per beat rather than a full beat of 60fps easing, and
  // at that size the pop reads as a bounce anyway.
  SequentialAnimation {
    id: danceHopAnim
    NumberAnimation { target: root; property: "danceHop"; to: 1; duration: root.smooth ? 70 : 0; easing.type: Easing.OutQuad }
    PauseAnimation { duration: root.smooth ? 0 : 130 }
    NumberAnimation { target: root; property: "danceHop"; to: 0; duration: root.smooth ? Math.max(110, root.beatMs - 70) : 0; easing.type: Easing.OutQuad }
  }

  NumberAnimation {
    id: spinAnim
    target: root; property: "spinAngle"
    from: 0; to: 360
    duration: Math.max(320, root.beatMs * 2)
    easing.type: Easing.InOutQuad
  }

  Behavior on danceLean {
    enabled: root.smooth
    NumberAnimation { duration: Math.max(90, root.beatMs * 0.55); easing.type: Easing.InOutSine }
  }

  // Typing. Two arms out of phase at a speed that reads as keys rather than
  // flailing.
  property real typePhase: 0
  NumberAnimation on typePhase {
    running: root.animated && root.smooth && root.activity === "coding" && !root.asleep && !root.isEgg && !root.isGhost
    from: 0; to: 1
    duration: 320
    loops: Animation.Infinite
  }

  // Reading. A slow left-to-right eye sweep with a fast carriage return, which
  // is exactly what reading looks like from across a room.
  property real readSweep: 0
  SequentialAnimation on readSweep {
    running: root.animated && root.smooth && root.activity === "browsing" && !root.asleep && !root.isEgg && !root.isGhost
    loops: Animation.Infinite
    NumberAnimation { from: -0.9; to: 0.9; duration: 2100; easing.type: Easing.InOutQuad }
    NumberAnimation { to: -0.9; duration: 260; easing.type: Easing.OutQuad }
    PauseAnimation { duration: 380 }
  }

  // The walk cycle, driven independently of how far the panel has decided to
  // walk it, so a short stroll and a long one use the same gait.
  property real stepPhase: 0
  NumberAnimation on stepPhase {
    running: root.animated && root.smooth && root.walking && !root.asleep
    from: 0; to: 1
    duration: 560
    loops: Animation.Infinite
  }

  // Extra arm swing on top of the idle sway, per side.
  function armOffset(dir) {
    var a = 0
    if (dancing && danceMove === 3) a -= danceHop * 88 * dir
    if (dancing && danceMove === 1) a -= danceLean * 26 * dir
    if (activity === "coding" && !asleep)
      a += Math.sin(typePhase * Math.PI * 2 + (dir > 0 ? 0 : Math.PI)) * 15 * dir
    if (activity === "agent" && !asleep) a -= 12 * dir
    if (walking) a += Math.sin(stepPhase * Math.PI * 2 + (dir > 0 ? 0 : Math.PI)) * 20 * dir
    return a
  }

  // Feet lift and reach during a walk cycle; still otherwise.
  function footLift(dir) {
    if (!walking) return 0
    var ph = stepPhase * Math.PI * 2 + (dir > 0 ? 0 : Math.PI)
    return Math.max(0, Math.sin(ph)) * 5 * u
  }

  function footReach(dir) {
    if (!walking) return 0
    return Math.cos(stepPhase * Math.PI * 2 + (dir > 0 ? 0 : Math.PI)) * 4 * u
  }

  // Idle joy: a delighted creature hops on its own every few seconds.
  Timer {
    running: root.animated && !root.calm && root.mood === "ecstatic"
    interval: (root.smooth ? 2400 : 13000) + Math.random() * (root.smooth ? 2000 : 9000)
    repeat: true
    onTriggered: root.jump()
  }

  function jump() {
    hopAnim.restart()
  }

  SequentialAnimation {
    id: hopAnim
    NumberAnimation { target: root; property: "hop"; to: 1; duration: 190; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "hop"; to: 0; duration: 420; easing.type: Easing.OutBounce }
  }

  Behavior on bodyScale { NumberAnimation { duration: 900; easing.type: Easing.OutBack } }
  Behavior on tint { ColorAnimation { duration: 700 } }

  // -------------------------------------------------------------- hatching
  //
  // The one authored moment in a creature's life. The panel calls
  // `crackOpen()`, which knocks three times from inside, runs a crack across
  // the shell and then hands back so the hatch can be committed. The stage
  // change then calls `revealHatch()`, which throws the two halves apart and
  // pops the baby out. Panel-only: at bar size a burst of sparkles says it.
  //
  // The shell is cut from the static egg (no breathing), so its paths are
  // built once per size instead of on every frame of the animation.

  property real crack: 0          // 0..1 how far the crack has run
  property real shake: 0          // extra egg tilt while it knocks, degrees
  property real shell: 0          // 0..1 halves flying apart; hidden at rest
  property real pop: 1            // body scale while it climbs out
  property var crackDone: null
  readonly property bool hatching: crackAnim.running || revealAnim.running || calmReveal.running

  function crackOpen(done) {
    if (hatching || !isEgg) return false
    if (calm) { if (done) Qt.callLater(done); return true }
    crackDone = done || null
    crackAnim.restart()
    return true
  }

  function revealHatch() {
    crackAnim.stop()
    crack = 0
    shake = 0
    // Set before the next frame so the baby never flashes in at full size.
    if (calm) { calmReveal.restart(); return }
    shell = 0.001
    pop = 0.15
    blink = 0.06
    revealAnim.restart()
  }

  function cubicAt(a, b, c, d, t) {
    var m = 1 - t
    return Qt.point(m * m * m * a.x + 3 * m * m * t * b.x + 3 * m * t * t * c.x + t * t * t * d.x,
                    m * m * m * a.y + 3 * m * m * t * b.y + 3 * m * t * t * c.y + t * t * t * d.y)
  }

  // The zigzag and the two closed halves either side of it, sampled from the
  // same two cubics that draw the egg below.
  readonly property var shellGeometry: {
    var cx = 50 * u, cy = 50 * u, w = 46 * u, h = 58 * u
    var top = Qt.point(cx, cy - h / 2), bottom = Qt.point(cx, cy + h / 2)
    var left = [], right = [], steps = 24
    for (var i = 0; i <= steps; i++) {
      left.push(cubicAt(top, Qt.point(cx - w * 0.40, cy - h * 0.44), Qt.point(cx - w * 0.62, cy + h * 0.34), bottom, i / steps))
      right.push(cubicAt(bottom, Qt.point(cx + w * 0.62, cy + h * 0.34), Qt.point(cx + w * 0.40, cy - h * 0.44), top, i / steps))
    }
    // Just below the middle, where an egg is widest and breaks most readily.
    var y0 = cy + h * 0.04
    function crossing(list) {
      for (var k = 0; k < list.length - 1; k++) {
        var a = list[k], b = list[k + 1]
        if ((a.y - y0) * (b.y - y0) <= 0 && a.y !== b.y) {
          var t = (y0 - a.y) / (b.y - a.y)
          return { i: k, p: Qt.point(a.x + (b.x - a.x) * t, y0) }
        }
      }
      return { i: 0, p: list[0] }
    }
    var L = crossing(left), R = crossing(right)
    var teeth = 6, amp = h * 0.055, zig = []
    for (var z = 0; z <= teeth; z++)
      zig.push(Qt.point(L.p.x + (R.p.x - L.p.x) * z / teeth,
                        y0 + (z === 0 || z === teeth ? 0 : (z % 2 ? -amp : amp))))
    return {
      crack: zig,
      upper: left.slice(0, L.i + 1).concat(zig).concat(right.slice(R.i + 1)),
      lower: [L.p].concat(left.slice(L.i + 1)).concat(right.slice(1, R.i + 1)).concat(zig.slice().reverse()),
      pivotX: cx,
      pivotY: (cy - h / 2 + y0) / 2,
      x1: cx - w / 2, y1: cy - h / 2, x2: cx + w / 2, y2: cy + h / 2
    }
  }

  // The part of the zigzag that has opened so far.
  readonly property var crackPath: {
    var zig = shellGeometry.crack
    var p = Math.max(0, Math.min(1, crack)) * (zig.length - 1)
    var whole = Math.floor(p)
    var out = zig.slice(0, whole + 1)
    if (whole < zig.length - 1 && p > whole) {
      var a = zig[whole], b = zig[whole + 1], f = p - whole
      out.push(Qt.point(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f))
    }
    return out
  }

  // Which way the lid goes flying. Seeded, so every egg breaks its own way.
  readonly property real flingDir: seed % 2 === 0 ? -1 : 1

  SequentialAnimation {
    id: crackAnim
    // Three knocks from inside, each harder, each running the crack further.
    NumberAnimation { target: root; property: "shake"; to: -5; duration: 70; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "shake"; to: 5; duration: 110; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "shake"; to: 0; duration: 80; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "crack"; to: 0.34; duration: 110; easing.type: Easing.OutQuad }
    PauseAnimation { duration: 150 }
    NumberAnimation { target: root; property: "shake"; to: -8; duration: 70; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "shake"; to: 8; duration: 110; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "shake"; to: 0; duration: 80; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "crack"; to: 0.7; duration: 110; easing.type: Easing.OutQuad }
    PauseAnimation { duration: 130 }
    NumberAnimation { target: root; property: "shake"; to: -12; duration: 60; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "shake"; to: 12; duration: 100; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "shake"; to: -5; duration: 80; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "shake"; to: 0; duration: 70; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "crack"; to: 1; duration: 90; easing.type: Easing.OutQuad }
    // The held breath before it breaks.
    PauseAnimation { duration: 200 }
    // Handed back on the next turn of the event loop: committing the hatch
    // starts the reveal, which must not stop this animation from inside it.
    ScriptAction { script: { var done = root.crackDone; root.crackDone = null; if (done) Qt.callLater(done) } }
  }

  // Calm motion's hatch: the baby simply fades in where the egg was.
  NumberAnimation { id: calmReveal; target: root; property: "opacity"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }

  SequentialAnimation {
    id: revealAnim
    ParallelAnimation {
      NumberAnimation { target: root; property: "shell"; from: 0.001; to: 0.999; duration: 900; easing.type: Easing.OutCubic }
      SequentialAnimation {
        PauseAnimation { duration: 60 }
        NumberAnimation { target: root; property: "pop"; to: 1; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
      }
      SequentialAnimation {
        PauseAnimation { duration: 520 }
        // Its first look at the world: one slow opening, then normal blinks.
        NumberAnimation { target: root; property: "blink"; to: 1; duration: 320; easing.type: Easing.OutCubic }
      }
    }
    ScriptAction { script: { root.shell = 0; root.jump() } }
  }

  // ---------------------------------------------------------- derived pose

  readonly property real breathe: root.animated ? breath : 0
  // ------------------------------------------------------------------- rig
  //
  // The body's geometry is STATIC. Every continuous motion — breathing,
  // bobbing, swaying, hopping, dancing, spinning — is expressed as a transform
  // on the rig below instead.
  //
  // This is not a style choice. Binding `bodyW`/`bodyCy` to a 60fps oscillator
  // makes every Shape in here (mouth, horns, crown, headphone band, ghost)
  // re-tessellate its path every single frame, which measured at ~50% of a
  // core for two bar widgets. Driving a transform node instead costs nothing
  // and looks identical: with static geometry the same creature idles at ~1%.

  // Shape, ears, marking, eyes and cheeks from the seed. Static features, so
  // they cost nothing per frame, in the bar or anywhere else.
  readonly property var look: Sim.traits(seed, ownSeed)

  readonly property real bodyW: (look.shape === "bean" ? 54 : look.shape === "chunky" ? 66 : 60) * u * bodyScale
  readonly property real bodyH: (look.shape === "bean" ? 61 : look.shape === "chunky" ? 52 : 56) * u * bodyScale
  readonly property real bodyCx: 50 * u
  readonly property real bodyCy: 52 * u

  // Every mode contributes to the same four numbers; nothing downstream has to
  // know which mode is active.
  readonly property real danceRise: dancing && (danceMove === 0 || danceMove === 3) ? danceHop * 9 * u : 0
  readonly property real danceSlide: dancing && danceMove === 1 ? danceLean * 6 * u : 0
  readonly property real walkBounce: walking ? Math.abs(Math.sin(stepPhase * Math.PI * 2)) * 2.5 * u : 0

  readonly property real rigX: (isGhost ? sway * 4 : sway * 1.2) * u + danceSlide
  readonly property real rigY: (isGhost ? bob * 5 : bob * 1.6) * u - hop * 16 * u - danceRise - walkBounce
  readonly property real rigScaleX: (1 + breathe * 0.020 - hop * 0.06 + danceHop * 0.05) * pop
  readonly property real rigScaleY: (1 - breathe * 0.022 + hop * 0.10 - danceHop * 0.05) * pop
  readonly property real rigAngle: spinAngle
                                 + sway * 2.5
                                 + (dancing && danceMove === 1 ? danceLean * 7 : 0)
                                 + (walking ? walkDir * 3 : 0)

  // -------------------------------------------------------------- drawing

  // Ground shadow. Tightens as the creature lifts, which is what sells the hop.
  Rectangle {
    id: contactShadow
    visible: root.detail && !root.isGhost
    width: root.bodyW * 0.62
    height: 6 * root.u
    radius: height / 2
    x: root.bodyCx - width / 2
    // Under the feet at every size: a baby's feet sit higher than an adult's.
    y: (root.isEgg ? 76 : 85 - (1 - root.bodyScale) * 34) * root.u
    color: Qt.rgba(0, 0, 0, 0.17)
    // Outside the rig: a shadow does not hop. It tightens instead, and does so
    // through a transform so the hop costs no layout.
    opacity: (1 - root.hop * 0.5) * Math.min(1, root.pop)
    transform: Scale {
      origin.x: contactShadow.width / 2
      origin.y: contactShadow.height / 2
      xScale: 1 - root.hop * 0.32
    }
  }

  // ---- broken shell: cup --------------------------------------------------
  // Behind the rig: the baby grows up out of the bottom half and stands in
  // front of it, instead of being seen through a fading shell.

  Item {
    visible: root.detail && root.shell > 0 && root.shell < 1
    anchors.fill: parent

    // It stays put until the baby is out, then sinks away.
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      opacity: 1 - Math.max(0, (root.shell - 0.6) / 0.4)
      transform: Translate { y: Math.max(0, root.shell - 0.4) * 10 * root.u }

      ShapePath {
        strokeWidth: 0
        fillGradient: LinearGradient {
          x1: root.shellGeometry.x1; y1: root.shellGeometry.y1
          x2: root.shellGeometry.x2; y2: root.shellGeometry.y2
          GradientStop { position: 0.0; color: Qt.lighter(root.effectiveTint, 1.55) }
          GradientStop { position: 1.0; color: Qt.lighter(root.effectiveTint, 1.15) }
        }
        PathPolyline { path: root.shellGeometry.lower }
      }
      ShapePath {
        strokeColor: Qt.darker(root.effectiveTint, 1.25)
        strokeWidth: Math.max(1, 2.2 * root.u)
        fillColor: "transparent"
        joinStyle: ShapePath.RoundJoin
        PathPolyline { path: root.shellGeometry.crack }
      }
    }
  }

  // ---- face geometry ----------------------------------------------------
  // Read by Gear as well as by the face itself, so these stay on the root
  // rather than inside the rig.

  readonly property real gazeX: {
    if (activity === "browsing" && !asleep) return readSweep
    if (walking) return walkDir * 0.65
    if (dancing) return danceLean * 0.5
    return lookX
  }

  readonly property real gazeY: {
    if (activity === "agent" && !asleep) return -0.9
    if (activity === "coding" && !asleep) return 0.55
    if (activity === "video" && !asleep) return -0.2
    return lookY
  }

  readonly property real eyeY: root.bodyCy - root.bodyH * 0.10

  readonly property real eyeDx: root.bodyW * 0.215

  readonly property real eyeR: (root.detail ? 9.5 : 11) * root.u * root.bodyScale * (look.eyes === "big" ? 1.14 : 1)
  // Narrow eyes are the same eye, a little squashed, like the mood squints.
  readonly property real eyeShape: look.eyes === "narrow" ? 0.8 : 1

  readonly property real mouthCurve: {
    if (asleep) return 0.30
    if (mood === "sick" || mood === "weak") return -0.55
    if (mood === "hungry") return -0.45
    var base = (happiness - 48) / 52
    // Dancing and cheering override a merely-content mouth. Nobody dances
    // with a straight face.
    if (dancing) return Math.max(base, 0.88)
    if (activity === "gaming") return Math.max(base, 0.6)
    return base
  }

  // ---- rig ---------------------------------------------------------------
  // Everything the creature *is* lives in here and moves as one.

  Item {
    id: rig
    anchors.fill: parent

    transform: [
      Scale {
        origin.x: root.bodyCx
        origin.y: root.bodyCy + root.bodyH * 0.5
        xScale: root.rigScaleX
        yScale: root.rigScaleY
      },
      Rotation {
        origin.x: root.bodyCx
        origin.y: root.bodyCy + root.bodyH * 0.35
        angle: root.rigAngle
      },
      Translate { x: root.rigX; y: root.rigY }
    ]

  // ---- egg ---------------------------------------------------------------
  // A real egg is an ovoid, not a capsule: narrow at the top, heavy at the
  // bottom. Two mirrored cubics give exactly that in four control points.
  Item {
    id: eggItem
    visible: root.isEgg
    anchors.fill: parent

    readonly property real w: 46 * root.u * (1 + root.breathe * 0.020)
    readonly property real h: 58 * root.u * (1 - root.breathe * 0.020)
    readonly property real cx: 50 * root.u
    readonly property real cy: 50 * root.u

    rotation: root.sway * 4 + root.shake
    transformOrigin: Item.Bottom

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillGradient: LinearGradient {
          x1: eggItem.cx - eggItem.w / 2; y1: eggItem.cy - eggItem.h / 2
          x2: eggItem.cx + eggItem.w / 2; y2: eggItem.cy + eggItem.h / 2
          GradientStop { position: 0.0; color: Qt.lighter(root.effectiveTint, 1.55) }
          GradientStop { position: 1.0; color: Qt.lighter(root.effectiveTint, 1.15) }
        }
        strokeWidth: 0
        startX: eggItem.cx
        startY: eggItem.cy - eggItem.h / 2
        PathCubic {
          x: eggItem.cx; y: eggItem.cy + eggItem.h / 2
          control1X: eggItem.cx - eggItem.w * 0.40; control1Y: eggItem.cy - eggItem.h * 0.44
          control2X: eggItem.cx - eggItem.w * 0.62; control2Y: eggItem.cy + eggItem.h * 0.34
        }
        PathCubic {
          x: eggItem.cx; y: eggItem.cy - eggItem.h / 2
          control1X: eggItem.cx + eggItem.w * 0.62; control1Y: eggItem.cy + eggItem.h * 0.34
          control2X: eggItem.cx + eggItem.w * 0.40; control2Y: eggItem.cy - eggItem.h * 0.44
        }
      }
    }

    // Speckles, placed from the seed so each generation's egg is its own.
    Repeater {
      model: 6
      Rectangle {
        id: speck
        required property int index
        readonly property real rnd1: root.seededRand(index * 2)
        readonly property real rnd2: root.seededRand(index * 2 + 1)
        width: (3 + (index % 3)) * root.u
        height: width
        radius: width / 2
        x: eggItem.cx - eggItem.w * 0.30 + rnd1 * eggItem.w * 0.60 - width / 2
        y: eggItem.cy - eggItem.h * 0.24 + rnd2 * eggItem.h * 0.58 - height / 2
        color: Qt.darker(root.effectiveTint, 1.30)
        opacity: 0.45
      }
    }

    // Highlight, same top-left convention as the body.
    Rectangle {
      width: eggItem.w * 0.26
      height: eggItem.h * 0.17
      x: eggItem.cx - eggItem.w * 0.26
      y: eggItem.cy - eggItem.h * 0.26
      radius: width / 2
      color: Qt.rgba(1, 1, 1, 0.45)
      rotation: -24
    }

    // The crack, drawn as far as it has run.
    Shape {
      visible: root.crack > 0
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.darker(root.effectiveTint, 1.7)
        strokeWidth: Math.max(1.2, 1.8 * root.u)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathPolyline { path: root.crackPath }
      }
    }
  }

  // The egg rocks harder the closer it gets to hatching. It is the only cue
  // that something is about to happen, so it has to be visible from the bar.
  SequentialAnimation on rotation {
    running: root.animated && root.isEgg && !root.hatching
    // Stopping mid-rock would otherwise leave the hatchling standing crooked.
    onRunningChanged: if (!running) root.rotation = 0
    loops: Animation.Infinite
    NumberAnimation { to:  2.5; duration: 260; easing.type: Easing.InOutSine }
    NumberAnimation { to: -2.5; duration: 260; easing.type: Easing.InOutSine }
    NumberAnimation { to:  0;   duration: 200; easing.type: Easing.InOutSine }
    PauseAnimation { duration: 2200 }
  }

  // ---- feet --------------------------------------------------------------
  Repeater {
    model: root.detail && !root.isGhost && !root.isEgg ? 2 : 0
    Rectangle {
      required property int index
      readonly property real dir: index === 0 ? -1 : 1
      width: 17 * root.u * root.bodyScale
      height: 9 * root.u * root.bodyScale
      radius: height / 2
      x: root.bodyCx + dir * root.bodyW * 0.30 - width / 2 + root.footReach(dir)
      y: root.bodyCy + root.bodyH * 0.47 - height * 0.18 - root.footLift(dir)
      color: root.bodyDark
      rotation: root.sway * 4 * dir
    }
  }

  // ---- arms --------------------------------------------------------------
  Repeater {
    model: root.detail && !root.isGhost && !root.isEgg ? 2 : 0
    Rectangle {
      required property int index
      readonly property real dir: index === 0 ? -1 : 1
      width: 8 * root.u * root.bodyScale
      height: 19 * root.u * root.bodyScale
      radius: width / 2
      x: root.bodyCx + dir * root.bodyW * 0.54 - width / 2
      y: root.bodyCy - height * 0.05
      color: root.bodyDark
      transformOrigin: Item.Top
      // Arms swing with the sway, and fly up when the creature is delighted.
      rotation: dir * (14 + root.sway * 16 * dir) - root.hop * dir * 100 + root.armOffset(dir)
      Behavior on rotation { NumberAnimation { duration: 160 } }
    }
  }

  // ---- ghost -------------------------------------------------------------
  // Drawn as one silhouette rather than the body plus a tail: a domed top and
  // three scalloped hems, so the bottom edge actually reads as a ghost instead
  // of a rectangle with decoration underneath.
  Shape {
    id: ghostShape
    visible: root.isGhost
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    readonly property real w: root.bodyW
    readonly property real h: root.bodyH * 1.14
    readonly property real cx: root.bodyCx
    readonly property real cy: root.bodyCy
    readonly property real hem: cy + h * 0.34
    // Static: the float comes from the rig, so the path itself never moves.
    readonly property real wob: 0

    ShapePath {
      fillColor: Qt.rgba(root.effectiveTint.r, root.effectiveTint.g, root.effectiveTint.b, 0.72)
      strokeWidth: 0
      startX: ghostShape.cx - ghostShape.w / 2
      startY: ghostShape.cy

      PathCubic {
        x: ghostShape.cx + ghostShape.w / 2; y: ghostShape.cy
        control1X: ghostShape.cx - ghostShape.w * 0.52; control1Y: ghostShape.cy - ghostShape.h * 0.86
        control2X: ghostShape.cx + ghostShape.w * 0.52; control2Y: ghostShape.cy - ghostShape.h * 0.86
      }
      PathLine { x: ghostShape.cx + ghostShape.w / 2; y: ghostShape.hem }
      PathQuad {
        x: ghostShape.cx + ghostShape.w * 0.166; y: ghostShape.hem
        controlX: ghostShape.cx + ghostShape.w * 0.333
        controlY: ghostShape.hem + ghostShape.h * 0.22 + ghostShape.wob
      }
      PathQuad {
        x: ghostShape.cx - ghostShape.w * 0.166; y: ghostShape.hem
        controlX: ghostShape.cx
        controlY: ghostShape.hem - ghostShape.h * 0.14 - ghostShape.wob
      }
      PathQuad {
        x: ghostShape.cx - ghostShape.w / 2; y: ghostShape.hem
        controlX: ghostShape.cx - ghostShape.w * 0.333
        controlY: ghostShape.hem + ghostShape.h * 0.22 + ghostShape.wob
      }
      PathLine { x: ghostShape.cx - ghostShape.w / 2; y: ghostShape.cy }
    }
  }

  // ---- ears --------------------------------------------------------------
  // Behind the body, and kept at bar size: ears change the silhouette, which
  // is what tells two creatures apart at 20px.

  Item {
    id: ears
    visible: !root.isEgg && !root.isGhost && root.look.ears !== "none"
    anchors.fill: parent
    readonly property real headTop: root.bodyCy - root.bodyH / 2
    readonly property color inner: Qt.lighter(root.effectiveTint, 1.3)

    Repeater {
      model: root.look.ears === "round" ? 2 : 0
      Rectangle {
        required property int index
        readonly property real dir: index === 0 ? -1 : 1
        width: root.bodyW * 0.30
        height: width
        radius: width / 2
        x: root.bodyCx + dir * root.bodyW * 0.33 - width / 2
        y: ears.headTop + root.bodyH * 0.12 - height / 2
        color: root.bodyDark
        Rectangle {
          visible: root.detail
          anchors.centerIn: parent
          width: parent.width * 0.52
          height: width
          radius: width / 2
          color: ears.inner
        }
      }
    }

    Repeater {
      model: root.look.ears === "pointy" ? 2 : 0
      Shape {
        id: pointyEar
        required property int index
        readonly property real dir: index === 0 ? -1 : 1
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          fillColor: root.bodyDark
          strokeWidth: 0
          startX: root.bodyCx + pointyEar.dir * root.bodyW * 0.16
          startY: ears.headTop + root.bodyH * 0.16
          PathLine { x: root.bodyCx + pointyEar.dir * root.bodyW * 0.42; y: ears.headTop - root.bodyH * 0.16 }
          PathLine { x: root.bodyCx + pointyEar.dir * root.bodyW * 0.46; y: ears.headTop + root.bodyH * 0.28 }
        }
        ShapePath {
          fillColor: root.detail ? ears.inner : "transparent"
          strokeWidth: 0
          startX: root.bodyCx + pointyEar.dir * root.bodyW * 0.25
          startY: ears.headTop + root.bodyH * 0.12
          PathLine { x: root.bodyCx + pointyEar.dir * root.bodyW * 0.40; y: ears.headTop - root.bodyH * 0.06 }
          PathLine { x: root.bodyCx + pointyEar.dir * root.bodyW * 0.42; y: ears.headTop + root.bodyH * 0.18 }
        }
      }
    }

    Repeater {
      model: root.look.ears === "floppy" ? 2 : 0
      Rectangle {
        required property int index
        readonly property real dir: index === 0 ? -1 : 1
        width: root.bodyW * 0.17
        height: root.bodyH * 0.40
        radius: width / 2
        x: root.bodyCx + dir * root.bodyW * 0.40 - width / 2
        y: ears.headTop + root.bodyH * 0.02
        color: root.bodyDark
        transformOrigin: Item.Top
        rotation: dir * -38 + root.sway * 3 * dir
      }
    }
  }

  // ---- body --------------------------------------------------------------
  Rectangle {
    id: body
    visible: !root.isEgg && !root.isGhost
    width: root.bodyW
    height: root.bodyH
    x: root.bodyCx - width / 2
    y: root.bodyCy - height / 2
    radius: Math.min(width, height) * 0.47

    gradient: Gradient {
      GradientStop { position: 0.0; color: root.bodyLight }
      GradientStop { position: 1.0; color: root.effectiveTint }
    }

    // Belly patch — a lighter oval that reads as volume without needing a
    // single shadow pass.
    Rectangle {
      visible: root.detail && !root.isGhost
      width: parent.width * 0.52
      height: parent.height * 0.42
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.50
      radius: width / 2
      color: Qt.lighter(root.effectiveTint, 1.40)
      opacity: 0.55
    }

    // Marking: spots, forehead stripes, a patch around one eye, or freckles.
    // Drawn in the body's own darker shade, so they belong to its colour.
    Item {
      id: marking
      visible: root.detail && !root.isGhost && root.look.marking !== "none"
      anchors.fill: parent
      readonly property real side: root.look.side
      readonly property color ink: Qt.darker(root.effectiveTint, 1.45)

      Repeater {
        model: root.look.marking === "spots" ? [[0.20, 0.20, 0.13], [0.70, 0.09, 0.09], [0.82, 0.30, 0.07]] : []
        Rectangle {
          required property var modelData
          width: body.width * modelData[2]
          height: width
          radius: width / 2
          x: (marking.side > 0 ? modelData[0] : 1 - modelData[0]) * body.width - width / 2
          y: modelData[1] * body.height
          color: marking.ink
          opacity: 0.42
        }
      }

      Repeater {
        model: root.look.marking === "stripes" ? [-1, 0, 1] : []
        Rectangle {
          required property var modelData
          width: body.width * 0.055
          height: body.height * (modelData === 0 ? 0.17 : 0.13)
          radius: width / 2
          x: body.width * (0.5 + modelData * 0.10) - width / 2
          y: body.height * 0.035
          rotation: modelData * 14
          color: marking.ink
          opacity: 0.5
        }
      }

      Rectangle {
        visible: root.look.marking === "patch"
        width: root.eyeR * 3.0
        height: root.eyeR * 2.7
        radius: height / 2
        x: body.width / 2 + marking.side * root.eyeDx - width / 2
        y: root.eyeY - (root.bodyCy - root.bodyH / 2) - height / 2
        color: marking.ink
        opacity: 0.38
      }

      Repeater {
        model: root.look.marking === "freckles" ? 6 : 0
        Rectangle {
          required property int index
          readonly property real dir: index < 3 ? -1 : 1
          readonly property int k: index % 3
          width: Math.max(1, body.width * 0.028)
          height: width
          radius: width / 2
          x: body.width / 2 + dir * (root.eyeDx + (k - 1) * body.width * 0.05) - width / 2
          y: root.eyeY - (root.bodyCy - root.bodyH / 2) + root.eyeR * (1.35 + (k === 1 ? 0.25 : 0))
          color: marking.ink
          opacity: 0.6
        }
      }
    }

    // Specular highlight, top-left, always. Consistency here is what stops it
    // looking like a flat sticker.
    Rectangle {
      visible: !root.isGhost
      width: parent.width * 0.24
      height: parent.height * 0.17
      x: parent.width * 0.17
      y: parent.height * 0.13
      radius: width / 2
      color: Qt.rgba(1, 1, 1, 0.42)
      rotation: -22
    }
  }

  // ---- stage accessory ---------------------------------------------------
  // Growing up has to be legible at a glance: a tuft, then an antenna, then
  // horns, then a crown. The silhouette changes, not just the size.

  // baby: hair tuft
  Rectangle {
    visible: root.detail && root.stageKey === "baby" && !root.costumeHat
    width: 5.5 * root.u
    height: 12 * root.u
    radius: width / 2
    x: root.bodyCx - width / 2
    y: root.bodyCy - root.bodyH / 2 - height * 0.70
    color: root.bodyDark
    transformOrigin: Item.Bottom
    rotation: 12 + root.sway * 10
  }

  // kid: antenna with a bobbing bead
  Item {
    visible: root.detail && root.stageKey === "kid" && !root.costumeHat
    anchors.fill: parent
    Rectangle {
      width: 2.4 * root.u
      height: 16 * root.u
      x: root.bodyCx - width / 2
      y: root.bodyCy - root.bodyH / 2 - height
      color: root.bodyDark
      transformOrigin: Item.Bottom
      rotation: root.sway * 12
    }
    Rectangle {
      width: 8 * root.u
      height: width
      radius: width / 2
      x: root.bodyCx - width / 2 + root.sway * 3.2 * root.u
      y: root.bodyCy - root.bodyH / 2 - 16 * root.u - width * 0.55
      color: Qt.lighter(root.glowColor, 1.5)
      // The bead pulses like it is thinking about something.
      scale: 1 + root.breath * 0.16
    }
  }

  // teen: horns
  Repeater {
    model: root.detail && root.stageKey === "teen" && !root.costumeHat ? 2 : 0
    Shape {
      id: horn
      required property int index
      readonly property real dir: index === 0 ? -1 : 1
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: root.bodyDark
        strokeWidth: 0
        startX: root.bodyCx + horn.dir * root.bodyW * 0.26 - 5 * root.u
        startY: root.bodyCy - root.bodyH * 0.44
        PathLine { x: root.bodyCx + horn.dir * root.bodyW * 0.26 + 5 * root.u; y: root.bodyCy - root.bodyH * 0.44 }
        PathQuad {
          x: root.bodyCx + horn.dir * root.bodyW * 0.34
          y: root.bodyCy - root.bodyH * 0.44 - 15 * root.u
          controlX: root.bodyCx + horn.dir * root.bodyW * 0.36
          controlY: root.bodyCy - root.bodyH * 0.44 - 6 * root.u
        }
      }
    }
  }

  // adult + elder: crown
  Repeater {
    model: root.detail && (root.stageKey === "adult" || root.stageKey === "elder") && !root.costumeHat ? 3 : 0
    Shape {
      id: spike
      required property int index
      readonly property real dir: index - 1
      readonly property real tall: index === 1 ? 15 : 10
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: root.stageKey === "elder" ? Qt.lighter(root.glowColor, 1.7) : root.bodyDark
        strokeWidth: 0
        startX: root.bodyCx + spike.dir * 11 * root.u - 5 * root.u
        startY: root.bodyCy - root.bodyH * 0.46
        PathLine { x: root.bodyCx + spike.dir * 11 * root.u + 5 * root.u; y: root.bodyCy - root.bodyH * 0.46 }
        PathLine { x: root.bodyCx + spike.dir * 11 * root.u; y: root.bodyCy - root.bodyH * 0.46 - spike.tall * root.u }
      }
    }
  }

  // elder: a halo, because two weeks of survival deserves one
  Rectangle {
    visible: root.detail && root.stageKey === "elder" && !root.costumeHat
    width: 30 * root.u
    height: 7 * root.u
    radius: height / 2
    x: root.bodyCx - width / 2
    y: root.bodyCy - root.bodyH / 2 - 21 * root.u + root.bob * 1.6 * root.u
    color: "transparent"
    border.width: Math.max(1.2, 2.2 * root.u)
    border.color: "#ffd97a"
    opacity: 0.80 + root.breath * 0.18
  }

  // ---- face --------------------------------------------------------------

  // Where the eyes are actually pointing. The idle wander is only the fallback
  // — reading, watching an agent work and walking all take precedence, because
  // a creature that looks at the thing you are doing is the whole trick.



  // Open eyes: white + pupil + catchlight.
  Repeater {
    model: (!root.isEgg && !root.asleep && root.mood !== "sick" && !root.isGhost) ? 2 : 0
    Item {
      required property int index
      readonly property real dir: index === 0 ? -1 : 1
      x: root.bodyCx + dir * root.eyeDx - root.eyeR
      y: root.eyeY - root.eyeR
      width: root.eyeR * 2
      height: root.eyeR * 2

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "#ffffff"
        scale: 1
        transform: Scale {
          origin.x: root.eyeR; origin.y: root.eyeR
          // The squint on a low-energy or sad face is a vertical squash of the
          // same eye, so there is only ever one eye to keep in sync.
          yScale: root.blink * root.eyeShape * (root.mood === "tired" || root.mood === "weak" ? 0.45
                              : (root.mood === "sad" ? 0.72 : 1))
        }
      }

      Rectangle {
        id: pupil
        width: root.eyeR * ((root.mood === "ecstatic" || root.activity === "agent" || root.activity === "gaming") ? 1.04 : 0.92)
        height: width
        radius: width / 2
        x: root.eyeR - width / 2 + root.gazeX * root.eyeR * 0.36
        y: root.eyeR - height / 2 + root.gazeY * root.eyeR * 0.30
        color: root.inkColor
        transform: Scale {
          origin.x: pupil.width / 2; origin.y: pupil.height / 2
          yScale: root.blink * root.eyeShape * (root.mood === "tired" || root.mood === "weak" ? 0.45 : 1)
        }

        Rectangle {
          width: parent.width * 0.36
          height: width
          radius: width / 2
          x: parent.width * 0.14
          y: parent.height * 0.14
          color: Qt.rgba(1, 1, 1, 0.92)
        }
        // Sparkly eyes carry a second, smaller catchlight.
        Rectangle {
          visible: root.look.eyes === "sparkle" && root.detail
          width: parent.width * 0.18
          height: width
          radius: width / 2
          x: parent.width * 0.62
          y: parent.height * 0.60
          color: Qt.rgba(1, 1, 1, 0.85)
        }
      }
    }
  }

  // Sleeping and sick eyes are drawn as arcs, not squashed circles — a closed
  // eye that is really a flattened ball always looks like a bug.
  Repeater {
    model: (!root.isEgg && (root.asleep || root.mood === "sick") && !root.isGhost) ? 2 : 0
    Shape {
      id: lid
      required property int index
      readonly property real dir: index === 0 ? -1 : 1
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: root.inkColor
        strokeWidth: Math.max(1.4, 2.6 * root.u * root.bodyScale)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: root.bodyCx + lid.dir * root.eyeDx - root.eyeR * 0.85
        startY: root.eyeY
        PathQuad {
          x: root.bodyCx + lid.dir * root.eyeDx + root.eyeR * 0.85
          y: root.eyeY
          // Sleep curves down (lids closed), sickness curves up (>_< squint).
          controlX: root.bodyCx + lid.dir * root.eyeDx
          controlY: root.eyeY + (root.asleep ? 1 : -1) * root.eyeR * 0.95
        }
      }
    }
  }

  // Ghost eyes: two hollow crosses.
  Repeater {
    model: root.isGhost ? 2 : 0
    Item {
      required property int index
      readonly property real dir: index === 0 ? -1 : 1
      x: root.bodyCx + dir * root.eyeDx
      y: root.eyeY
      Repeater {
        model: 2
        Rectangle {
          required property int index
          width: 13 * root.u
          height: Math.max(1.5, 2.4 * root.u)
          radius: height / 2
          x: -width / 2
          y: -height / 2
          color: root.inkColor
          opacity: 0.8
          rotation: index === 0 ? 45 : -45
        }
      }
    }
  }

  // ---- mouth -------------------------------------------------------------
  // One quadratic curve whose control point is driven by happiness: a smile at
  // 100, flat at 50, a frown at 0. Every expression in the whole widget comes
  // out of this single number.

  Shape {
    visible: !root.isEgg && !root.isGhost
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: root.inkColor
      strokeWidth: Math.max(1.4, 2.8 * root.u * root.bodyScale)
      fillColor: root.mouthCurve > 0.72 ? root.inkColor : "transparent"
      capStyle: ShapePath.RoundCap
      startX: root.bodyCx - root.bodyW * 0.14
      startY: root.eyeY + root.eyeR * 1.75
      PathQuad {
        x: root.bodyCx + root.bodyW * 0.14
        y: root.eyeY + root.eyeR * 1.75
        controlX: root.bodyCx
        controlY: root.eyeY + root.eyeR * 1.75 + root.mouthCurve * 13 * root.u * root.bodyScale
      }
    }
  }

  // Tongue, but only for a wide open grin — the small detail people notice
  // second and can't unsee.
  Rectangle {
    visible: root.detail && root.mouthCurve > 0.80 && !root.isEgg && !root.isGhost
    width: 7 * root.u * root.bodyScale
    height: 5 * root.u * root.bodyScale
    radius: width / 2
    x: root.bodyCx - width / 2
    y: root.eyeY + root.eyeR * 1.75 + root.mouthCurve * 8 * root.u * root.bodyScale
    color: "#e0748f"
  }

  // ---- cheeks ------------------------------------------------------------
  Repeater {
    model: root.detail && !root.isEgg && !root.isGhost ? 2 : 0
    Rectangle {
      required property int index
      readonly property real dir: index === 0 ? -1 : 1
      width: 11 * root.u * root.bodyScale
      height: 7 * root.u * root.bodyScale
      radius: width / 2
      x: root.bodyCx + dir * root.bodyW * 0.36 - width / 2
      y: root.eyeY + root.eyeR * 0.85
      color: root.mood === "sick" ? "#8fbf6a" : root.look.cheek
      opacity: root.dancing ? 0.7
             : (root.mood === "ecstatic" ? 0.75
             : (root.mood === "happy" || root.mood === "sick" ? 0.5 : 0.22))
      Behavior on opacity { NumberAnimation { duration: 400 } }
    }
  }

  // ---- status marks ------------------------------------------------------

  // Sweat drop for illness and exhaustion.
  Rectangle {
    visible: root.detail && (root.mood === "sick" || root.mood === "tired") && !root.isEgg
    width: 6 * root.u
    height: 8 * root.u
    radius: width / 2
    x: root.bodyCx + root.bodyW * 0.40
    y: root.eyeY - root.eyeR * 0.35 + root.bob * 2 * root.u
    color: "#8fc7e8"
    opacity: 0.85
  }

  // Sleep bubbles. Three, offset in phase, endlessly rising.
  Repeater {
    model: root.detail && root.asleep && !root.isEgg ? 3 : 0
    Text {
      id: zzz
      required property int index
      // Animating a dedicated offset instead of `y` keeps the anchor binding
      // alive, so the bubbles follow the creature as it breathes and floats.
      property real rise: 0

      text: "z"
      color: root.inkColor
      opacity: 0
      font.pixelSize: (9 + index * 4) * root.u
      font.bold: true
      x: root.bodyCx + root.bodyW * 0.40 + index * 5 * root.u
      y: root.bodyCy - root.bodyH * 0.55 - index * 9 * root.u - rise

      SequentialAnimation {
        running: true
        loops: Animation.Infinite
        PauseAnimation { duration: zzz.index * 620 }
        ParallelAnimation {
          NumberAnimation { target: zzz; property: "rise"; from: 0; to: 14 * root.u; duration: 1600; easing.type: Easing.OutSine }
          SequentialAnimation {
            NumberAnimation { target: zzz; property: "opacity"; to: 0.9; duration: 700 }
            NumberAnimation { target: zzz; property: "opacity"; to: 0.0; duration: 900 }
          }
        }
        PauseAnimation { duration: (2 - zzz.index) * 620 }
      }
    }
  }

  // ---- gear --------------------------------------------------------------
  // Last, so props sit in front of the body and the face.

  Gear {
    anchors.fill: parent
    u: root.u
    bodyCx: root.bodyCx
    bodyCy: root.bodyCy
    bodyW: root.bodyW
    bodyH: root.bodyH
    bodyScale: root.bodyScale
    eyeY: root.eyeY
    eyeDx: root.eyeDx
    eyeR: root.eyeR
    detail: root.detail
    animated: root.animated
    beat: root.beat
    beatMs: root.beatMs
    tint: root.effectiveTint
    ink: root.inkColor
    accent: root.glowColor

    activity: root.gearActivity
    hat: root.costumeHat ? root.costume : ""
    music: root.music && !root.isEgg && !root.isGhost
  }
  }

  // ---- broken shell: lid -------------------------------------------------
  // In front of the rig and outside it, so the lid keeps its size while the
  // baby pops, and flies past the face rather than behind it.

  Item {
    visible: root.detail && root.shell > 0 && root.shell < 1
    anchors.fill: parent

    // The top is flung up and off to one side, tumbling as it goes.
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      opacity: 1 - Math.max(0, (root.shell - 0.4) / 0.6)
      transform: [
        Rotation {
          origin.x: root.shellGeometry.pivotX
          origin.y: root.shellGeometry.pivotY
          angle: root.flingDir * root.shell * 150
        },
        Translate {
          x: root.flingDir * root.shell * 30 * root.u
          y: -Math.sin(Math.min(1, root.shell * 1.4) * Math.PI) * 26 * root.u + root.shell * 12 * root.u
        }
      ]

      ShapePath {
        strokeWidth: 0
        fillGradient: LinearGradient {
          x1: root.shellGeometry.x1; y1: root.shellGeometry.y1
          x2: root.shellGeometry.x2; y2: root.shellGeometry.y2
          GradientStop { position: 0.0; color: Qt.lighter(root.effectiveTint, 1.55) }
          GradientStop { position: 1.0; color: Qt.lighter(root.effectiveTint, 1.15) }
        }
        PathPolyline { path: root.shellGeometry.upper }
      }
      ShapePath {
        strokeColor: Qt.darker(root.effectiveTint, 1.25)
        strokeWidth: Math.max(1, 2.2 * root.u)
        fillColor: "transparent"
        joinStyle: ShapePath.RoundJoin
        PathPolyline { path: root.shellGeometry.crack }
      }
    }
  }
}
