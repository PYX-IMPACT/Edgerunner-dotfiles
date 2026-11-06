import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

PanelWindow {
    id: win
    visible: false
    color: "transparent"
    implicitWidth: 600
    implicitHeight: col.implicitHeight + 56
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // palette
    readonly property color bg:    "#f012080a"
    readonly property color maroon:"#2a0c10"
    readonly property color panel: "#0f262b"
    readonly property color coral: "#c84c48"
    readonly property color dim:   "#7a2a2c"
    readonly property color cyan:  "#6ee7e7"
    readonly property color ink:   "#12080a"
    readonly property string fontName: "Rajdhani"

    property string query: ""
    property var results: []
    property int total: 0
    readonly property int matches: results.length
    readonly property int pct: {
        if (query.trim() === "" || matches === 0) return 0
        if (matches <= 2 || total <= 2) return 100
        return Math.round(100 * (1 - (matches - 2) / (total - 2)))
    }
    readonly property string status: {
        if (query.trim() === "") return "AWAITING INPUT"
        if (matches === 0) return "ATTENTION // NO SIGNAL"
        if (pct === 100) return "COMPLETE // ACCESS GRANTED"
        return "SCANNING ..."
    }
    readonly property bool alarm: query.trim() !== "" && matches === 0

    function score(name, full, q) {
        if (name.startsWith(q)) return 3
        if (name.includes(q)) return 2
        if (full.includes(q)) return 1.5
        let i = 0
        for (const c of name) { if (c === q[i]) i++; if (i === q.length) return 1 }
        return 0
    }

    function refresh() {
        const apps = Array.from(DesktopEntries.applications.values).filter(a => !a.noDisplay)
        total = apps.length
        const q = query.trim().toLowerCase()
        if (q === "") {
            results = apps.sort((x, y) => x.name.localeCompare(y.name))
        } else {
            results = apps
                .map(a => ({ a: a, s: score(a.name.toLowerCase(), (a.name + " " + (a.genericName || "")).toLowerCase(), q) }))
                .filter(x => x.s > 0)
                .sort((x, y) => (y.s - x.s) || x.a.name.localeCompare(y.a.name))
                .map(x => x.a)
        }
        list.currentIndex = 0
    }

    function launch() {
        if (results.length === 0) return
        results[list.currentIndex].execute()
        visible = false
    }

    function bits() {
        const s = query.slice(-5)
        let out = []
        for (const c of s) out.push(c.charCodeAt(0).toString(2).padStart(8, "0"))
        return out.length ? out.join("\n") : "00000000"
    }

    onVisibleChanged: if (visible) {
        query = ""; input.text = ""
        refresh()
        input.forceActiveFocus()
        flicker.restart()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { win.visible = !win.visible }
    }

    Item {
        id: root
        anchors.fill: parent

        SequentialAnimation {
            id: flicker
            NumberAnimation { target: root; property: "opacity"; to: 0.1; duration: 0 }
            NumberAnimation { target: root; property: "opacity"; to: 1;   duration: 50 }
            NumberAnimation { target: root; property: "opacity"; to: 0.3; duration: 40 }
            NumberAnimation { target: root; property: "opacity"; to: 1;   duration: 70 }
        }

        // clipped-corner frame
        Shape {
            id: frame
            anchors.fill: parent
            ShapePath {
                fillColor: win.bg
                strokeColor: win.alarm ? "#ff3b4e" : win.coral
                strokeWidth: 1.5
                startX: 0; startY: 0
                PathLine { x: frame.width - 28; y: 0 }
                PathLine { x: frame.width;      y: 28 }
                PathLine { x: frame.width;      y: frame.height }
                PathLine { x: 28;               y: frame.height }
                PathLine { x: 0;                y: frame.height - 28 }
                PathLine { x: 0;                y: 0 }
            }
        }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28 }
            spacing: 10

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: "05 KILO MICROCYBER BATTLEDECK V02 // ADMIN ACCESS"
                color: win.cyan; font.family: win.fontName; font.pixelSize: 11; font.bold: true
                font.letterSpacing: 1
            }

            // status + scan bar
            Row {
                width: parent.width
                Text {
                    width: parent.width / 2
                    text: win.status
                    color: win.alarm ? "#ff3b4e" : win.cyan
                    font.family: win.fontName; font.pixelSize: 15; font.bold: true
                }
                Text {
                    width: parent.width / 2
                    horizontalAlignment: Text.AlignRight
                    text: win.pct + "%   " + win.matches + "/" + win.total + " FILES"
                    color: win.cyan; font.family: win.fontName; font.pixelSize: 15; font.bold: true
                }
            }
            Rectangle {
                width: parent.width; height: 10
                color: win.panel; border.color: win.dim; border.width: 1
                Rectangle {
                    x: 1; y: 1; height: parent.height - 2
                    width: (parent.width - 2) * win.pct / 100
                    color: win.alarm ? "#ff3b4e" : win.cyan
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }

            // input
            Row {
                width: parent.width; height: 42
                Rectangle {
                    width: 90; height: parent.height; color: win.coral
                    Text {
                        anchors.centerIn: parent; text: "HACK"
                        color: win.ink; font.family: win.fontName; font.pixelSize: 17; font.bold: true
                        font.letterSpacing: 2
                    }
                }
                Rectangle {
                    width: parent.width - 90; height: parent.height
                    color: win.maroon; border.color: win.dim; border.width: 1
                    TextInput {
                        id: input
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: win.cyan; font.family: win.fontName; font.pixelSize: 17; font.bold: true
                        selectionColor: win.coral; selectedTextColor: win.ink
                        onTextChanged: { win.query = text; win.refresh() }
                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier
                            if (event.key === Qt.Key_Escape) { win.visible = false; event.accepted = true }
                            else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
                                list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1); event.accepted = true
                            } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
                                list.currentIndex = Math.max(list.currentIndex - 1, 0); event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                win.launch(); event.accepted = true
                            }
                        }
                        Text {
                            visible: input.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "TYPE TO BREACH //"
                            color: win.dim; font: input.font
                        }
                    }
                }
            }

            // side strip + list
            Row {
                width: parent.width
                spacing: 8
                Rectangle {
                    width: 22; height: list.height; color: win.coral
                    Text {
                        anchors.centerIn: parent; rotation: -90
                        text: "BREACH PROTOCOL // 104.008"
                        color: win.ink; font.family: win.fontName; font.pixelSize: 11; font.bold: true
                        font.letterSpacing: 2
                    }
                }
                ListView {
                    id: list
                    width: parent.width - 30
                    height: Math.max(1, Math.min(count, 7)) * 52
                    model: win.results
                    spacing: 6
                    clip: true
                    currentIndex: 0
                    highlightMoveDuration: 0

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool sel: ListView.isCurrentItem
                        width: list.width; height: 46

                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                fillColor: row.sel ? win.coral : win.panel
                                strokeColor: row.sel ? win.cyan : win.dim
                                strokeWidth: 1
                                startX: 0; startY: 0
                                PathLine { x: row.width - 16; y: 0 }
                                PathLine { x: row.width;      y: 16 }
                                PathLine { x: row.width;      y: row.height }
                                PathLine { x: 0;              y: row.height }
                                PathLine { x: 0;              y: 0 }
                            }
                        }
                        Row {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 24 }
                            spacing: 12
                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28; height: 28; sourceSize: Qt.size(28, 28)
                                source: Quickshell.iconPath(row.modelData.icon, true)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.name.toUpperCase()
                                color: row.sel ? win.ink : win.cyan
                                font.family: win.fontName; font.pixelSize: 17; font.bold: true
                                font.letterSpacing: 1
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (row.modelData.genericName || "").toUpperCase()
                                color: row.sel ? win.maroon : win.dim
                                font.family: win.fontName; font.pixelSize: 10; font.bold: true
                            }
                        }
                        Text {
                            anchors { right: parent.right; top: parent.top; rightMargin: 3; topMargin: 1 }
                            text: "◥"; color: row.sel ? win.ink : win.cyan; font.pixelSize: 11
                        }
                        Text {
                            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 8; bottomMargin: 3 }
                            text: (row.index + 1).toString().padStart(2, "0")
                            color: row.sel ? win.maroon : win.dim
                            font.family: win.fontName; font.pixelSize: 9; font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { list.currentIndex = row.index; win.launch() }
                        }
                    }
                }
            }

            // footer
            Row {
                width: parent.width
                Text {
                    width: parent.width / 2
                    text: "ROOT@ARCH-LAPTOP : ~ #"
                    color: win.cyan; font.family: win.fontName; font.pixelSize: 11; font.bold: true
                }
                Text {
                    width: parent.width / 2
                    horizontalAlignment: Text.AlignRight
                    text: win.bits()
                    color: win.coral; font.family: "monospace"; font.pixelSize: 9
                }
            }
        }
    }
}