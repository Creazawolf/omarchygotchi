pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// ---------------------------------------------------------------------------
// What the creature is wearing or holding, based on what you are doing.
//
// Split out of Creature.qml because it is a different job: Creature owns a
// body and a face, this owns props. It takes the body geometry as plain
// numbers rather than reaching into the creature, so a prop never has to know
// which life stage it is sitting on.
//
// Headphones are a layer, not a mode: they go on whenever music is playing,
// alongside whatever the current activity is holding. Everything else is
// mutually exclusive.
// ---------------------------------------------------------------------------
Item {
  id: root

  property real u: 1
  property real bodyCx: 0
  property real bodyCy: 0
  property real bodyW: 0
  property real bodyH: 0
  property real bodyScale: 1
  property real eyeY: 0
  property real eyeDx: 0
  property real eyeR: 0

  property string activity: "idle"
  property string hat: ""          // seasonal costume hat, e.g. "witch"
  property bool music: false
  property bool detail: true
  property bool animated: true

  property color tint: "#7fd1c1"
  property color ink: "#101315"
  property color accent: "#7fd1c1"

  // Beat counter from Awareness. Props that pulse read this rather than
  // running their own clock, so the headphones throb in time with the dancing.
  property int beat: 0
  property int beatMs: 500

  readonly property real s: bodyScale

  // A prop must never be the reason you can't read the face, so at bar size
  // only the silhouette-changing ones survive: headphones, and a still
  // propeller cap while an agent works.
  readonly property bool showsProp: detail
  function has(name) { return activity === name }

  // ------------------------------------------------------------ headphones

  property real cupPulse: 0

  onBeatChanged: if (root.music && root.animated) cupPulseAnim.restart()

  // Same budget rule as the creature: smooth in the panel, two frames per beat
  // in the bar, so a full-width bar is not repainted sixty times a second.
  SequentialAnimation {
    id: cupPulseAnim
    NumberAnimation { target: root; property: "cupPulse"; to: 1; duration: root.detail ? 90 : 0; easing.type: Easing.OutQuad }
    PauseAnimation { duration: root.detail ? 0 : 140 }
    NumberAnimation { target: root; property: "cupPulse"; to: 0; duration: root.detail ? Math.max(120, root.beatMs - 90) : 0; easing.type: Easing.OutCubic }
  }

  Item {
    id: headphones
    visible: root.music
    anchors.fill: parent
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 240 } }

    readonly property real cupX: root.bodyW * 0.50 + root.u * 2
    readonly property real cupY: root.eyeY + root.u * 2

    // Band. Drawn first so the cups cover where it meets them.
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.darker(root.ink, 0.85)
        strokeWidth: Math.max(1.5, 4 * root.u * root.s)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: root.bodyCx - headphones.cupX
        startY: headphones.cupY - root.u * 6
        PathQuad {
          x: root.bodyCx + headphones.cupX
          y: headphones.cupY - root.u * 6
          controlX: root.bodyCx
          controlY: root.bodyCy - root.bodyH * 0.68
        }
      }
    }

    Repeater {
      model: 2
      Item {
        id: cup
        required property int index
        readonly property real dir: index === 0 ? -1 : 1
        x: root.bodyCx + dir * headphones.cupX
        y: headphones.cupY
        scale: 1 + root.cupPulse * 0.14

        Rectangle {
          width: 14 * root.u * root.s
          height: 19 * root.u * root.s
          radius: width * 0.45
          x: -width / 2
          y: -height / 2
          color: Qt.darker(root.ink, 0.85)

          Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.52
            height: parent.height * 0.5
            radius: width / 2
            color: Qt.lighter(root.accent, 1.3)
            opacity: 0.35 + root.cupPulse * 0.55
          }
        }
      }
    }
  }

  // --------------------------------------------------------------- glasses

  Item {
    visible: root.showsProp && root.has("browsing")
    anchors.fill: parent

    Repeater {
      model: 2
      Rectangle {
        id: lens
        required property int index
        readonly property real dir: index === 0 ? -1 : 1
        width: root.eyeR * 2.55
        height: root.eyeR * 2.25
        radius: height / 2
        x: root.bodyCx + dir * root.eyeDx - width / 2
        y: root.eyeY - height / 2
        color: Qt.rgba(1, 1, 1, 0.10)
        border.width: Math.max(1.2, 2.2 * root.u * root.s)
        border.color: Qt.darker(root.ink, 0.9)

        // The one diagonal glint that makes a circle read as glass.
        Rectangle {
          width: parent.width * 0.42
          height: Math.max(1, 1.6 * root.u * root.s)
          radius: height / 2
          x: parent.width * 0.16
          y: parent.height * 0.30
          color: Qt.rgba(1, 1, 1, 0.7)
          rotation: -28
        }
      }
    }

    Rectangle {
      width: root.eyeDx * 2 - root.eyeR * 2.4
      height: Math.max(1.2, 2.2 * root.u * root.s)
      radius: height / 2
      x: root.bodyCx - width / 2
      y: root.eyeY - height / 2
      color: Qt.darker(root.ink, 0.9)
    }
  }

  // ---------------------------------------------------------------- laptop

  Item {
    id: laptop
    visible: root.showsProp && root.has("coding")
    anchors.fill: parent

    readonly property real cx: root.bodyCx
    readonly property real baseY: root.bodyCy + root.bodyH * 0.66
    readonly property real w: 36 * root.u * root.s

    // Screen, leaning back off the hinge.
    Rectangle {
      width: laptop.w * 0.86
      height: 18 * root.u * root.s
      x: laptop.cx - width / 2
      y: laptop.baseY - height
      radius: 2 * root.u
      color: Qt.darker(root.ink, 0.8)
      transformOrigin: Item.Bottom
      rotation: -10

      Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(1, 2 * root.u * root.s)
        radius: 1.5 * root.u
        color: Qt.lighter(root.accent, 1.35)
        opacity: 0.30 + screenFlicker.value * 0.45

        // Three bars of "code", the middle one restlessly resizing. Reads as a
        // live screen at 20px without drawing a single glyph.
        Column {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.margins: Math.max(1, 2.5 * root.u * root.s)
          spacing: Math.max(1, 2 * root.u * root.s)

          Repeater {
            model: 3
            Rectangle {
              id: codeLine
              required property int index
              width: (index === 1 ? 7 + screenFlicker.value * 7 : (index === 0 ? 12 : 9)) * root.u * root.s
              height: Math.max(1, 2 * root.u * root.s)
              radius: height / 2
              color: Qt.darker(root.ink, 0.9)
              opacity: 0.75
            }
          }
        }
      }
    }

    // Base.
    Rectangle {
      width: laptop.w
      height: 5 * root.u * root.s
      x: laptop.cx - width / 2
      y: laptop.baseY - height / 2
      radius: height / 2
      color: Qt.darker(root.ink, 0.72)
    }
  }

  // Shared flicker driver for the laptop and phone screens.
  QtObject {
    id: screenFlicker
    property real value: 0
  }

  SequentialAnimation {
    running: root.animated && (root.has("coding") || root.has("chatting"))
    loops: Animation.Infinite
    NumberAnimation { target: screenFlicker; property: "value"; to: 1; duration: 260; easing.type: Easing.InOutQuad }
    NumberAnimation { target: screenFlicker; property: "value"; to: 0.2; duration: 340; easing.type: Easing.InOutQuad }
    NumberAnimation { target: screenFlicker; property: "value"; to: 0.7; duration: 180; easing.type: Easing.InOutQuad }
  }

  // ------------------------------------------------------------- propeller
  //
  // The agent-watching hat. A spinning thing above the head reads as "work in
  // progress" faster than any icon, and it stops the instant the agent does.

  Item {
    id: propeller
    visible: root.showsProp && root.has("agent")
    anchors.fill: parent

    readonly property real topY: root.bodyCy - root.bodyH * 0.5 - (root.music ? 16 : 7) * root.u
    readonly property real hubY: topY - 10 * root.u * root.s

    // The stem is measured down to the skull rather than given a fixed length,
    // so the propeller stays attached whatever the life stage or headgear.
    Rectangle {
      width: Math.max(1.4, 2.6 * root.u * root.s)
      height: Math.max(0, root.bodyCy - root.bodyH * 0.46 - propeller.hubY)
      x: root.bodyCx - width / 2
      y: propeller.hubY
      color: Qt.darker(root.ink, 0.85)
    }

    Item {
      x: root.bodyCx
      y: propeller.hubY

      RotationAnimation on rotation {
        // Only spun where it is big enough to read; in the bar the propeller
        // is four pixels of blur that would cost a full-width repaint.
        running: propeller.visible && root.animated && root.detail
        from: 0; to: 360
        duration: 620
        loops: Animation.Infinite
      }

      Repeater {
        model: 2
        Rectangle {
          id: blade
          required property int index
          width: 26 * root.u * root.s
          height: Math.max(2, 4.5 * root.u * root.s)
          radius: height / 2
          x: -width / 2
          y: -height / 2
          rotation: index * 90
          color: index === 0 ? Qt.lighter(root.accent, 1.4) : Qt.darker(root.accent, 1.2)
        }
      }

      Rectangle {
        width: 6 * root.u * root.s
        height: width
        radius: width / 2
        x: -width / 2
        y: -height / 2
        color: Qt.darker(root.ink, 0.85)
      }
    }
  }

  // -------------------------------------------------------- bar propeller cap
  //
  // At bar size the propeller hat keeps its silhouette and loses the spin: a
  // striped cap sitting on the head and a two-lobed blade seen from above,
  // held still. An agent at work then costs one repaint when it starts and
  // one when it stops, and the whole hat fits in the few pixels a 26px bar
  // leaves above the head. The colours are the propeller beanie's own, not the
  // theme's, because that is what makes it recognisable at this size.

  Item {
    id: barCap
    visible: !root.detail && root.has("agent")
    anchors.fill: parent

    readonly property real headTop: root.bodyCy - root.bodyH * 0.5
    readonly property real capW: root.bodyW * 0.70
    readonly property real capBase: headTop + root.bodyH * 0.22
    readonly property real capTop: headTop - root.bodyH * 0.03
    readonly property real stripeW: capW * 0.26
    readonly property real bladeY: capTop - Math.max(1.2, 3.2 * root.u)
    readonly property real bladeW: root.bodyW * 0.84
    readonly property real bladeH: Math.max(2.4, 6.5 * root.u)

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      // The dome. A quad peaks halfway to its control point, so the control
      // sits twice as far above the base as the cap is tall.
      ShapePath {
        fillColor: "#e8705f"
        strokeWidth: 0
        startX: root.bodyCx - barCap.capW / 2
        startY: barCap.capBase
        PathQuad {
          x: root.bodyCx + barCap.capW / 2
          y: barCap.capBase
          controlX: root.bodyCx
          controlY: barCap.capTop * 2 - barCap.capBase
        }
        PathLine { x: root.bodyCx - barCap.capW / 2; y: barCap.capBase }
      }

      // The centre panel, narrowing toward the crown.
      ShapePath {
        fillColor: "#f2c14e"
        strokeWidth: 0
        startX: root.bodyCx - barCap.stripeW / 2
        startY: barCap.capBase
        PathLine { x: root.bodyCx - barCap.stripeW * 0.18; y: barCap.capTop + 0.4 }
        PathLine { x: root.bodyCx + barCap.stripeW * 0.18; y: barCap.capTop + 0.4 }
        PathLine { x: root.bodyCx + barCap.stripeW / 2; y: barCap.capBase }
      }

      // Two lobes meeting at the hub, each its own colour.
      ShapePath {
        fillColor: "#5fa8e8"
        strokeWidth: 0
        startX: root.bodyCx
        startY: barCap.bladeY
        PathLine { x: root.bodyCx - barCap.bladeW / 2; y: barCap.bladeY - barCap.bladeH / 2 }
        PathLine { x: root.bodyCx - barCap.bladeW / 2; y: barCap.bladeY + barCap.bladeH / 2 }
        PathLine { x: root.bodyCx; y: barCap.bladeY }
      }
      ShapePath {
        fillColor: "#f2c14e"
        strokeWidth: 0
        startX: root.bodyCx
        startY: barCap.bladeY
        PathLine { x: root.bodyCx + barCap.bladeW / 2; y: barCap.bladeY - barCap.bladeH / 2 }
        PathLine { x: root.bodyCx + barCap.bladeW / 2; y: barCap.bladeY + barCap.bladeH / 2 }
        PathLine { x: root.bodyCx; y: barCap.bladeY }
      }
    }

    // Stem and hub, dark so the blade reads as two lobes rather than a line.
    Rectangle {
      width: Math.max(1, 2 * root.u)
      height: Math.max(1, barCap.capTop - barCap.bladeY + 0.5)
      x: root.bodyCx - width / 2
      y: barCap.bladeY
      color: Qt.darker(root.ink, 0.85)
    }
    Rectangle {
      width: Math.max(1.6, 4 * root.u)
      height: width
      radius: width / 2
      x: root.bodyCx - width / 2
      y: barCap.bladeY - height / 2
      color: Qt.darker(root.ink, 0.85)
    }
  }

  // ------------------------------------------------------------- witch hat
  //
  // Halloween week (Sim.season). A cone with a bent tip, an orange band and a
  // wide brim. In the bar it is squatter and bends further sideways, keeping
  // its silhouette inside the few pixels above the head.

  Item {
    id: witch
    visible: root.hat === "witch"
    anchors.fill: parent

    readonly property real headTop: root.bodyCy - root.bodyH * 0.5
    readonly property real brimY: headTop + root.bodyH * 0.09
    readonly property real brimW: root.bodyW * 1.04
    readonly property real brimH: Math.max(1.6, root.bodyH * 0.10)
    readonly property real coneW: root.bodyW * 0.58
    readonly property real coneH: root.bodyH * (root.detail ? 0.64 : 0.30)
    readonly property real tipX: root.bodyCx - root.bodyW * (root.detail ? 0.24 : 0.36)
    readonly property real tipY: brimY - coneH
    readonly property real bandH: Math.max(1.2, root.bodyH * 0.07)

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: "#4b3566"
        strokeColor: "#7a5aa0"
        strokeWidth: Math.max(1, 1.4 * root.u)
        joinStyle: ShapePath.RoundJoin
        startX: root.bodyCx - witch.coneW / 2
        startY: witch.brimY
        PathQuad {
          x: witch.tipX; y: witch.tipY
          controlX: root.bodyCx - witch.coneW * 0.18
          controlY: witch.brimY - witch.coneH * 0.55
        }
        PathQuad {
          x: root.bodyCx + witch.coneW / 2; y: witch.brimY
          controlX: root.bodyCx + witch.coneW * 0.12
          controlY: witch.brimY - witch.coneH * 0.78
        }
      }
    }

    // The band sits just above the brim, where the cone is still at its widest.
    Rectangle {
      width: witch.coneW * 0.9
      height: witch.bandH
      x: root.bodyCx - width / 2 + witch.coneW * 0.02
      y: witch.brimY - witch.brimH * 0.4 - height
      color: "#f08a3c"
    }

    Rectangle {
      width: witch.brimW
      height: witch.brimH
      radius: height / 2
      x: root.bodyCx - width / 2
      y: witch.brimY - height / 2
      color: "#3b2952"
      border.width: Math.max(1, 1.2 * root.u)
      border.color: "#7a5aa0"
    }
  }

  // --------------------------------------------------------------- popcorn

  Item {
    id: popcorn
    visible: root.showsProp && root.has("video")
    anchors.fill: parent

    readonly property real bx: root.bodyCx + root.bodyW * 0.56
    readonly property real by: root.bodyCy + root.bodyH * 0.50

    Repeater {
      model: 4
      Rectangle {
        id: kernel
        required property int index
        width: 6 * root.u * root.s
        height: width
        radius: width / 2
        x: popcorn.bx - 9 * root.u * root.s + (index % 3) * 7 * root.u * root.s
        y: popcorn.by - 20 * root.u * root.s - (index === 1 ? 4 : 0) * root.u * root.s
        color: "#f2e3b0"
      }
    }

    // Bucket: a tapered tub, striped the only way anyone draws popcorn.
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: "#d9534f"
        strokeWidth: 0
        startX: popcorn.bx - 11 * root.u * root.s
        startY: popcorn.by - 18 * root.u * root.s
        PathLine { x: popcorn.bx + 11 * root.u * root.s; y: popcorn.by - 18 * root.u * root.s }
        PathLine { x: popcorn.bx + 8 * root.u * root.s;  y: popcorn.by + 2 * root.u * root.s }
        PathLine { x: popcorn.bx - 8 * root.u * root.s;  y: popcorn.by + 2 * root.u * root.s }
      }
    }

    Repeater {
      model: 2
      Rectangle {
        id: stripe
        required property int index
        width: Math.max(1.5, 3 * root.u * root.s)
        height: 20 * root.u * root.s
        x: popcorn.bx + (index === 0 ? -4 : 4) * root.u * root.s - width / 2
        y: popcorn.by - 18 * root.u * root.s
        color: "#f7f2e8"
        opacity: 0.9
      }
    }
  }

  // ------------------------------------------------------------ controller

  Item {
    id: gamepad
    visible: root.showsProp && root.has("gaming")
    anchors.fill: parent

    readonly property real cx: root.bodyCx
    readonly property real cy: root.bodyCy + root.bodyH * 0.54

    Rectangle {
      width: 30 * root.u * root.s
      height: 15 * root.u * root.s
      radius: height * 0.42
      x: gamepad.cx - width / 2
      y: gamepad.cy - height / 2
      color: Qt.darker(root.ink, 0.78)

      Rectangle {
        width: 4 * root.u * root.s; height: width; radius: width / 2
        x: parent.width * 0.66; y: parent.height * 0.28
        color: "#e8705f"
      }
      Rectangle {
        width: 4 * root.u * root.s; height: width; radius: width / 2
        x: parent.width * 0.80; y: parent.height * 0.50
        color: "#67c98a"
      }
      Rectangle {
        width: 9 * root.u * root.s; height: Math.max(1.5, 3 * root.u * root.s); radius: height / 2
        x: parent.width * 0.10; y: parent.height * 0.44
        color: Qt.lighter(root.ink, 2.2)
      }
      Rectangle {
        width: Math.max(1.5, 3 * root.u * root.s); height: 9 * root.u * root.s; radius: width / 2
        x: parent.width * 0.10 + 3 * root.u * root.s; y: parent.height * 0.44 - 3 * root.u * root.s
        color: Qt.lighter(root.ink, 2.2)
      }
    }
  }

  // ---------------------------------------------------------------- palette

  Item {
    id: palette
    visible: root.showsProp && root.has("making")
    anchors.fill: parent

    readonly property real cx: root.bodyCx + root.bodyW * 0.50
    readonly property real cy: root.bodyCy + root.bodyH * 0.36

    Rectangle {
      width: 26 * root.u * root.s
      height: 20 * root.u * root.s
      radius: width / 2
      x: palette.cx - width / 2
      y: palette.cy - height / 2
      color: "#c9a27a"

      Rectangle {
        width: parent.width * 0.24; height: width; radius: width / 2
        x: parent.width * 0.60; y: parent.height * 0.52
        color: Qt.darker("#c9a27a", 1.6)
      }

      Repeater {
        model: ["#e8705f", "#67c98a", "#5fa8e8", "#e8cf5f"]
        Rectangle {
          id: blob
          required property int index
          required property var modelData
          width: parent.width * 0.20; height: width; radius: width / 2
          x: parent.width * (0.12 + (index % 2) * 0.26)
          y: parent.height * (0.14 + Math.floor(index / 2) * 0.34)
          color: modelData
        }
      }
    }
  }

  // ------------------------------------------------------------------ phone

  Item {
    visible: root.showsProp && root.has("chatting")
    anchors.fill: parent

    Rectangle {
      width: 13 * root.u * root.s
      height: 21 * root.u * root.s
      radius: 3 * root.u
      x: root.bodyCx + root.bodyW * 0.40 - width / 2
      y: root.bodyCy + root.bodyH * 0.26
      color: Qt.darker(root.ink, 0.78)
      rotation: -12

      Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(1, 1.8 * root.u * root.s)
        radius: 2 * root.u
        color: Qt.lighter(root.accent, 1.5)
        opacity: 0.55 + screenFlicker.value * 0.4
      }
    }
  }

  // --------------------------------------------------------------- nightcap

  Item {
    visible: root.showsProp && root.has("away")
    anchors.fill: parent

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: Qt.darker(root.accent, 1.5)
        strokeWidth: 0
        startX: root.bodyCx - root.bodyW * 0.34
        startY: root.bodyCy - root.bodyH * 0.40
        PathLine { x: root.bodyCx + root.bodyW * 0.30; y: root.bodyCy - root.bodyH * 0.40 }
        PathQuad {
          x: root.bodyCx + root.bodyW * 0.62
          y: root.bodyCy - root.bodyH * 0.66
          controlX: root.bodyCx + root.bodyW * 0.34
          controlY: root.bodyCy - root.bodyH * 0.78
        }
        PathQuad {
          x: root.bodyCx - root.bodyW * 0.34
          y: root.bodyCy - root.bodyH * 0.40
          controlX: root.bodyCx - root.bodyW * 0.20
          controlY: root.bodyCy - root.bodyH * 0.72
        }
      }
    }

    Rectangle {
      width: 9 * root.u * root.s
      height: width
      radius: width / 2
      x: root.bodyCx + root.bodyW * 0.62 - width / 2
      y: root.bodyCy - root.bodyH * 0.66 - height / 2
      color: "#f2eee6"
    }
  }
}
