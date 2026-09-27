import QtQuick
import qs.Commons
import "Sim.js" as Sim

// Only supplied, recorded participants are rendered. This item can be exported
// by itself: no window, desktop, server address or owner identity is captured.
//
// The scene is painted from the desktop's own theme, so a moment saved on a
// Tokyo Night desktop looks like it was taken there: the sky from the popup
// background and accent, grass that sits in either a light or a dark theme,
// and text in the theme's foreground. The props keep their own colours.
Item {
  id: root
  property var scene: null
  property var child: null
  property string caption: ""
  // What kind of keepsake this is, printed small in the footer beside the
  // product's name rather than as a label over the picture.
  property string eyebrow: "A MOMENT TOGETHER"
  property bool animated: false
  // Thumbnails: the picture alone, without names, caption or footer.
  property bool compact: false
  readonly property var people: scene ? scene.participants || [] : []
  implicitHeight: width * 0.625
  height: implicitHeight
  clip: true

  function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
  }
  function tintFor(seed) {
    // The same lean toward the accent the bar gives your own creature, applied
    // to everyone, so a creature has one colour on this desktop.
    return Qt.tint(Qt.hsla(Sim.seededUnit(seed, 11), 0.52, 0.62, 1),
                   Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18))
  }

  readonly property color canvas: Color.popups.background
  readonly property bool dark: canvas.r * 0.2126 + canvas.g * 0.7152 + canvas.b * 0.0722 < 0.5
  readonly property color skyTop: dark ? Qt.darker(canvas, 1.35) : Qt.lighter(canvas, 1.02)
  readonly property color skyBottom: mix(canvas, Color.accent, dark ? 0.16 : 0.12)
  readonly property color ground: mix(dark ? Qt.rgba(0.243, 0.353, 0.282, 1) : Qt.rgba(0.725, 0.831, 0.694, 1), canvas, 0.25)
  // The popup surface's own text colour, so text and sky always come from the
  // same pair, whichever way a theme defines its surfaces.
  readonly property color ink: Color.popups.text
  readonly property color quiet: Qt.rgba(ink.r, ink.g, ink.b, 0.72)

  Item {
    width: 640; height: 400
    scale: root.width / 640
    transformOrigin: Item.TopLeft
    Rectangle {
      anchors.fill: parent; radius: 18
      gradient: Gradient {
        GradientStop { position: 0; color: root.skyTop }
        GradientStop { position: 1; color: root.skyBottom }
      }
    }
    Repeater {
      model: root.dark ? 15 : 0
      Rectangle {
        required property int index
        x: 20 + ((index + 1) * 137) % 600; y: 35 + ((index + 1) * 41) % 145
        width: index % 3 === 0 ? 3 : 2; height: width; radius: width
        color: root.mix(Color.accent, Qt.rgba(1, 1, 1, 1), 0.55); opacity: 0.5
      }
    }
    // The hill is clipped short of the bottom so it cannot square off the
    // rounded corners; a band with the frame's own radius finishes the ground.
    Item {
      width: 640; height: 372; clip: true
      Rectangle { x: -50; y: 275; width: 740; height: 230; radius: 210; color: root.ground }
    }
    Rectangle { y: 352; width: 640; height: 48; radius: 18; color: root.ground }
    Repeater {
      model: root.people
      delegate: Item {
        required property var modelData
        required property int index
        // A portrait fills the middle; two creatures share the frame.
        readonly property bool alone: root.people.length === 1
        x: alone ? 200 : (index === 0 ? 90 : 360); y: alone ? 40 : 78
        width: alone ? 240 : 190; height: alone ? 268 : 220
        Creature {
          width: parent.width; height: parent.width; size: parent.width
          seed: parent.modelData.seed; stageKey: parent.modelData.stage
          bodyScale: Sim.stageScale(stageKey)
          mood: parent.modelData.mood || "happy"; happiness: 90; animated: root.animated; detail: true
          tint: root.tintFor(seed)
          activity: parent.modelData.activity || "idle"
          costume: parent.modelData.costume || ""
          music: (root.scene && root.scene.scene === "radio") || parent.modelData.music === true
          beat: sceneBeat.count
        }
        Text {
          visible: !root.compact
          anchors.bottom: parent.bottom; width: parent.width
          text: parent.modelData.name; textFormat: Text.PlainText
          color: root.ink; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 18; font.bold: true
        }
      }
    }
    Timer { id: sceneBeat; property int count: 0; interval: 600; repeat: true; running: root.animated && root.visible && root.scene && root.scene.scene === "radio"; onTriggered: count++ }
    // Small authored props make the recorded activity visible.
    Rectangle {
      x: 279; y: 224; width: 82; height: 45; radius: 8
      visible: root.scene && root.scene.scene === "radio"
      color: "#d4a66c"; border.color: "#182b31"; border.width: 3
      Rectangle { x: 7; y: 9; width: 27; height: 27; radius: 14; color: "#314148" }
      Rectangle { x: 48; y: 10; width: 24; height: 9; radius: 2; color: "#eddfb6" }
      Rectangle { x: 48; y: 26; width: 7; height: 7; radius: 4; color: "#314148" }
      Rectangle { x: 21; y: -18; width: 3; height: 23; rotation: 22; color: "#d4a66c" }
    }
    Rectangle {
      x: 286; y: 235; width: 68; height: 35; radius: 13; rotation: -9
      visible: root.scene && root.scene.scene === "gift"
      color: "#acb6ae"; border.color: "#dce0c5"; border.width: 2
    }
    Item {
      x: 279; y: 217; width: 82; height: 56; visible: root.scene && root.scene.scene === "hat"
      Rectangle { x: 17; y: 2; width: 48; height: 40; radius: 9; rotation: -12; color: "#d8ae72" }
      Rectangle { y: 36; width: 82; height: 10; radius: 5; color: "#c98c59" }
    }
    Item {
      x: 270; y: 205; width: 100; height: 70; visible: root.scene && root.scene.scene === "shelter"
      Rectangle { x: 14; y: 25; width: 6; height: 46; rotation: 12; color: "#c29f73" }
      Rectangle { x: 77; y: 25; width: 6; height: 46; rotation: -9; color: "#c29f73" }
      Rectangle { y: 10; width: 100; height: 13; rotation: -16; radius: 3; color: "#cfac77" }
    }
    Rectangle {
      x: 296; y: 235; width: 48; height: 35; radius: 20
      visible: root.scene && (root.scene.scene === "picnic" || root.scene.scene === "hearts")
      color: "#cfa374"
      Repeater { model: 5; Rectangle { required property int index; x: 7 + (index * 17) % 34; y: 6 + (index * 13) % 20; width: 4; height: 4; radius: 2; color: "#654c3a" } }
    }
    Text { x: 305; y: 162; text: "♥"; color: "#e6a3ad"; font.pixelSize: 32; visible: root.scene && root.scene.scene === "hearts" }
    Creature {
      x: 269; y: 170; size: 102; visible: root.child !== null
      seed: root.child ? root.child.seed : 0; stageKey: root.child ? root.child.stage : "egg"
      ownSeed: root.child ? Sim.seedFromId(root.child.id) : 0
      bodyScale: Sim.stageScale(stageKey); mood: "happy"; animated: root.animated
      tint: root.tintFor(root.child ? root.child.colorSeed : 0)
    }
    Text {
      visible: !root.compact
      x: 32; y: 315; width: 576; height: 60
      text: root.caption; textFormat: Text.PlainText; wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter; color: root.ink; font.pixelSize: 20
      fontSizeMode: Text.Fit; minimumPixelSize: 13
    }
    Text {
      visible: !root.compact
      x: 26; y: 376; text: root.eyebrow; textFormat: Text.PlainText
      color: root.quiet; font.pixelSize: 10; font.letterSpacing: 1.5
    }
    Text {
      visible: !root.compact
      anchors.right: parent.right; anchors.rightMargin: 26; y: 376
      text: "OMARCHYGOTCHI"; color: root.quiet; font.pixelSize: 10; font.letterSpacing: 1.5; font.bold: true
    }
  }
}
