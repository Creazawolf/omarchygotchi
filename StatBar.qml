import QtQuick
import qs.Commons

// ---------------------------------------------------------------------------
// One care meter. Colour is semantic, not thematic: a starving creature has to
// read as red in every Omarchy theme, so green/amber come from fixed values
// while the alarm colour tracks the theme's own urgent role.
// ---------------------------------------------------------------------------
Item {
  id: root

  property string glyph: ""
  property string label: ""
  property real value: 0                 // 0..100
  property color foreground: Color.foreground
  property color urgent: Color.urgent
  property bool dimmed: false            // the creature is asleep or gone

  readonly property color good: "#63c98a"
  readonly property color warn: "#e0a94a"
  readonly property bool critical: value < 20

  readonly property color barColor: value >= 50 ? good : (value >= 22 ? warn : urgent)

  implicitHeight: Math.max(track.height, labelText.implicitHeight) + Style.space(6)
  width: parent ? parent.width : implicitWidth

  opacity: dimmed ? 0.45 : 1
  Behavior on opacity { NumberAnimation { duration: 250 } }

  Text {
    id: glyphText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.glyph
    font.pixelSize: Style.font.body
    width: Style.space(20)
  }

  Text {
    id: labelText
    anchors.left: glyphText.right
    anchors.leftMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    text: root.label.toUpperCase()
    textFormat: Text.PlainText
    color: Qt.darker(root.foreground, 1.35)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1.1
    width: Style.space(72)
    elide: Text.ElideRight
  }

  Text {
    id: valueText
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: Math.round(root.value)
    textFormat: Text.PlainText
    color: root.critical ? root.urgent : Qt.darker(root.foreground, 1.2)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
    horizontalAlignment: Text.AlignRight
    width: Style.space(22)
  }

  Rectangle {
    id: track
    anchors.left: labelText.right
    anchors.leftMargin: Style.space(8)
    anchors.right: valueText.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    height: Style.space(8)
    radius: height / 2
    color: Style.normalFillFor(root.foreground, root.foreground)

    Rectangle {
      id: fill
      height: parent.height
      // Never let a non-zero stat vanish entirely — a hairline of colour says
      // "critical", an empty track says "no data".
      width: root.value <= 0 ? 0 : Math.max(parent.height, parent.width * Math.min(1, root.value / 100))
      radius: height / 2

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.darker(root.barColor, 1.25) }
        GradientStop { position: 1.0; color: Qt.lighter(root.barColor, 1.15) }
      }

      Behavior on width { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    }

    // A critical meter breathes. Pulsing a separate glow instead of the fill
    // itself keeps the fill's own opacity a plain constant — an `on opacity`
    // animation would strand the property at whatever value it stopped on.
    Rectangle {
      id: pulse
      anchors.fill: fill
      radius: fill.radius
      color: Qt.lighter(root.barColor, 1.5)
      visible: root.critical && !root.dimmed
      opacity: 0

      SequentialAnimation on opacity {
        running: pulse.visible
        loops: Animation.Infinite
        NumberAnimation { to: 0.55; duration: 620; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0;  duration: 620; easing.type: Easing.InOutSine }
      }
    }
  }
}
