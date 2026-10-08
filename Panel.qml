pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Your online tailnet machines; pick one to open its desktop with bin/omaremote.
Panel {
  id: root
  moduleName: "io.github.matiacone.omaremote"
  ipcTarget: "io.github.matiacone.omaremote"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar && bar.foreground !== undefined ? bar.foreground : Color.foreground
  readonly property color urgent: bar && bar.urgent !== undefined ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string cliPath: String(Qt.resolvedUrl("bin/omaremote")).replace(/^file:\/\//, "")

  property var machines: []
  property bool loading: false
  property string error: ""
  property string connecting: ""
  property int selectedIndex: 0

  readonly property bool mirror: setting("mirror", false) === true
  readonly property bool h264: setting("h264", false) === true

  readonly property var supportedCount: {
    var n = 0
    for (var i = 0; i < machines.length; i++) if (machines[i].supported) n++
    return n
  }

  function osGlyph(os) {
    if (os === "linux") return "󰌽"
    if (os === "macOS") return "󰀵"
    if (os === "windows") return "󰖳"
    if (os === "iOS") return "󰀷"
    if (os === "android") return "󰀲"
    return "󰍹"
  }

  function refresh() {
    if (listProc.running) return
    loading = true
    error = ""
    listProc.running = true
  }

  function moveCursor(dy) {
    if (machines.length === 0) return
    selectedIndex = Math.max(0, Math.min(machines.length - 1, selectedIndex + dy))
  }

  function connect(machine) {
    if (!machine || !machine.supported) return
    var args = [cliPath]
    if (mirror) args.push("--mirror")
    if (h264) args.push("--h264")
    args.push(machine.name)
    Quickshell.execDetached(args)
    connecting = machine.name
    connectingReset.restart()
    close()
  }

  function persist(key, value) {
    var entry = { id: root.moduleName }
    var current = root.settings || ({})
    for (var k in current) if (k !== "id") entry[k] = current[k]
    entry[key] = !!value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  onOpenedChanged: if (opened) refresh()

  Timer {
    id: connectingReset
    interval: 4000
    onTriggered: root.connecting = ""
  }

  Process {
    id: listProc
    command: [root.cliPath, "list"]
    stdout: StdioCollector { id: listOut; waitForEnd: true }
    stderr: StdioCollector { id: listErr; waitForEnd: true }
    onExited: function(code) {
      root.loading = false
      if (code !== 0) {
        root.error = String(listErr.text || "").trim() || "Couldn't read tailscale status"
        return
      }
      try {
        var list = JSON.parse(listOut.text)
        root.machines = list
        root.selectedIndex = Math.min(root.selectedIndex, Math.max(0, list.length - 1))
      } catch (e) {
        root.error = "Couldn't read tailscale status"
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: Style.space(380)
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: root.connect(root.machines[root.selectedIndex])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "m" || t === "M") root.persist("mirror", !root.mirror)
        else if (t === "h" || t === "H") root.persist("h264", !root.h264)
        else if (t === "r" || t === "R") root.refresh()
      }

      ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        PanelHero {
          Layout.fillWidth: true
          title: "Remote desktop"
          meta: root.loading && root.machines.length === 0 ? "Looking for machines…"
            : root.connecting !== "" ? "Connecting to " + root.connecting + "…"
            : root.supportedCount + (root.supportedCount === 1 ? " machine" : " machines") + " you can open"
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "󰢹"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

        Text {
          visible: root.error !== ""
          Layout.fillWidth: true
          text: root.error
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          visible: !root.loading && root.error === "" && root.machines.length === 0
          Layout.fillWidth: true
          text: "No other machines on your tailnet are online."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Column {
          Layout.fillWidth: true
          spacing: Style.space(2)

          Repeater {
            model: root.machines
            delegate: Item {
              id: row
              required property var modelData
              required property int index
              width: parent ? parent.width : 0
              implicitHeight: rowLayout.implicitHeight + Style.space(12)
              opacity: modelData.supported ? 1 : 0.45

              Rectangle {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: root.selectedIndex === row.index ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent"
              }

              RowLayout {
                id: rowLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(10)

                Text {
                  text: root.osGlyph(row.modelData.os)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.subtitle
                }

                Text {
                  Layout.fillWidth: true
                  text: row.modelData.name
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }

                Text {
                  text: row.modelData.supported ? row.modelData.ip : row.modelData.shared ? "shared" : row.modelData.os
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: row.modelData.supported ? Qt.PointingHandCursor : Qt.ArrowCursor
                onEntered: root.selectedIndex = row.index
                onClicked: root.connect(row.modelData)
              }
            }
          }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

        Toggle {
          Layout.fillWidth: true
          label: "Mirror the real monitor"
          description: "Off: a fullscreen virtual screen sized to yours (m)"
          checked: root.mirror
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.persist("mirror", !root.mirror)
        }

        Toggle {
          Layout.fillWidth: true
          label: "H.264"
          description: "Smoother on slow links, slightly washed-out colors (h)"
          checked: root.h264
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.persist("h264", !root.h264)
        }

        Text {
          Layout.fillWidth: true
          text: "Enter connects · F8 in the viewer to disconnect"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
