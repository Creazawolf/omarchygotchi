// Marketing composition using actual plugin components and explicit demo characters.
import QtQuick
import QtQuick.Window
import Quickshell
import "plugin" as Pet

ShellRoot {
  Window {
    visible: true
    width: 1440; height: 810
    Rectangle {
      id: artwork
      width: 1440; height: 810
      color: "#192b2b"
      Rectangle { x: 76; y: 73; width: 36; height: 4; color: "#dfb475" }
      Text {
        x: 129; y: 57; text: "A COMPANION FOR OMARCHY"
        font.family: "DejaVu Sans"; font.pixelSize: 20; font.letterSpacing: 3
        color: "#c6d5bf"
      }
      Text {
        x: 72; y: 111; text: "Omarchygotchi"
        font.family: "DejaVu Sans"; font.pixelSize: 91; font.bold: true; font.letterSpacing: -4
        color: "#f2edda"
      }
      Text {
        x: 79; y: 281; width: 520; text: "A little companion.\nA life of its own."
        font.family: "DejaVu Sans"; font.pixelSize: 40; lineHeight: 1.15
        color: "#e3bc85"
      }
      Text {
        x: 81; y: 422; width: 460
        text: "Grow together.\nMeet the neighbours.\nKeep the little moments."
        font.family: "DejaVu Sans"; font.pixelSize: 26; lineHeight: 1.5
        color: "#cad4c4"
      }
      Pet.SharedScene {
        x: 626; y: 239; width: 738
        scene: ({participants: [{id: "demo-pixel", name: "Pixel", seed: 4, stage: "adult"}, {id: "demo-bean", name: "Bean", seed: 78, stage: "adult"}], scene: "radio"})
        caption: "Their station. Their terrible taste in music."
        eyebrow: "A MOMENT TOGETHER"
        animated: false
      }
      Text {
        x: 81; y: 697; text: "GENTLE CARE  ·  REAL FRIENDSHIPS"
        font.family: "DejaVu Sans"; font.pixelSize: 16; font.letterSpacing: 1.5
        color: "#aabda8"
      }
      Text {
        x: 82; y: 743; text: "CREAZAWOLF   /   3.0"
        font.family: "DejaVu Sans"; font.pixelSize: 13; font.letterSpacing: 2
        color: "#91a695"
      }
      Text {
        x: 1102; y: 743; text: "ACTUAL RENDERER · DEMO SCENE"
        font.family: "DejaVu Sans"; font.pixelSize: 10
        color: "#91a695"
      }
    }
  }
  Timer {
    interval: 1200; running: true
    onTriggered: artwork.grabToImage(function(result) {
      if (!result.saveToFile(Quickshell.env("TAMA_PREVIEW"))) throw new Error("Preview export failed")
      console.log("PREVIEW_SAVED")
      Qt.quit()
    }, Qt.size(1440,810))
  }
  Timer { interval: 8000; running: true; onTriggered: Qt.quit() }
}
