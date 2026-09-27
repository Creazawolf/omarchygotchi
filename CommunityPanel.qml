import QtQuick
import qs.Commons
import qs.Ui
import "Sim.js" as Sim

// ---------------------------------------------------------------------------
// The park. A place first: the creatures that matter stand on the grass and
// one click opens your story with them. Below it, in order of how often you
// need them: moments, requests, bringing a friend, family, and, folded away,
// the park settings (server, roaming, blocked, deleting your profile).
//
// Every destructive or social action keeps the server's rules: requests need
// a meeting, romance needs two private choices, a friend code is consent.
// ---------------------------------------------------------------------------
Column {
  id: root
  property var social: null
  property bool active: false
  property color foreground: Color.foreground
  property color accent: Color.accent
  property var pet: null
  property string stageKey: "adult"
  property string moodKey: "happy"
  property color meTint: Color.accent
  property color skyTop: Qt.lighter(Color.popups.background, 1.12)
  property color skyBottom: Qt.lighter(Color.popups.background, 1.26)
  property bool calm: false

  onActiveChanged: {
    if (social) { social.panelOpen = active; if (active && social.optedIn) social.call("sync", "") }
  }
  onSocialChanged: if (social && active) { social.panelOpen = true; if (social.optedIn) social.call("sync", "") }
  Component.onDestruction: if (social && active) social.panelOpen = false

  readonly property bool editing: address.activeFocus || codeField.activeFocus || stories.editing
  signal revealRequested(real offset)
  spacing: Style.space(12)

  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property var snap: social ? social.snapshot : ({})
  readonly property bool joined: social ? social.optedIn === true : false
  readonly property bool canAct: !!social && social.optedIn === true && social.connected === true && !social.busy && !social.disconnectRequested
  readonly property bool ready: canAct && social.available === true

  // Who stands in the park: friends first, then creatures met along the way.
  // Bonds carry the shared history; a friend made by code may have none yet.
  readonly property var people: {
    var friends = snap.friends || [], bonds = snap.bonds || []
    var friendIds = friends.map(function(p) { return p.id })
    var first = [], later = [], seen = {}
    for (var i = 0; i < bonds.length; i++) {
      var b = bonds[i], isFriend = friendIds.indexOf(b.creature.id) >= 0
      seen[b.creature.id] = true
      ;(isFriend ? first : later).push({creature: b.creature, bond: b, friend: isFriend})
    }
    for (var j = 0; j < friends.length; j++)
      if (!seen[friends[j].id]) first.push({creature: friends[j], bond: null, friend: true})
    return first.concat(later)
  }

  property string selectedId: ""
  readonly property var selected: {
    for (var i = 0; i < people.length; i++) if (people[i].creature.id === selectedId) return people[i]
    return null
  }
  onPeopleChanged: if (selectedId !== "" && selected === null) selectedId = ""
  onSelectedIdChanged: { moreOpen = false; confirmBlock = false }

  property bool moreOpen: false
  property bool confirmBlock: false
  property bool settingsOpen: false
  property bool confirmDelete: false

  readonly property var moments: {
    var all = snap.visits || []
    if (!selected) return all
    return all.filter(function(v) { return v.creature.id === root.selectedId })
  }

  function plural(n, one, many) { return n + " " + (n === 1 ? one : many) }
  function when(seconds) { return new Date(seconds * 1000).toLocaleString(Qt.locale("en_US"), "MMM d, HH:mm") }
  function day(seconds) { return new Date(seconds * 1000).toLocaleDateString(Qt.locale("en_US"), "MMM d") }
  function isOutgoing(id) { return (snap.outgoing || []).some(function(p) { return p.id === id }) }

  // ---------------------------------------------------------- the park
  ParkScene {
    width: parent.width
    me: root.pet ? ({ name: root.pet.name, seed: root.pet.seed, stage: root.stageKey,
                      mood: root.moodKey === "asleep" ? "asleep" : "happy" }) : null
    meTint: root.meTint
    others: root.joined ? root.people : []
    selectedId: root.selectedId
    skyTop: root.skyTop
    skyBottom: root.skyBottom
    foreground: root.foreground
    animated: root.active && visible
    calm: root.calm
    emptyText: root.joined ? "The park is quiet right now." : ""
    onPicked: function(id) { root.selectedId = id }
  }

  // Honest numbers, and the community's own status in its own words.
  Column {
    width: parent.width
    spacing: Style.space(2)
    visible: root.joined
    Text {
      width: parent.width
      visible: !!(root.social && root.social.park)
      text: root.social && root.social.park
            ? root.plural(root.social.park.week, "creature", "creatures") + " in the park this week · " + root.social.park.now + " here now"
            : ""
      textFormat: Text.PlainText; wrapMode: Text.WordWrap
      color: root.dim
      font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }
    Text {
      width: parent.width
      text: root.social && root.social.status ? String(root.social.status) : ""
      textFormat: Text.PlainText; wrapMode: Text.WordWrap
      color: root.foreground; opacity: 0.85
      font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }
  }

  // ---------------------------------------------------- not joined yet
  Column {
    visible: !root.joined
    width: parent.width
    spacing: Style.space(6)
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: "Meet creatures from other Omarchy desktops."
      color: root.foreground
      font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
    }
    // The consent comes before the button, not after it.
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: "Joining shares your creature's name, look, life stage and whether it is free to play. What you do on your desktop stays on it."
      color: root.dim; lineHeight: 1.15
      font.family: Style.font.family; font.pixelSize: Style.font.body
    }
    Flow {
      width: parent.width; spacing: Style.space(6); topPadding: Style.space(4)
      Button {
        text: "Join the park"
        bordered: true; selected: true; foreground: root.foreground; accent: root.accent
        enabled: !!root.social && !root.social.busy && address.text.trim().length > 0
        opacity: enabled ? 1 : 0.38
        onClicked: root.social.connectTo(address.text)
      }
    }
    Text {
      width: parent.width
      visible: text !== "" && root.social && root.social.status !== "Connect to a community server to meet other creatures."
      text: root.social && root.social.status ? String(root.social.status) : ""
      textFormat: Text.PlainText; wrapMode: Text.WordWrap
      color: root.foreground; opacity: 0.85
      font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }
  }

  // ------------------------------------------ nobody picked: go and play
  Flow {
    visible: root.joined && root.selected === null
    width: parent.width; spacing: Style.space(6)
    Button {
      text: "Find a playmate"
      bordered: true; selected: true; foreground: root.foreground; accent: root.accent
      enabled: root.ready
      opacity: enabled ? 1 : 0.38
      onClicked: root.social.call("visit", "")
    }
  }

  // --------------------------------------------------- a creature's card
  Column {
    visible: root.joined && root.selected !== null
    width: parent.width
    spacing: Style.space(6)
    readonly property var who: root.selected ? root.selected.creature : null
    readonly property var bond: root.selected ? root.selected.bond : null
    readonly property bool friend: root.selected ? root.selected.friend : false
    id: card

    Text {
      width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
      text: card.who ? card.who.name : ""
      color: root.foreground
      font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
    }
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: card.who ? [card.bond ? card.bond.level : (card.friend ? "friend" : ""),
                        card.bond ? card.bond.personality : Sim.personality(card.who),
                        card.who.online ? "here now" : "napping"].filter(function(s) { return s !== "" }).join(" · ") : ""
      color: root.dim
      font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      lineHeight: 1.15
      text: !card.who ? "" : card.bond
        ? card.bond.memory + "." + (card.bond.keepsake ? "\nKept: " + card.bond.keepsake + "." : "")
          + (card.bond.togetherAt ? "\nTogether since " + root.day(card.bond.togetherAt) + "." : "")
        : "Friends already. Invite them over for your first story together."
      color: root.foreground
      font.family: Style.font.family; font.pixelSize: Style.font.body
    }
    Flow {
      width: parent.width; spacing: Style.space(6); topPadding: Style.space(2)
      Button {
        visible: card.friend
        text: "Invite over"
        bordered: true; selected: true; foreground: root.foreground; accent: root.accent
        enabled: root.ready
        opacity: enabled ? 1 : 0.38
        onClicked: root.social.call("visit", card.who.id)
      }
      Button {
        visible: !card.friend && card.who !== null && !root.isOutgoing(card.who.id)
        text: "Add friend"
        bordered: true; selected: true; foreground: root.foreground; accent: root.accent
        enabled: root.canAct
        onClicked: root.social.call("request", card.who.id)
      }
      Button {
        visible: card.friend && !!card.bond && card.bond.encounters >= 3 && ["adult", "elder"].indexOf(card.who.stage) >= 0
        text: card.bond && card.bond.romanceAllowed ? "Keep as friends" : "Allow romance"
        bordered: true; foreground: root.foreground; accent: root.accent
        enabled: root.canAct
        onClicked: root.social.call("romance", card.who.id, {allow: !card.bond.romanceAllowed})
      }
      Button {
        visible: !!card.bond && card.bond.togetherAt > 0 && card.bond.encounters >= 6
        text: "Plan a shared egg"
        bordered: true; foreground: root.foreground; accent: root.accent
        enabled: root.canAct
        onClicked: stories.beginEgg(card.who)
      }
      Button {
        text: root.moreOpen ? "Less" : "More…"
        bordered: true; foreground: root.foreground; accent: root.accent
        onClicked: { root.moreOpen = !root.moreOpen; root.confirmBlock = false }
      }
    }
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      visible: !!card.bond && card.bond.romanceAllowed && !card.bond.togetherAt
      text: "Romance can bloom if both owners allow it. Your choice stays private until then."
      color: root.dim
      font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      visible: card.who !== null && !card.friend && root.isOutgoing(card.who.id)
      text: "Friend request sent. Their owner decides."
      color: root.dim
      font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }

    // Rare, consequential actions, one step further away.
    Flow {
      visible: root.moreOpen && !root.confirmBlock
      width: parent.width; spacing: Style.space(6)
      Button {
        visible: card.friend
        text: "Unfriend"
        bordered: true; foreground: root.foreground; accent: root.accent
        enabled: root.canAct
        onClicked: { root.social.call("remove", card.who.id); root.moreOpen = false }
      }
      Button {
        text: "Block"
        bordered: true; foreground: root.foreground; accent: root.accent
        enabled: root.canAct
        onClicked: root.confirmBlock = true
      }
    }
    Column {
      visible: root.moreOpen && root.confirmBlock
      width: parent.width; spacing: Style.space(6)
      Text {
        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
        text: card.who ? "Block " + card.who.name + "? Your creatures won't meet again, and any courtship or unagreed egg ends. You can unblock later in Park settings." : ""
        color: root.foreground
        font.family: Style.font.family; font.pixelSize: Style.font.body
      }
      Flow {
        width: parent.width; spacing: Style.space(6)
        Button {
          text: card.who ? "Block " + card.who.name : "Block"
          bordered: true; foreground: root.foreground; accent: root.accent
          enabled: root.canAct
          onClicked: { root.social.call("block", card.who.id); root.selectedId = "" }
        }
        Button {
          text: "Cancel"
          bordered: true; foreground: root.foreground; accent: root.accent
          onClicked: root.confirmBlock = false
        }
      }
    }
  }

  // ------------------------------------------------------------ moments
  Column {
    visible: root.joined
    width: parent.width
    spacing: Style.space(6)
    Text {
      text: root.selected ? "Moments with " + root.selected.creature.name : "Moments"
      textFormat: Text.PlainText
      color: root.foreground
      font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
    }
    Text {
      visible: root.moments.length === 0
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: root.selected ? "No shared moments in the last 30 days." : "Your first shared story will appear here."
      color: root.dim
      font.family: Style.font.family; font.pixelSize: Style.font.body
    }
    // A strip of the last 30 days, newest first. Each is the recorded scene
    // itself, small; clicking one opens it to caption and keep.
    Flickable {
      visible: root.moments.length > 0
      width: parent.width
      height: strip.height
      contentWidth: strip.width
      flickableDirection: Flickable.HorizontalFlick
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      Row {
        id: strip
        spacing: Style.space(8)
        Repeater {
          model: root.moments
          delegate: Column {
            id: moment
            required property var modelData
            spacing: Style.space(3)
            width: Style.space(150)
            SharedScene {
              width: parent.width
              compact: true
              scene: moment.modelData.scene
              visible: !!moment.modelData.scene
            }
            Text {
              width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
              text: (root.selected ? "" : moment.modelData.creature.name + " · ") + root.when(moment.modelData.at)
              color: root.dim
              font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
            }
            TapHandler { onTapped: stories.preview(moment.modelData) }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
          }
        }
      }
    }
  }

  // ---------------------------------------------------- friend requests
  Column {
    visible: root.joined && (root.snap.incoming || []).length > 0
    width: parent.width
    spacing: Style.space(6)
    Text {
      text: "Friend requests"
      color: root.foreground
      font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
    }
    Repeater {
      model: root.snap.incoming || []
      delegate: Column {
        id: request
        required property var modelData
        width: root.width; spacing: Style.space(4)
        Text {
          width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
          text: request.modelData.name + " would like to be friends."
          color: root.foreground
          font.family: Style.font.family; font.pixelSize: Style.font.body
        }
        Flow {
          width: parent.width; spacing: Style.space(6)
          Button {
            text: "Accept"
            bordered: true; selected: true; foreground: root.foreground; accent: root.accent
            enabled: root.canAct
            onClicked: root.social.call("accept", request.modelData.id)
          }
          Button {
            text: "Decline"
            bordered: true; foreground: root.foreground; accent: root.accent
            enabled: root.canAct
            onClicked: root.social.call("decline", request.modelData.id)
          }
        }
      }
    }
  }

  // ----------------------------------------------------- bring a friend
  Column {
    visible: root.joined && !!root.social && root.social.friendCodes === true
    width: parent.width
    spacing: Style.space(6)
    readonly property bool hasCode: !!root.social && !!root.social.inviteCode
    id: bring

    Text {
      text: "Bring a friend"
      color: root.foreground
      font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true
    }
    Text {
      visible: bring.hasCode
      text: root.social && root.social.inviteCode ? String(root.social.inviteCode) : ""
      textFormat: Text.PlainText
      color: root.foreground
      font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true; font.letterSpacing: 2
    }
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: bring.hasCode
        ? "Whoever enters this code becomes your friend. It works until " + root.day(root.social.inviteExpires) + ", or until you make a new one."
        : "Share a code in any chat. Whoever enters it becomes your friend straight away, even if you're away."
      color: root.dim; lineHeight: 1.15
      font.family: Style.font.family; font.pixelSize: Style.font.body
    }
    Flow {
      width: parent.width; spacing: Style.space(6)
      Button {
        visible: bring.hasCode
        text: "Copy"
        bordered: true; selected: true; foreground: root.foreground; accent: root.accent
        onClicked: root.social.copyText(root.social.inviteCode)
      }
      Button {
        text: bring.hasCode ? "New code" : "Create a friend code"
        bordered: true; selected: !bring.hasCode; foreground: root.foreground; accent: root.accent
        enabled: root.canAct
        opacity: enabled ? 1 : 0.38
        onClicked: root.social.createInvite()
      }
      Button {
        visible: bring.hasCode
        text: "Turn off"
        bordered: true; foreground: root.foreground; accent: root.accent
        enabled: root.canAct
        onClicked: root.social.revokeInvite()
      }
    }
    Row {
      width: parent.width
      spacing: Style.space(6)
      topPadding: Style.space(4)
      TextField {
        id: codeField
        width: parent.width - addByCode.width - parent.spacing
        maximumLength: 12
        placeholderText: "A friend's code"
        foreground: root.foreground
        accent: root.accent
        onAccepted: if (addByCode.enabled) addByCode.clicked()
      }
      Button {
        id: addByCode
        anchors.verticalCenter: codeField.verticalCenter
        text: "Add friend"
        bordered: true; foreground: root.foreground; accent: root.accent
        enabled: root.canAct && codeField.text.replace(/[\s-]/g, "").length === 8
        opacity: enabled ? 1 : 0.38
        onClicked: { root.social.acceptInvite(codeField.text); codeField.text = "" }
      }
    }
  }

  // ----------------------------------------------------------- families
  StoryPanel {
    id: stories
    width: parent.width
    visible: root.joined && !!root.social && root.social.sharedHistory === true
    social: root.social
    active: root.active
    foreground: root.foreground
    accent: root.accent
    onPreviewRequested: function(offset) { root.revealRequested(stories.y + offset) }
  }

  // ------------------------------------------------------ park settings
  Button {
    text: root.settingsOpen ? "Hide park settings" : "Park settings"
    bordered: true; foreground: root.foreground; accent: root.accent
    onClicked: { root.settingsOpen = !root.settingsOpen; root.confirmDelete = false; if (root.settingsOpen) root.revealRequested(y) }
  }

  Column {
    visible: root.settingsOpen
    width: parent.width
    spacing: Style.space(8)

    Text {
      text: "Community server"
      color: root.dim
      font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }
    TextField {
      id: address
      width: parent.width
      text: root.social && root.social.serverUrl ? String(root.social.serverUrl) : ""
      placeholderText: "https://your-community-server.example"
      enabled: !!root.social && root.social.optedIn !== true && !root.social.busy && !root.social.disconnectRequested
      foreground: root.foreground
      accent: root.accent
      font.pixelSize: Style.font.bodySmall
    }
    Flow {
      width: parent.width; spacing: Style.space(6)
      Button {
        visible: root.joined
        text: "Leave the park"
        bordered: true; foreground: root.foreground; accent: root.accent
        enabled: !!root.social && !root.social.busy
        onClicked: root.social.disconnect()
      }
      Button {
        visible: root.joined
        text: root.social && root.social.roaming ? "Auto-roam: on" : "Auto-roam: off"
        bordered: true; foreground: root.foreground; accent: root.accent
        enabled: !!root.social && !root.social.busy && !root.social.disconnectRequested
        onClicked: root.social.setRoaming(!root.social.roaming)
      }
      Button {
        visible: root.joined && !!root.social && root.social.cloudRoaming === true
        text: root.social && root.social.offlineVisits ? "Offline adventures: on" : "Offline adventures: off"
        bordered: true; foreground: root.foreground; accent: root.accent
        enabled: !!root.social && !root.social.busy && !root.social.disconnectRequested
        onClicked: root.social.setOfflineVisits(!root.social.offlineVisits)
      }
    }
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      visible: root.joined
      text: "Auto-roam finds a playdate about every six hours when a partner is free. Offline adventures let your creature join in while your computer is off, for up to seven days after you were last connected."
      color: root.dim
      font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }

    Repeater {
      model: root.joined ? (root.snap.outgoing || []) : []
      delegate: Row {
        id: sent
        required property var modelData
        spacing: Style.space(8)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: sent.modelData.name + " · request sent"
          textFormat: Text.PlainText
          color: root.foreground
          font.family: Style.font.family; font.pixelSize: Style.font.body
        }
        Button {
          text: "Cancel"
          bordered: true; foreground: root.foreground; accent: root.accent
          enabled: root.canAct
          onClicked: root.social.call("remove", sent.modelData.id)
        }
      }
    }
    Repeater {
      model: root.joined ? (root.snap.blocked || []) : []
      delegate: Row {
        id: blockedRow
        required property var modelData
        spacing: Style.space(8)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: blockedRow.modelData.name + " · blocked"
          textFormat: Text.PlainText
          color: root.foreground
          font.family: Style.font.family; font.pixelSize: Style.font.body
        }
        Button {
          text: "Unblock"
          bordered: true; foreground: root.foreground; accent: root.accent
          enabled: root.canAct
          onClicked: root.social.call("unblock", blockedRow.modelData.id)
        }
      }
    }

    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: "The server sees your creature's name, look, stage and availability, and the social actions you take. Your desktop activity never leaves this computer."
      color: root.dim
      font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }
    Button {
      visible: root.joined
      text: root.confirmDelete ? "Delete my community profile" : "Delete community profile…"
      bordered: true; foreground: root.foreground; accent: root.accent
      enabled: root.canAct
      onClicked: { if (root.confirmDelete) { root.social.call("delete", ""); root.confirmDelete = false } else root.confirmDelete = true }
    }
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      visible: root.confirmDelete
      text: "This removes your creature from the park, its friendships and journal. Agreed family portraits stay in the other parent's album. Your creature at home is not affected."
      color: root.foreground
      font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
    }
  }
}
