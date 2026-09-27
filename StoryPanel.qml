import QtQuick
import qs.Commons
import qs.Ui

// ---------------------------------------------------------------------------
// What friendships grow into: the family album, a sweethearts' egg proposal,
// and the preview where a moment becomes an image. The friendships themselves
// live in the park (CommunityPanel).
// ---------------------------------------------------------------------------
Column {
  id: root
  property var social: null
  property bool active: false
  property color foreground: Color.foreground
  property color accent: Color.accent
  readonly property var history: social ? social.snapshot : ({})
  readonly property var families: history.families || []
  readonly property bool canAct: !!social && social.optedIn === true && social.connected === true && !social.busy && !social.disconnectRequested
  readonly property bool editing: eggName.activeFocus || keepsake.editing
  readonly property color dim: Qt.darker(foreground, 1.4)

  property var eggPartner: null
  property bool myHome: true
  property var previewScene: null
  property var previewChild: null
  property string previewLabel: "A MOMENT TOGETHER"

  spacing: Style.space(10)
  signal previewRequested(real offset)

  function preview(visit) {
    if (!visit || !visit.scene) return
    previewChild = null
    previewLabel = "A MOMENT TOGETHER"
    previewScene = visit.scene
    keepsake.fileStem = "moment"
    keepsake.show(visit.scene.participants.map(function(p) { return p.name }).join(" & ") + " " + visit.activity + ".")
    Qt.callLater(function() { root.previewRequested(keepsake.y) })
  }

  function previewFamily(child) {
    previewChild = child
    previewLabel = "OUR FAMILY"
    previewScene = {participants: child.parents, scene: "family"}
    keepsake.fileStem = "family"
    keepsake.show(child.name + " · " + child.milestone + ".")
    Qt.callLater(function() { root.previewRequested(keepsake.y) })
  }

  function beginEgg(partner) {
    eggPartner = partner
    myHome = true
    eggName.text = "Pip"
    Qt.callLater(function() { root.previewRequested(eggProposal.y) })
  }

  // ---- a sweethearts' egg
  Column {
    id: eggProposal
    width: parent.width
    spacing: Style.space(6)
    visible: root.eggPartner !== null

    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: root.eggPartner ? "A shared egg with " + root.eggPartner.name : ""
      color: root.foreground
      font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
    }
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: "Both owners agree to its name and its home. It hatches after a day and grows up in two weeks, with no care meters of its own. One growing child per household."
      color: root.dim
      font.family: Style.font.family; font.pixelSize: Style.font.body
    }
    TextField {
      id: eggName
      width: parent.width
      maximumLength: 20
      foreground: root.foreground
      accent: root.accent
    }
    Flow {
      width: parent.width; spacing: Style.space(6)
      Button {
        text: root.myHome ? "Home: my desktop" : "Home: their desktop"
        bordered: true; foreground: root.foreground; accent: root.accent
        onClicked: root.myHome = !root.myHome
      }
      Button {
        text: "Propose this egg"
        bordered: true; selected: true; foreground: root.foreground; accent: root.accent
        enabled: root.canAct && eggName.text.trim().length > 0
        opacity: enabled ? 1 : 0.38
        onClicked: {
          root.social.call("egg-propose", root.eggPartner.id, {name: eggName.text.trim(), home: root.myHome ? root.history.id : root.eggPartner.id})
          root.eggPartner = null
        }
      }
      Button {
        text: "Cancel"
        bordered: true; foreground: root.foreground; accent: root.accent
        onClicked: root.eggPartner = null
      }
    }
  }

  // ---- the family album
  Text {
    visible: root.families.length > 0
    text: "Family"
    color: root.foreground
    font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
  }
  Repeater {
    model: root.families
    delegate: Column {
      id: family
      required property var modelData
      readonly property string homeName: modelData.parents.filter(function(p) { return p.id === family.modelData.home })[0].name
      readonly property bool agreed: !!modelData.acceptedAt
      width: root.width; spacing: Style.space(6)
      SharedScene {
        width: parent.width
        scene: ({participants: family.modelData.parents, scene: "family"})
        child: family.modelData
        caption: family.modelData.name + " · " + family.modelData.milestone
        eyebrow: family.agreed ? "OUR FAMILY" : "EGG PROPOSAL · NOT YET AGREED"
      }
      Text {
        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
        text: family.modelData.parents.map(function(p) { return p.name }).join(" + ") + " → " + family.modelData.name
              + "\nHome: " + family.homeName + "’s desktop · " + family.modelData.trait
        color: root.dim
        font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
      }
      Flow {
        width: parent.width; spacing: Style.space(5)
        Button {
          visible: !family.agreed && family.modelData.proposer !== root.history.id
          text: "Agree to egg & home"
          bordered: true; selected: true; foreground: root.foreground; accent: root.accent
          enabled: root.canAct
          onClicked: root.social.call("egg-accept", "", {family: family.modelData.id, home: family.modelData.home})
        }
        Button {
          visible: !family.agreed
          text: "Close proposal"
          bordered: true; foreground: root.foreground; accent: root.accent
          enabled: root.canAct
          onClicked: root.social.call("egg-cancel", "", {family: family.modelData.id})
        }
        Button {
          visible: family.agreed
          text: "Visit family"
          bordered: true; selected: true; foreground: root.foreground; accent: root.accent
          enabled: root.canAct && root.social.available
          onClicked: root.social.call("visit", family.modelData.parents.filter(function(p) { return p.id !== root.history.id })[0].id)
        }
        Button {
          visible: family.agreed
          text: "Keepsake"
          bordered: true; foreground: root.foreground; accent: root.accent
          onClicked: root.previewFamily(family.modelData)
        }
      }
    }
  }

  // ---- a moment, as an image
  KeepsakePreview {
    id: keepsake
    width: parent.width
    visible: root.previewScene !== null
    scene: root.previewScene
    child: root.previewChild
    label: root.previewLabel
    foreground: root.foreground
    accent: root.accent
    onClosed: root.previewScene = null
  }
}
