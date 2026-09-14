pragma ComponentBehavior: Bound

import QtQuick

// ---------------------------------------------------------------------------
// One-shot particle bursts: hearts when you pet it, crumbs when you feed it,
// stars when you play. A fixed recycled pool rather than a particle system —
// bursts here are short, sparse and event-driven, and a pool of a dozen labels
// costs nothing while sitting idle in a bar that is always on screen.
// ---------------------------------------------------------------------------
Item {
  id: root

  property real originX: width / 2
  property real originY: height / 2
  property real spread: 46
  property real glyphSize: 15
  property color inkColor: "#ffffff"

  readonly property int poolSize: 14
  property int cursor: 0

  // Each burst is a glyph set plus a flight profile. "rise" drifts straight
  // up and lingers (zzz, notes); "pop" fans out fast (hearts, stars); "fall"
  // scatters downward under gravity (crumbs, poop).
  readonly property var kinds: ({
    heart:   { glyphs: ["♥", "♡", "❤"],       flight: "pop",  count: 6, color: "#ff7d9c" },
    food:    { glyphs: ["🍖", "🍎", "🍪"],     flight: "fall", count: 5, color: "" },
    star:    { glyphs: ["★", "✦", "✧"],       flight: "pop",  count: 7, color: "#ffd35c" },
    sparkle: { glyphs: ["✧", "✦", "·"],       flight: "pop",  count: 8, color: "#8fe6ff" },
    zzz:     { glyphs: ["z", "Z"],            flight: "rise", count: 4, color: "" },
    sick:    { glyphs: ["✖", "~"],            flight: "fall", count: 5, color: "#9fcf6a" },
    note:    { glyphs: ["♪", "♫"],            flight: "rise", count: 5, color: "#b8a6ff" }
  })

  function burst(kind) {
    var spec = kinds[kind]
    if (!spec) return
    for (var i = 0; i < spec.count; i++) spawn(spec, i)
  }

  function spawn(spec, i) {
    var item = pool.itemAt(root.cursor % root.poolSize)
    root.cursor++
    if (!item) return

    var angle = spec.flight === "rise"
      ? (-Math.PI / 2) + (Math.random() - 0.5) * 0.55
      : (spec.flight === "fall"
        ? (Math.random() - 0.5) * Math.PI * 0.9
        : (Math.random() * Math.PI * 2))
    var reach = root.spread * (0.55 + Math.random() * 0.75)

    item.glyph = spec.glyphs[Math.floor(Math.random() * spec.glyphs.length)]
    item.useColor = spec.color !== ""
    item.tintColor = spec.color !== "" ? spec.color : root.inkColor
    item.startX = root.originX + (Math.random() - 0.5) * root.spread * 0.4
    item.startY = root.originY + (Math.random() - 0.5) * root.spread * 0.3
    item.endX = item.startX + Math.cos(angle) * reach
    item.endY = spec.flight === "fall"
      ? item.startY + Math.abs(Math.sin(angle)) * reach * 0.4 + reach * 0.75
      : item.startY + Math.sin(angle) * reach - (spec.flight === "rise" ? reach * 0.7 : 0)
    item.spin = (Math.random() - 0.5) * 90
    item.lifetime = 620 + Math.random() * 520
    item.play()
  }

  Repeater {
    id: pool
    model: root.poolSize

    Text {
      id: particle
      required property int index

      property string glyph: ""
      property bool useColor: false
      property color tintColor: root.inkColor
      property real startX: 0
      property real startY: 0
      property real endX: 0
      property real endY: 0
      property real spin: 0
      property int lifetime: 700
      property real progress: 0

      function play() {
        progress = 0
        flight.restart()
      }

      text: glyph
      color: tintColor
      visible: flight.running
      font.pixelSize: root.glyphSize
      font.bold: true
      renderType: Text.NativeRendering

      // Position is a plain interpolation of one animated progress value, so a
      // particle only ever runs one animation no matter how many properties
      // its flight touches.
      x: startX + (endX - startX) * progress - width / 2
      y: startY + (endY - startY) * progress - height / 2
      opacity: progress < 0.15 ? progress / 0.15 : (1 - Math.max(0, (progress - 0.45)) / 0.55)
      scale: 0.6 + progress * 0.7
      rotation: spin * progress

      NumberAnimation {
        id: flight
        target: particle
        property: "progress"
        from: 0; to: 1
        duration: particle.lifetime
        easing.type: Easing.OutCubic
      }
    }
  }
}
