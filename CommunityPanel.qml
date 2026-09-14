import QtQuick
import qs.Commons
import qs.Ui
import "Sim.js" as Sim

Column {
  id: root
  property var social: null
  property bool active: false
  onActiveChanged: {
    if (social) { social.panelOpen = active; if (active && social.optedIn) social.call("sync", "") }
  }
  onSocialChanged: if (social && active) { social.panelOpen = true; if (social.optedIn) social.call("sync", "") }
  Component.onDestruction: if (social && active) social.panelOpen = false
  readonly property bool editing: address.activeFocus || stories.editing
  property color foreground: Color.foreground
  readonly property var communityData: social ? social.snapshot : ({friends: [], incoming: [], outgoing: [], blocked: [], visits: []})
  spacing: Style.space(10)
  signal revealRequested(real offset)
  function act(action, target) { if (social) social.call(action, target || "") }

  Text {
    width: parent.width
    text: "THE COMMUNITY PARK"
    color: root.foreground
    font.bold: true
    font.pixelSize: Style.font.body
  }
  Text {
    width: parent.width
    text: "Meet real creatures from other Omarchy desktops. Share playdates, make friends, and let your companion wander."
    wrapMode: Text.WordWrap
    color: root.foreground
    font.pixelSize: Style.font.caption
  }
  Rectangle {
    width: parent.width; height: Style.space(36)
    color: "transparent"; radius: Style.space(4)
    border.color: Color.accent
    TextInput {
      id: address
      anchors.fill: parent; anchors.margins: Style.space(8)
      text: root.social ? root.social.serverUrl : ""
      color: root.foreground
      font.pixelSize: Style.font.caption
      clip: true
      selectByMouse: true
      enabled: root.social && !root.social.optedIn && !root.social.busy && !root.social.disconnectRequested
      Text {
        visible: address.text.length === 0 && !address.activeFocus
        text: "https://your-community-server.example"
        color: root.foreground; opacity: 0.5
        font: address.font
      }
    }
  }
  Flow {
    width: parent.width; spacing: Style.space(6)
    Button {
      text: root.social && root.social.optedIn ? "Disconnect" : "Connect"
      bordered: true; foreground: root.foreground
      enabled: root.social && !root.social.busy && address.text.trim().length > 0
      onClicked: root.social.optedIn ? root.social.disconnect() : root.social.connectTo(address.text)
    }
    Button {
      text: "Find a playmate"; bordered: true; foreground: root.foreground
      enabled: root.social && root.social.optedIn && root.social.connected && root.social.available && !root.social.busy && !root.social.disconnectRequested
      onClicked: root.act("visit")
    }
    Button {
      text: root.social && root.social.roaming ? "Auto-roam: on" : "Auto-roam: off"
      bordered: true; foreground: root.foreground
      enabled: root.social && root.social.optedIn && !root.social.busy && !root.social.disconnectRequested
      onClicked: root.social.setRoaming(!root.social.roaming)
    }
    Button {
      text: root.social && root.social.offlineVisits ? "Offline adventures: on" : "Offline adventures: off"
      bordered: true; foreground: root.foreground
      enabled: root.social && root.social.optedIn && root.social.cloudRoaming && !root.social.busy && !root.social.disconnectRequested
      onClicked: root.social.setOfflineVisits(!root.social.offlineVisits)
    }
  }
  Text {
    width: parent.width
    visible: root.social && root.social.cloudRoaming
    text: "Auto-roam finds a playdate about every six hours when a partner is available. Offline adventures let your creature join while your computer is off, for up to seven days after your last connection."
    wrapMode: Text.WordWrap; color: root.foreground; opacity: 0.7
    font.pixelSize: Style.font.caption
  }
  Text {
    width: parent.width
    text: root.social ? root.social.status : "Starting community service…"
    textFormat: Text.PlainText; wrapMode: Text.WordWrap
    color: Color.accent; font.pixelSize: Style.font.caption
  }
  Text {
    width: parent.width
    text: "Connecting shares your creature’s name, appearance, stage and availability with this server. Friend requests are sent only when you choose. Desktop activity stays on your system."
    wrapMode: Text.WordWrap; color: root.foreground; opacity: 0.65
    font.pixelSize: Style.font.caption
  }
  StoryPanel {
    id: stories
    onPreviewRequested: function(offset) { root.revealRequested(stories.y + offset) }
    width: parent.width
    social: root.social
    active: root.active
    foreground: root.foreground
    visible: root.social && root.social.sharedHistory
  }
  Repeater {
    model: [
      {title: "FRIEND REQUESTS", key: "incoming", empty: "No requests yet.", action: "accept", label: "Accept"},
      {title: "FRIENDS", key: "friends", empty: "Meet someone in the park and send a request.", action: "visit", label: "Play"},
      {title: "SENT REQUESTS", key: "outgoing", empty: "No pending requests.", action: "remove", label: "Cancel"},
      {title: "BLOCKED", key: "blocked", empty: "", action: "unblock", label: "Unblock"}
    ]
    delegate: Column {
      id: section
      required property var modelData
      width: root.width; spacing: Style.space(5)
      Text { text: section.modelData.title; color: root.foreground; font.bold: true; font.pixelSize: Style.font.caption }
      Text {
        visible: (root.communityData[section.modelData.key] || []).length === 0
        width: parent.width; wrapMode: Text.WordWrap
        text: section.modelData.empty; color: root.foreground; opacity: 0.6; font.pixelSize: Style.font.caption
      }
      Repeater {
        model: root.communityData[section.modelData.key] || []
        delegate: Column {
          id: person
          required property var modelData
          width: section.width; spacing: Style.space(4)
          Text {
            width: parent.width; elide: Text.ElideRight
            text: person.modelData.name + (person.modelData.online ? " · online" : " · away")
            textFormat: Text.PlainText; color: root.foreground; font.pixelSize: Style.font.body
          }
          Flow {
            width: parent.width; spacing: Style.space(5)
            Button {
              text: section.modelData.label; bordered: true; foreground: root.foreground
              enabled: root.social && root.social.optedIn && !root.social.busy && !root.social.disconnectRequested
              onClicked: root.act(section.modelData.action, person.modelData.id)
            }
            Button {
              visible: section.modelData.key === "incoming" || section.modelData.key === "friends"
              text: section.modelData.key === "incoming" ? "Decline" : "Unfriend"
              bordered: true; foreground: root.foreground
              enabled: root.social && root.social.optedIn && !root.social.busy && !root.social.disconnectRequested
              onClicked: root.act(section.modelData.key === "incoming" ? "decline" : "remove", person.modelData.id)
            }
            Button {
              visible: section.modelData.key !== "blocked"
              text: "Block"; bordered: true; foreground: root.foreground
              enabled: root.social && root.social.optedIn && !root.social.busy && !root.social.disconnectRequested
              onClicked: root.act("block", person.modelData.id)
            }
          }
        }
      }
    }
  }
  Text { text: "MOMENTS · LAST 30 DAYS"; color: root.foreground; font.bold: true; font.pixelSize: Style.font.caption }
  Text {
    width: parent.width; wrapMode: Text.WordWrap
    visible: (root.communityData.visits || []).length === 0
    text: "The park may be quiet. When another real creature is available, your first shared story can begin."
    color: root.foreground; opacity: 0.6; font.pixelSize: Style.font.caption
  }
  Repeater {
    model: root.communityData.visits || []
    delegate: Column {
      id: visit
      required property var modelData
      width: root.width; spacing: Style.space(4)
      Text {
        width: parent.width; wrapMode: Text.WordWrap
        text: "You and " + visit.modelData.creature.name + " " + visit.modelData.activity + ".\n" + new Date(visit.modelData.at * 1000).toLocaleString(Qt.locale("en_US"), "MMM d, HH:mm")
        textFormat: Text.PlainText; color: root.foreground; font.pixelSize: Style.font.caption
      }
      Text {
        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
        text: visit.modelData.scene ? "Kept: " + visit.modelData.scene.keepsake + "." : ""
        color: Color.accent; font.pixelSize: Style.font.caption
      }
      Flow {
        width: parent.width; spacing: Style.space(5)
        Button {
          text: "Preview keepsake"; visible: !!visit.modelData.scene; bordered: true; foreground: root.foreground
          onClicked: stories.preview(visit.modelData)
        }
        Button {
          text: "Add friend"; bordered: true; foreground: root.foreground
          enabled: root.social && root.social.optedIn && !root.social.busy && !root.social.disconnectRequested
          onClicked: root.act("request", visit.modelData.creature.id)
        }
        Button {
          text: "Block"; bordered: true; foreground: root.foreground
          enabled: root.social && root.social.optedIn && !root.social.busy && !root.social.disconnectRequested
          onClicked: root.act("block", visit.modelData.creature.id)
        }
      }
    }
  }
  Button {
    property bool confirmed: false
    text: confirmed ? "Confirm profile deletion" : "Delete community profile"
    bordered: true; foreground: root.foreground
    enabled: root.social && root.social.optedIn && !root.social.busy && !root.social.disconnectRequested
    onClicked: { if (confirmed) { root.act("delete"); confirmed = false } else confirmed = true }
  }
}
