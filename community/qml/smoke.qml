import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "plugin" as Pet
ShellRoot {
  id: root
  property var snapshot: ({})
  FileView { path: Quickshell.env("TAMA_FIXTURE"); onLoaded: root.snapshot = JSON.parse(text()) }
  Pet.Service { id: actualService; config: ({notifications: false, awareness: false}) }
  Pet.Social {
    id: actualSocial
    service: QtObject {
      property var pet: ({name: "TestPixel", seed: 4, bornAt: Date.now()-200*3600000, asleep: false, sick: false, stats: {energy: 90}})
    }
  }
  QtObject {
    id: social
    property var snapshot: root.snapshot
    property bool optedIn: false
    property bool connected: false
    property bool busy: false
    property bool disconnectRequested: false
    property bool sharedHistory: true
    property bool cloudRoaming: true
    property bool roaming: false
    property bool offlineVisits: false
    property bool available: true
    property bool panelOpen: false
    property string status: "Isolated test fixture"
    property string serverUrl: "http://127.0.0.1:8787"
    property bool friendCodes: true
    property var park: ({week: 2, now: 1})
    property string inviteCode: ""
    property real inviteExpires: 0
    function call() {}
    function connectTo() {}
    function disconnect() {}
    function setRoaming() {}
    function setOfflineVisits() {}
    function createInvite() {}
    function revokeInvite() {}
    function acceptInvite() {}
    function copyText() {}
  }
  Window {
    visible: true; width: 820; height: 980; color: "#1c232d"
    Pet.SharedScene {
      id: scene
      width: 640; x: 80; y: 10
      scene: root.snapshot.visits ? root.snapshot.visits[0].scene : null
      caption: root.snapshot.visits ? root.snapshot.visits[0].activity : ""
      animated: false
    }
    Flickable {
      x: 20; y: 420; width: 780; height: 550; clip: true; contentHeight: community.height
      Pet.CommunityPanel { id: community; width: parent.width; social: social; active: true }
    }
    Pet.BarWidget { id: barWidget; visible: false }
  }
  Timer {
    interval: 2500; running: true
    onTriggered: {
      actualSocial.loaded = false
      actualSocial.snapshot = root.snapshot
      actualSocial.optedIn = true
      actualSocial.connected = true
      actualSocial.clockNow = root.snapshot.visits[0].at * 1000 + 1000
      if (!actualSocial.activeVisit) throw new Error("Expected a visible real visitor")
      actualSocial.clockNow = root.snapshot.visits[0].until * 1000 + 1
      if (actualSocial.activeVisit) throw new Error("Expired visitor remained visible")
      actualSocial.clockNow = root.snapshot.visits[0].at * 1000 + 1000
      actualSocial.disconnectRequested = true
      if (actualSocial.activeVisit) throw new Error("Visitor remained during disconnect")
      console.log("VISITOR_LIFECYCLE_OK")
      scene.grabToImage(function(result) {
        console.log("EXPORT_SAVED",result.saveToFile(Quickshell.env("TAMA_OUTPUT") + "/visit.png"))
        scene.child = root.snapshot.families[0]
        scene.scene = {participants: root.snapshot.families[0].parents, scene: "family"}
        scene.caption = root.snapshot.families[0].name + " · " + root.snapshot.families[0].milestone
        next.start()
      },Qt.size(1200,750))
    }
  }
  Timer { id: next; interval: 300; onTriggered: scene.grabToImage(function(result) { console.log("FAMILY_SAVED",result.saveToFile(Quickshell.env("TAMA_OUTPUT") + "/family.png")); Qt.quit() },Qt.size(1200,750)) }
  Timer { interval: 8000; running: true; onTriggered: Qt.quit() }
}
