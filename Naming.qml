import QtQuick
import qs.Commons
import qs.Ui
import "Sim.js" as Sim
import "Messages.js" as Msg

// ---------------------------------------------------------------------------
// Naming, once right after the hatch and again whenever the owner clicks the
// name in the habitat.
//
// The seeded name is only a suggestion: it arrives prefilled and selected, so
// Enter keeps it and typing replaces it. Nothing here touches the save; the
// panel routes `chosen` to the service like every other action.
// ---------------------------------------------------------------------------
Column {
  id: root

  property string currentName: ""
  property bool firstTime: true
  property string language: "en"
  property color foreground: Color.foreground
  property color accent: Color.accent

  readonly property var strings: Msg.ui(language)
  readonly property bool editing: field.activeFocus
  readonly property string cleaned: Sim.cleanName(field.text)

  signal chosen(string name)
  signal cancelled()

  spacing: Style.space(8)

  function begin() {
    field.text = currentName
    field.forceActiveFocus()
    field.selectAll()
  }

  function commit() { if (cleaned !== "") root.chosen(cleaned) }

  Text {
    width: parent.width
    text: root.firstTime ? root.strings.nameFirst : Msg.fill(root.strings.nameAgain, root.currentName)
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: root.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.subtitle
    font.bold: true
  }

  Row {
    width: parent.width
    spacing: Style.space(6)

    TextField {
      id: field
      width: parent.width - another.width - parent.spacing
      maximumLength: 20
      foreground: root.foreground
      accent: root.accent
      onAccepted: root.commit()
      Keys.onEscapePressed: function(event) { event.accepted = true; root.cancelled() }
    }

    // Right beside the field it changes, so a reroll never looks like a save.
    Button {
      id: another
      anchors.verticalCenter: field.verticalCenter
      text: root.strings.nameAnother
      bordered: true
      foreground: root.foreground
      accent: root.accent
      onClicked: {
        field.text = Sim.suggestName(root.cleaned)
        field.forceActiveFocus()
        field.selectAll()
      }
    }
  }

  Flow {
    width: parent.width
    spacing: Style.space(6)

    Button {
      text: root.firstTime ? root.strings.nameIt : root.strings.nameSave
      bordered: true
      selected: true
      foreground: root.foreground
      accent: root.accent
      enabled: root.cleaned !== ""
      opacity: enabled ? 1 : 0.38
      onClicked: root.commit()
    }
    Button {
      visible: !root.firstTime
      text: root.strings.nameCancel
      bordered: true
      foreground: root.foreground
      accent: root.accent
      onClicked: root.cancelled()
    }
  }

  Text {
    width: parent.width
    text: root.strings.nameHint + (root.firstTime ? " " + root.strings.nameLater : "")
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: Qt.darker(root.foreground, 1.4)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }
}
