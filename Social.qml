import QtQuick
import Quickshell
import Quickshell.Io
import "Sim.js" as Sim
import "CommunityDefaults.js" as Defaults

Item {
  id: root
  property var service: null
  property string serverUrl: Defaults.serverUrl
  property bool optedIn: false
  property bool roaming: false
  property bool offlineVisits: false
  property bool disconnectRequested: false
  property bool panelOpen: false
  property string lastVisitId: ""
  readonly property bool cloudRoaming: !!snapshot.capabilities && snapshot.capabilities.serverRoaming === true
  readonly property bool sharedHistory: !!snapshot.capabilities && snapshot.capabilities.sharedHistory === true
  readonly property bool friendCodes: !!snapshot.capabilities && snapshot.capabilities.friendCodes === true
  // Aggregate counts only: how many other creatures synced this week, and how
  // many are in the park and free right now. Null on servers without presence.
  readonly property var park: snapshot.park || null

  // The readable friend code. The server keeps only its hash, so the code
  // lives here, beside the other connection preferences, until it expires or
  // is replaced.
  property string inviteCode: ""
  property real inviteExpires: 0
  property real clockNow: Date.now()
  readonly property var activeVisit: {
    if (!optedIn || disconnectRequested || !connected || !available) return null
    var visits = snapshot.visits || []
    for (var i = 0; i < visits.length; i++) if (visits[i].scene && visits[i].until * 1000 > clockNow) return visits[i]
    return null
  }
  readonly property var householdChild: {
    var families = snapshot.families || []
    for (var i = 0; i < families.length; i++) if (families[i].acceptedAt && families[i].home === snapshot.id && families[i].stage !== "adult") return families[i]
    return null
  }
  property string lastFamilyMilestone: ""
  property bool initialSyncAttempted: false
  property bool loaded: false
  property string status: "Connect to a community server to meet other creatures."
  property var snapshot: ({friends: [], incoming: [], outgoing: [], blocked: [], visits: []})
  readonly property bool busy: request.running
  property bool connected: false
  property string pendingAction: ""
  readonly property var pet: service ? service.pet : null
  readonly property bool available: pet && !pet.asleep && !pet.sick && !Sim.isDead(pet) && Sim.stage(pet, Date.now()) !== "egg" && pet.stats.energy >= 20

  FileView {
    id: preferences
    path: Quickshell.env("HOME") + "/.local/state/omarchy/tamagotchi-community-settings.json"
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try {
        var p = JSON.parse(text())
        root.serverUrl = String(p.serverUrl || Defaults.serverUrl)
        root.roaming = p.roaming === true
        root.offlineVisits = p.offlineVisits === true
        root.disconnectRequested = p.disconnectRequested === true
        root.lastVisitId = String(p.lastVisitId || "")
        root.lastFamilyMilestone = String(p.lastFamilyMilestone || "")
        root.inviteCode = String(p.inviteCode || "")
        root.inviteExpires = Number(p.inviteExpires) || 0
        root.optedIn = p.optedIn === true
      } catch(e) {}
      root.loaded = true
      if (root.optedIn) root.call("sync", "")
    }
    onLoadFailed: root.loaded = true
  }
  function save() {
    preferences.setText(JSON.stringify({serverUrl: serverUrl, optedIn: optedIn, roaming: roaming, offlineVisits: offlineVisits, disconnectRequested: disconnectRequested, lastVisitId: lastVisitId, lastFamilyMilestone: lastFamilyMilestone, inviteCode: inviteCode, inviteExpires: inviteExpires}))
  }
  function connectTo(url) {
    if (busy) return
    if (optedIn && serverUrl !== url.trim()) {
      status = "Disconnect before changing servers."
      return
    }
    if (serverUrl !== url.trim()) { lastVisitId = ""; lastFamilyMilestone = ""; inviteCode = ""; inviteExpires = 0; archive.setText("{}"); snapshot = {friends: [], incoming: [], outgoing: [], blocked: [], visits: []} }
    serverUrl = url.trim()
    optedIn = true
    disconnectRequested = false
    save()
    call("sync", "")
  }
  onPetChanged: if (loaded && optedIn && !initialSyncAttempted && !busy) call("sync", "")
  onAvailableChanged: if (loaded && optedIn && !busy) call("sync", "")
  function disconnect() {
    if (busy) return
    disconnectRequested = true
    save()
    call("offline", "")
  }
  function setOfflineVisits(value) { offlineVisits = value; save(); call("sync", "") }
  function setRoaming(value) { roaming = value; save(); call("sync", "") }

  function createInvite() { call("invite-create", "") }
  function revokeInvite() { call("invite-revoke", "") }
  function acceptInvite(code) { call("invite-accept", "", {code: String(code || "")}) }

  // Plain text to the Wayland clipboard. Arguments, never a shell string.
  Process { id: clipboard }
  function copyText(text) {
    if (clipboard.running) return
    clipboard.command = ["wl-copy", "--", String(text)]
    clipboard.running = true
  }

  // Friends, remembered between syncs, to notice a new one arriving (say, from
  // a friend code you shared). Null until the first sync, so start-up is quiet.
  property var knownFriends: null
  function call(action, target, extra) {
    if (busy || !pet || (!optedIn && action !== "offline")) return
    if (disconnectRequested && action !== "delete") action = "offline"
    if (action === "sync") initialSyncAttempted = true
    pendingAction = action
    var profile = {name: pet.name, seed: pet.seed, stage: Sim.stage(pet, Date.now()), discover: available, offlineVisits: offlineVisits, autoRoam: roaming, target: target || ""}
    if (extra) for (var key in extra) profile[key] = extra[key]
    request.command = ["python3", decodeURIComponent(Qt.resolvedUrl("community/client.py").toString().replace("file://", "")), serverUrl, action, JSON.stringify(profile)]
    status = action === "visit" ? "Looking for a playmate…" : action === "invite-accept" ? "Checking the code…" : "Connecting…"
    request.running = true
  }
  Process {
    id: request
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.error) {
            root.status = root.disconnectRequested ? "Disconnect not confirmed. Retrying; offline adventures may continue until confirmed." : String(data.error)
            if (root.pendingAction === "sync") root.connected = false
            return
          }
          if (root.pendingAction === "offline") {
            root.optedIn = false; root.connected = false; root.disconnectRequested = false; root.save()
            root.status = "Disconnected. Your creature stays at home."
            return
          }
          if (root.pendingAction === "delete") {
            root.optedIn = false; root.connected = false; root.disconnectRequested = false; root.lastVisitId = ""; root.lastFamilyMilestone = ""; root.inviteCode = ""; root.inviteExpires = 0; root.save()
            root.snapshot = {friends: [], incoming: [], outgoing: [], blocked: [], visits: []}
            archive.setText("{}")
            root.status = "Community profile deleted. Your local pet is safe."
            return
          }
          var visits = data.visits || []
          var newAdventure = visits.length > 0 && visits[0].id !== root.lastVisitId
          if (newAdventure) {
            if (root.service) root.service.reacted("community", "star", "metFriend", true)
            root.lastVisitId = visits[0].id
            root.save()
          }
          root.clockNow = Date.now()
          root.connected = root.optedIn
          // A code arrives readable only when it is created; afterwards the
          // snapshot says whether it is still the live one.
          if (data.invite && data.invite.code) {
            root.inviteCode = data.invite.code; root.inviteExpires = data.invite.expires; root.save()
          } else if (root.inviteCode !== "" && (!data.invite || data.invite.expires !== root.inviteExpires)) {
            root.inviteCode = ""; root.inviteExpires = 0; root.save()
          }
          var friendIds = (data.friends || []).map(function(p) { return p.id })
          if (root.knownFriends !== null && root.service && root.service.notificationsEnabled) {
            var fresh = (data.friends || []).filter(function(p) { return root.knownFriends.indexOf(p.id) < 0 })
            if (fresh.length > 0) {
              root.service.reacted("community", "heart", "", true)
              root.service.notify(fresh[0].name + " is your friend now", root.pet.name + " and " + fresh[0].name + " can visit each other from the park.", "✨", "low", ["omarchy-shell", "shell", "summon", "creaza.tamagotchi"], false)
            }
          }
          root.knownFriends = friendIds
          root.snapshot = data
          archive.setText(JSON.stringify(data))
          if (newAdventure && root.activeVisit && root.service && root.service.notificationsEnabled && !Sim.inQuietHours(new Date().getHours(), root.service.quietHours)) {
            var guest = root.activeVisit.creature.name
            root.service.notify(guest + " is here", root.pet.name + " has company. Open their habitat to see what happens.", "✨", "low", ["omarchy-shell", "shell", "summon", "creaza.tamagotchi"], false)
          }
          var families = data.families || []
          var milestone = families.filter(function(f) { return f.acceptedAt > 0 }).map(function(f) { return f.id + ":" + f.stage }).join(",")
          if (milestone !== root.lastFamilyMilestone) {
            if (milestone && root.service) root.service.reacted("family", "heart", "metFriend", true)
            root.lastFamilyMilestone = milestone
            root.save()
          }
          if (!root.optedIn) return
          root.status = data.message || (newAdventure ? "New adventures are waiting in your journal!" : "") || (root.available ? "At the park · ready to meet creatures" : "Resting at home · care for your creature before visiting")
        } catch(e) { root.status = "Could not read the community response."; root.connected = false }
      }
    }
  }
  FileView {
    id: archive
    path: Quickshell.env("HOME") + "/.local/state/omarchy/tamagotchi-community-history.json"
    atomicWrites: true
    printErrors: false
    onLoaded: { try { if (!root.connected) root.snapshot = JSON.parse(text()) } catch(e) {} }
  }
  Timer { interval: 15000; repeat: true; running: root.optedIn; onTriggered: root.clockNow = Date.now() }
  Timer {
    interval: root.disconnectRequested ? 30000 : (root.panelOpen || root.activeVisit ? 30000 : 300000); repeat: true
    running: root.loaded && root.optedIn
    onTriggered: root.call("sync", "")
  }
  Timer {
    interval: 330000 + Math.floor(Math.random() * 60000); repeat: true
    running: root.loaded && root.optedIn && root.roaming && root.available && root.connected && !root.cloudRoaming && !root.disconnectRequested
    onTriggered: root.call("visit", "")
  }
}
