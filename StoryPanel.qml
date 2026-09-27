import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: root
  property var social: null
  property bool active: false
  property color foreground: Color.foreground
  readonly property var history: social ? social.snapshot : ({})
  readonly property bool canAct: social && social.optedIn && social.connected && !social.busy && !social.disconnectRequested
  readonly property bool editing: captionInput.activeFocus || eggName.activeFocus
  property var selectedMoment: null
  property var selectedChild: null
  property var eggPartner: null
  property bool myHome: true
  property string exportStatus: ""
  spacing: Style.space(10)
  signal previewRequested(real offset)
  function preview(visit) {
    if (!visit.scene) return
    selectedChild = null; selectedMoment = visit
    captionInput.text = visit.scene.participants.map(function(p) { return p.name }).join(" & ") + " " + visit.activity + "."
    exportStatus = ""
    Qt.callLater(function() { root.previewRequested(previewColumn.y) })
  }
  function previewFamily(child) {
    selectedChild = child
    selectedMoment = {id: child.id, scene: {participants: child.parents, scene: "family"}}
    captionInput.text = child.name + " · " + child.milestone + "."
    exportStatus = ""
    Qt.callLater(function() { root.previewRequested(previewColumn.y) })
  }
  Text {
    width: parent.width; text: "WHO MATTERS"; color: root.foreground; font.bold: true; font.letterSpacing: 1; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
  }
  Text {
    width: parent.width; visible: !(root.history.bonds || []).length
    text: "A familiar face starts with a first visit. Meet a playmate in the park."
    wrapMode: Text.WordWrap; color: root.foreground; opacity: 0.7; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
  }
  Repeater {
    model: root.history.bonds || []
    delegate: Column {
      id: bond
      required property var modelData
      readonly property bool friends: (root.history.friends || []).some(function(p) { return p.id === bond.modelData.creature.id })
      width: root.width; spacing: Style.space(4)
      Text {
        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
        text: bond.modelData.creature.name + " · " + bond.modelData.level + " · " + bond.modelData.personality
        color: root.foreground; font.bold: true; font.family: Style.font.family; font.pixelSize: Style.font.body
      }
      Text {
        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
        text: bond.modelData.memory + "." + (bond.modelData.keepsake ? "\nKept: " + bond.modelData.keepsake + "." : "") + (bond.modelData.togetherAt ? "\nTogether since " + new Date(bond.modelData.togetherAt * 1000).toLocaleDateString(Qt.locale("en_US")) + "." : "")
        color: root.foreground; opacity: 0.75; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
      }
      Flow {
        width: parent.width; spacing: Style.space(5)
        Button {
          text: "Invite over"; bordered: true; foreground: root.foreground
          enabled: root.canAct && root.social.available
          onClicked: root.social.call("visit", bond.modelData.creature.id)
        }
        Button {
          text: bond.modelData.romanceAllowed ? "Keep as friends" : "Allow romance"
          visible: bond.friends && bond.modelData.encounters >= 3 && ["adult", "elder"].indexOf(bond.modelData.creature.stage) >= 0
          bordered: true; foreground: root.foreground; enabled: root.canAct
          onClicked: root.social.call("romance", bond.modelData.creature.id, {allow: !bond.modelData.romanceAllowed})
        }
        Button {
          text: "Plan a shared egg"; visible: bond.modelData.togetherAt > 0 && bond.modelData.encounters >= 6
          bordered: true; foreground: root.foreground; enabled: root.canAct
          onClicked: { root.eggPartner = bond.modelData.creature; root.myHome = true; eggName.text = "Pip" }
        }
      }
      Text {
        visible: bond.modelData.romanceAllowed && !bond.modelData.togetherAt
        width: parent.width; wrapMode: Text.WordWrap
        text: "Romance can emerge if both owners allow it. Your choice stays private until then."
        color: root.foreground; opacity: 0.65; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
      }
    }
  }
  Column {
    width: parent.width; spacing: Style.space(6); visible: root.eggPartner !== null
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: root.eggPartner ? "A shared egg with " + root.eggPartner.name + ". Both owners must agree to the name and primary home. It hatches after one day and grows up in two weeks, with no extra care meters. One growing child per household." : ""
      color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }
    Rectangle {
      width: parent.width; height: Style.space(36); color: "transparent"; border.color: Color.accent; radius: 4
      TextInput { id: eggName; anchors.fill: parent; anchors.margins: Style.space(8); maximumLength: 20; color: root.foreground; selectByMouse: true; font.family: Style.font.family; font.pixelSize: Style.font.body; clip: true }
    }
    Flow {
      width: parent.width; spacing: Style.space(5)
      Button { text: root.myHome ? "Primary home: my desktop" : "Primary home: their desktop"; bordered: true; foreground: root.foreground; onClicked: root.myHome = !root.myHome }
      Button {
        text: "Propose this egg"; bordered: true; foreground: root.foreground
        enabled: root.canAct && eggName.text.trim().length > 0
        onClicked: { root.social.call("egg-propose", root.eggPartner.id, {name: eggName.text.trim(), home: root.myHome ? root.history.id : root.eggPartner.id}); root.eggPartner = null }
      }
      Button { text: "Cancel"; bordered: true; foreground: root.foreground; onClicked: root.eggPartner = null }
    }
  }
  Text { text: "FAMILY ALBUM"; color: root.foreground; font.bold: true; font.letterSpacing: 1; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
  Text {
    width: parent.width; visible: !(root.history.families || []).length; wrapMode: Text.WordWrap
    text: "Shared history comes first. Adult sweethearts can plan one shared child after six visits. Friendships have their own rituals, gifts, and stories."
    color: root.foreground; opacity: 0.7; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
  }
  Repeater {
    model: root.history.families || []
    delegate: Column {
      id: family
      required property var modelData
      readonly property string homeName: modelData.parents.filter(function(p) { return p.id === family.modelData.home })[0].name
      width: root.width; spacing: Style.space(5)
      SharedScene {
        width: parent.width
        scene: ({participants: family.modelData.parents, scene: "family"})
        child: family.modelData
        caption: family.modelData.name + " · " + family.modelData.milestone
        eyebrow: family.modelData.acceptedAt ? "OUR FAMILY" : "EGG PROPOSAL · NOT YET AGREED"
      }
      Text {
        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
        text: "Primary home: " + family.homeName + "’s desktop · " + family.modelData.trait + ".\n" + family.modelData.parents.map(function(p) { return p.name }).join(" + ") + " → " + family.modelData.name
        color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
      }
      Flow {
        width: parent.width; spacing: Style.space(5)
        Button {
          visible: !family.modelData.acceptedAt && family.modelData.proposer !== root.history.id
          text: "Agree to egg & this home"; bordered: true; foreground: root.foreground; enabled: root.canAct
          onClicked: root.social.call("egg-accept", "", {family: family.modelData.id, home: family.modelData.home})
        }
        Button {
          visible: !family.modelData.acceptedAt
          text: "Close proposal"; bordered: true; foreground: root.foreground; enabled: root.canAct
          onClicked: root.social.call("egg-cancel", "", {family: family.modelData.id})
        }
        Button {
          visible: !!family.modelData.acceptedAt; text: "Preview keepsake"; bordered: true; foreground: root.foreground
          onClicked: root.previewFamily(family.modelData)
        }
        Button {
          visible: !!family.modelData.acceptedAt; text: "Visit family"; bordered: true; foreground: root.foreground
          enabled: root.canAct && root.social.available
          onClicked: root.social.call("visit", family.modelData.parents.filter(function(p) { return p.id !== root.history.id })[0].id)
        }
      }
    }
  }
  Column {
    id: previewColumn
    width: parent.width; spacing: Style.space(7); visible: root.selectedMoment !== null
    Text { text: "PREVIEW YOUR MOMENT"; color: root.foreground; font.bold: true; font.letterSpacing: 1; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
    SharedScene {
      id: exportScene
      width: parent.width
      scene: root.selectedMoment ? root.selectedMoment.scene : null
      child: root.selectedChild
      caption: captionInput.text
      eyebrow: root.selectedChild ? "OUR FAMILY" : "A MOMENT TOGETHER"
    }
    Rectangle {
      width: parent.width; height: Style.space(64); radius: 4; color: "transparent"; border.color: Color.accent
      TextEdit {
        id: captionInput
        anchors.fill: parent; anchors.margins: Style.space(8)
        color: root.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; wrapMode: TextEdit.Wrap
        textFormat: TextEdit.PlainText; selectByMouse: true; clip: true
        onTextChanged: if (text.length > 180) text = text.slice(0,180)
      }
    }
    Text { width: parent.width; wrapMode: Text.WordWrap; text: "Edit your caption, then save a PNG. Only this scene is exported. You choose whether and where to share it."; color: root.foreground; opacity: 0.7; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
    Flow {
      width: parent.width; spacing: Style.space(5)
      Button {
        text: "Save image"; bordered: true; foreground: root.foreground
        onClicked: {
          var path = Quickshell.env("HOME") + "/.local/state/omarchy/tamagotchi-community/moment-" + root.selectedMoment.id + "-" + Date.now() + ".png"
          root.exportStatus = "Saving…"
          if (!exportScene.grabToImage(function(result) { root.exportStatus = result.saveToFile(path) ? "Saved: " + path : "Could not save this image." }, Qt.size(1200,750))) root.exportStatus = "Could not capture this scene."
        }
      }
      Button { text: "Close preview"; bordered: true; foreground: root.foreground; onClicked: root.selectedMoment = null }
    }
    Text { width: parent.width; wrapMode: Text.WrapAnywhere; text: root.exportStatus; textFormat: Text.PlainText; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
  }
}
