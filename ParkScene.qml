import QtQuick
import qs.Commons
import "Sim.js" as Sim

// ---------------------------------------------------------------------------
// The park, as a place: your creature on the left, the creatures that matter
// to it standing on the grass beside it. A friend whose owner is at their
// desk right now is awake; the others are napping in the sun. Click one to
// see your story with it; click your own creature to step back.
//
// Drawn from the same primitives and the same sky as the habitat, so the two
// tabs read as two places in one world.
// ---------------------------------------------------------------------------
Item {
  id: root

  property var me: null                 // { name, seed, stage, mood }
  property color meTint: Color.accent
  property var others: []               // [{ creature, level, friend }], at most five shown
  property string selectedId: ""
  property color skyTop: Qt.lighter(Color.popups.background, 1.12)
  property color skyBottom: Qt.lighter(Color.popups.background, 1.26)
  property color foreground: Color.foreground
  property bool animated: false
  property bool calm: false
  property string emptyText: ""

  signal picked(string id)

  readonly property var shown: (others || []).slice(0, 5)
  readonly property real groundY: height - Style.space(46)
  readonly property real otherSize: shown.length > 3 ? Style.space(66) : Style.space(76)

  function tintFor(seed) {
    return Qt.tint(Qt.hsla(Sim.seededUnit(seed, 11), 0.52, 0.62, 1),
                   Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18))
  }

  implicitHeight: Style.space(196)
  clip: true

  Rectangle {
    anchors.fill: parent
    radius: Math.max(Style.cornerRadius, Style.space(6))
    border.width: 1
    border.color: Style.normalBorderFor(root.foreground, Color.accent)
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.skyTop }
      GradientStop { position: 1.0; color: root.skyBottom }
    }
  }

  // A tree at the edge, so the grass reads as a park rather than a floor.
  Item {
    x: root.width - Style.space(58)
    y: root.groundY - Style.space(96)
    width: Style.space(80); height: Style.space(110)
    opacity: 0.55
    Rectangle { x: parent.width * 0.44; y: parent.height * 0.52; width: parent.width * 0.12; height: parent.height * 0.5; radius: width / 2; color: Qt.darker(root.skyTop, 1.35) }
    Rectangle { x: 0; y: parent.height * 0.12; width: parent.width * 0.62; height: width; radius: width / 2; color: Qt.rgba(0.30, 0.45, 0.33, 1) }
    Rectangle { x: parent.width * 0.34; y: 0; width: parent.width * 0.66; height: width; radius: width / 2; color: Qt.rgba(0.34, 0.50, 0.37, 1) }
  }

  // Ground: the same soft ellipse the habitat stands on.
  Rectangle {
    width: root.width * 1.5
    height: Style.space(84)
    radius: width / 2
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.groundY - Style.space(12)
    color: Qt.lighter(root.meTint, 1.05)
    opacity: 0.13
  }

  // ---- you
  Item {
    id: meSlot
    visible: root.me !== null
    width: Style.space(96); height: root.height
    x: root.width * 0.14 - width / 2

    Rectangle {
      width: Style.space(58); height: Style.space(8); radius: height / 2
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.groundY - height / 2
      color: root.meTint
      opacity: root.selectedId === "" && root.shown.length > 0 ? 0.35 : 0
      Behavior on opacity { NumberAnimation { duration: 200 } }
    }
    Creature {
      size: Style.space(92)
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.groundY - size * 0.86
      seed: root.me ? root.me.seed : 1
      stageKey: root.me ? root.me.stage : "adult"
      bodyScale: Sim.stageScale(stageKey)
      mood: root.me && root.me.mood ? root.me.mood : "happy"
      happiness: 80
      tint: root.meTint
      animated: root.animated
      calm: root.calm
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.groundY + Style.space(6)
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      text: root.me ? root.me.name : ""
      textFormat: Text.PlainText
      color: root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
    MouseArea {
      anchors.fill: parent
      enabled: root.shown.length > 0
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.picked("")
    }
  }

  // ---- the creatures that matter
  Repeater {
    model: root.shown
    Item {
      id: slot
      required property var modelData
      required property int index
      readonly property var pet: modelData.creature
      readonly property bool chosen: root.selectedId === pet.id
      readonly property real span: root.width * 0.66
      width: Math.min(Style.space(92), span / Math.max(1, root.shown.length))
      height: root.height
      x: root.width * 0.28 + span * (index + 0.5) / Math.max(root.shown.length, 2) - width / 2

      Rectangle {
        width: Style.space(50); height: Style.space(8); radius: height / 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.groundY - height / 2
        color: root.meTint
        opacity: slot.chosen ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
      }
      Creature {
        size: root.otherSize
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.groundY - size * 0.86
        seed: slot.pet.seed
        stageKey: slot.pet.stage
        bodyScale: Sim.stageScale(stageKey)
        // Awake if their owner is here right now; napping otherwise.
        mood: slot.pet.online ? "happy" : "asleep"
        happiness: 80
        tint: root.tintFor(slot.pet.seed)
        animated: root.animated
        calm: root.calm
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.groundY + Style.space(6)
        width: parent.width + Style.space(8)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: slot.pet.name
        textFormat: Text.PlainText
        color: slot.chosen ? root.foreground : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.78)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: slot.chosen
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(slot.chosen ? "" : slot.pet.id)
      }
    }
  }

  Text {
    visible: root.shown.length === 0 && root.emptyText !== ""
    x: root.width * 0.34
    width: root.width * 0.58
    y: root.groundY - Style.space(52)
    text: root.emptyText
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.8)
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }
}
