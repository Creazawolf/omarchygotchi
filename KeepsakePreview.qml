import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// ---------------------------------------------------------------------------
// Preview a keepsake, edit its caption, then save it as a PNG or copy it.
//
// Used for shared moments, family portraits and the solo portrait. Images go
// to ~/Pictures/Omarchygotchi, next to your screenshots, not into the private
// state directory where the community identity lives. Only the scene item is
// captured: never the desktop, the panel, or anything about the owner.
// ---------------------------------------------------------------------------
Column {
  id: root

  property var scene: null
  property var child: null
  property string label: "A MOMENT TOGETHER"
  property string fileStem: "moment"
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string status: ""
  readonly property bool editing: captionField.activeFocus
  readonly property string folder: Quickshell.env("HOME") + "/Pictures/Omarchygotchi"

  signal closed()

  spacing: Style.space(7)

  function show(caption) {
    captionField.text = caption
    status = ""
  }

  SharedScene {
    id: exportScene
    width: parent.width
    scene: root.scene
    child: root.child
    caption: captionField.text
    eyebrow: root.label
  }

  TextField {
    id: captionField
    width: parent.width
    maximumLength: 180
    foreground: root.foreground
    accent: root.accent
    Keys.onEscapePressed: function(event) { event.accepted = true; root.forceActiveFocus() }
  }

  Flow {
    width: parent.width
    spacing: Style.space(6)
    Button {
      text: "Save image"
      bordered: true; selected: true
      foreground: root.foreground; accent: root.accent
      enabled: !saver.running
      onClicked: root.save(false)
    }
    Button {
      text: "Copy image"
      bordered: true
      foreground: root.foreground; accent: root.accent
      enabled: !saver.running
      onClicked: root.save(true)
    }
    Button {
      text: "Close"
      bordered: true
      foreground: root.foreground; accent: root.accent
      onClicked: root.closed()
    }
  }

  Text {
    width: parent.width
    visible: text !== ""
    text: root.status
    textFormat: Text.PlainText
    wrapMode: Text.WrapAnywhere
    color: Qt.darker(root.foreground, 1.4)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  // mkdir, then capture, then (for Copy) hand the file to wl-copy. Every step
  // takes arguments, never a shell string, so a caption can't become a command.
  property string pendingPath: ""
  property bool pendingCopy: false

  function save(copy) {
    if (saver.running) return
    var stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd-HHmmss")
    pendingPath = folder + "/" + fileStem.replace(/[^A-Za-z0-9_-]/g, "") + "-" + stamp + ".png"
    pendingCopy = copy
    status = "Saving…"
    saver.command = ["mkdir", "-p", folder]
    saver.running = true
  }

  Process {
    id: saver
    onExited: function(code) {
      if (code !== 0) { root.status = "Could not create " + root.folder + "."; return }
      var path = root.pendingPath
      var captured = exportScene.grabToImage(function(result) {
        if (!result.saveToFile(path)) { root.status = "Could not save this image."; return }
        if (!root.pendingCopy) { root.status = "Saved: " + path; return }
        // The path is a positional argument ($1), not part of the script, so
        // nothing in it is ever interpreted by the shell.
        copier.command = ["sh", "-c", "exec wl-copy --type image/png < \"$1\"", "sh", path]
        copier.path = path
        copier.running = true
      }, Qt.size(1200, 750))
      if (!captured) root.status = "Could not capture this scene."
    }
  }

  // wl-copy copies its arguments as text, so the image has to arrive on
  // stdin; a tiny sh redirect is the only way Process can feed it a file.
  Process {
    id: copier
    property string path: ""
    onExited: function(code) {
      root.status = code === 0 ? "Copied, and saved: " + copier.path : "Saved, but could not copy: " + copier.path
    }
  }
}
