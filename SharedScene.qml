import QtQuick
import "Sim.js" as Sim

// Only supplied, recorded participants are rendered. This item can be exported
// by itself: no window, desktop, server address or owner identity is captured.
Item {
  id: root
  property var scene: null
  property var child: null
  property string caption: ""
  property string eyebrow: "A MOMENT TOGETHER"
  property bool animated: false
  readonly property var people: scene ? scene.participants || [] : []
  implicitHeight: width * 0.625
  height: implicitHeight
  clip: true
  Item {
    width: 640; height: 400
    scale: root.width / 640
    transformOrigin: Item.TopLeft
    Rectangle {
      anchors.fill: parent; radius: 18
      gradient: Gradient {
        GradientStop { position: 0; color: "#202c3c" }
        GradientStop { position: 1; color: "#46645d" }
      }
    }
    Repeater {
      model: 15
      Rectangle {
        required property int index
        x: 20 + (index * 137) % 600; y: 35 + (index * 41) % 145
        width: index % 3 === 0 ? 3 : 2; height: width; radius: width
        color: "#e6dca6"; opacity: 0.5
      }
    }
    Rectangle { x: -50; y: 275; width: 740; height: 230; radius: 210; color: "#344c42" }
    Text { x: 26; y: 24; text: root.eyebrow; color: "#c8d8bd"; font.pixelSize: 13; font.letterSpacing: 2; textFormat: Text.PlainText }
    Repeater {
      model: root.people
      delegate: Item {
        required property var modelData
        required property int index
        x: index === 0 ? 90 : 360; y: 78
        width: 190; height: 220
        Creature {
          width: 190; height: 190; size: 190
          seed: parent.modelData.seed; stageKey: parent.modelData.stage
          bodyScale: Sim.stageScale(stageKey)
          mood: "happy"; happiness: 90; animated: root.animated; detail: true
          tint: Qt.hsla(Sim.seededUnit(seed, 11), 0.52, 0.62, 1)
          music: root.scene && root.scene.scene === "radio"
          beat: sceneBeat.count
        }
        Text {
          anchors.bottom: parent.bottom; width: parent.width
          text: parent.modelData.name; textFormat: Text.PlainText
          color: "#f3eedc"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 18; font.bold: true
        }
      }
    }
    Timer { id: sceneBeat; property int count: 0; interval: 600; repeat: true; running: root.animated && root.visible && root.scene && root.scene.scene === "radio"; onTriggered: count++ }
    // Small authored props make the recorded activity visible.
    Rectangle {
      x: 279; y: 224; width: 82; height: 45; radius: 8
      visible: root.scene && root.scene.scene === "radio"
      color: "#d4a66c"; border.color: "#182b31"; border.width: 3
      Rectangle { x: 7; y: 9; width: 27; height: 27; radius: 14; color: "#314148" }
      Rectangle { x: 48; y: 10; width: 24; height: 9; radius: 2; color: "#eddfb6" }
      Rectangle { x: 48; y: 26; width: 7; height: 7; radius: 4; color: "#314148" }
      Rectangle { x: 21; y: -18; width: 3; height: 23; rotation: 22; color: "#d4a66c" }
    }
    Rectangle {
      x: 286; y: 235; width: 68; height: 35; radius: 13; rotation: -9
      visible: root.scene && root.scene.scene === "gift"
      color: "#acb6ae"; border.color: "#dce0c5"; border.width: 2
    }
    Item {
      x: 279; y: 217; width: 82; height: 56; visible: root.scene && root.scene.scene === "hat"
      Rectangle { x: 17; y: 2; width: 48; height: 40; radius: 9; rotation: -12; color: "#d8ae72" }
      Rectangle { y: 36; width: 82; height: 10; radius: 5; color: "#c98c59" }
    }
    Item {
      x: 270; y: 205; width: 100; height: 70; visible: root.scene && root.scene.scene === "shelter"
      Rectangle { x: 14; y: 25; width: 6; height: 46; rotation: 12; color: "#c29f73" }
      Rectangle { x: 77; y: 25; width: 6; height: 46; rotation: -9; color: "#c29f73" }
      Rectangle { y: 10; width: 100; height: 13; rotation: -16; radius: 3; color: "#cfac77" }
    }
    Rectangle {
      x: 296; y: 235; width: 48; height: 35; radius: 20
      visible: root.scene && (root.scene.scene === "picnic" || root.scene.scene === "hearts")
      color: "#cfa374"
      Repeater { model: 5; Rectangle { required property int index; x: 7 + (index * 17) % 34; y: 6 + (index * 13) % 20; width: 4; height: 4; radius: 2; color: "#654c3a" } }
    }
    Text { x: 305; y: 162; text: "♥"; color: "#e6a3ad"; font.pixelSize: 32; visible: root.scene && root.scene.scene === "hearts" }
    Creature {
      x: 269; y: 170; size: 102; visible: root.child !== null
      seed: root.child ? root.child.seed : 0; stageKey: root.child ? root.child.stage : "egg"
      bodyScale: Sim.stageScale(stageKey); mood: "happy"; animated: root.animated
      tint: Qt.hsla(Sim.seededUnit(root.child ? root.child.colorSeed : 0, 11), 0.52, 0.62, 1)
    }
    Text {
      x: 32; y: 315; width: 576; height: 60
      text: root.caption; textFormat: Text.PlainText; wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter; color: "#f3eedc"; font.pixelSize: 20
      fontSizeMode: Text.Fit; minimumPixelSize: 13
    }
    Text { x: 26; y: 380; text: "TINY SOCIAL LIFE  ·  OMARCHY"; color: "#bdcdb7"; font.pixelSize: 9; font.letterSpacing: 1.5 }
  }
}
