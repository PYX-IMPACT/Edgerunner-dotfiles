import QtQuick
import Quickshell
import Quickshell.Services.Greetd

FloatingWindow {
    id: win
    visible: true
    color: "#050000"

    // ---- settings you might want to tweak -------------------------------
    property bool skipPick: false          // true = go straight to password when only one profile exists
    property string sessionCmd: "start-hyprland"
    property real uiY: 0.53                // vertical position of the login block (fraction of screen height)
    property string fontName: "Rajdhani"   // must be installed system-wide; falls back to the default font if missing
    // ---------------------------------------------------------------------

    property string stage: "pick"          // "pick" | "password"
    property int sel: 0
    property string chosenTitle: ""
    property bool busy: false
    property bool launching: false
    property bool fading: false
    property bool glitchOn: false
    property real shakeX: 0

    readonly property color red: "#ff3c4a"
    readonly property color redHi: "#ff7a84"
    readonly property color redDim: "#99ff3c4a"
    readonly property color redFaint: "#40ff3c4a"
    readonly property color ink: "#120002"
    readonly property color panel: "#c0100002"

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // Add more profiles by adding more ListElement lines.
    // uname must be the real Linux username.
    ListModel {
        id: users
        ListElement { uname: "whoami"; title: "WHOAMI"; tag: "NETRUNNER"; avatar: "" }
    }

    function setStatus(msg, col) {
        status.text = msg
        status.color = col
    }

    function pick(i) {
        var u = users.get(i)
        win.chosenTitle = u.title
        setStatus("", win.red)
        win.busy = true
        Greetd.createSession(u.uname)
    }

    Component.onCompleted: {
        if (skipPick && users.count === 1) pick(0)
    }

    onStageChanged: {
        if (stage === "password") input.forceActiveFocus()
        else root.forceActiveFocus()
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                win.busy = false
                win.stage = "password"
                input.text = ""
                input.echoMode = echoResponse ? TextInput.Normal : TextInput.Password
            } else {
                win.setStatus(message.toUpperCase(), error ? win.red : win.redHi)
            }
        }
        function onAuthFailure(message) {
            win.busy = false
            win.setStatus("ACCESS DENIED", win.red)
            win.stage = "pick"
            input.text = ""
            shake.restart()
            if (win.skipPick && users.count === 1) retry.start()
        }
        function onReadyToLaunch() {
            win.launching = true
            win.setStatus("ACCESS GRANTED", win.redHi)
            fadeTimer.start()
        }
    }

    Timer { id: fadeTimer; interval: 700; onTriggered: { win.fading = true; launchTimer.start() } }
    Timer { id: launchTimer; interval: 450; onTriggered: Greetd.launch(win.sessionCmd.split(" ")) }
    Timer { id: retry; interval: 700; onTriggered: win.pick(0) }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: win; property: "shakeX"; to: -14; duration: 50 }
        NumberAnimation { target: win; property: "shakeX"; to: 14; duration: 50 }
        NumberAnimation { target: win; property: "shakeX"; to: -9; duration: 50 }
        NumberAnimation { target: win; property: "shakeX"; to: 9; duration: 50 }
        NumberAnimation { target: win; property: "shakeX"; to: 0; duration: 50 }
    }

    Timer {
        running: true; repeat: true; interval: 3000
        onTriggered: {
            if (!win.glitchOn) { win.glitchOn = true; interval = 90 }
            else { win.glitchOn = false; interval = 2500 + Math.random() * 3500 }
        }
    }

    Item {
        id: root
        anchors.fill: parent
        focus: true

        // Everything is sized against a 1280x720 reference so it lines up with the background art.
        readonly property real u: height / 720
        readonly property int bw: Math.max(1, Math.round(u))
        function px(n) { return Math.round(n * u) }

        Keys.onPressed: function(event) {
            if (!hud.bootDone || win.stage !== "pick" || win.busy) return
            if (event.key === Qt.Key_Left) win.sel = Math.max(0, win.sel - 1)
            else if (event.key === Qt.Key_Right) win.sel = Math.min(users.count - 1, win.sel + 1)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.pick(win.sel)
        }

        // ---- background: animated HUD (Hud.qml, same folder) ----
        Hud {
            id: hud
            anchors.fill: parent
            fontName: win.fontName
        }

        // slow scan bar sweeping down the screen
        Rectangle {
            id: scanBar
            width: parent.width
            height: root.px(110)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00ff3c4a" }
                GradientStop { position: 0.5; color: "#12ff3c4a" }
                GradientStop { position: 1.0; color: "#00ff3c4a" }
            }
            NumberAnimation on y {
                from: -root.px(110); to: root.height
                duration: 9000
                loops: Animation.Infinite
            }
        }

        // CRT scanlines (painted once)
        Canvas {
            anchors.fill: parent
            opacity: 0.16
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = "#000000"
                for (var y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1)
            }
        }

        // ---- clock (top centre, between the side panels) ----
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.12
            spacing: 0
            opacity: hud.bootDone ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: win.red
                font.family: win.fontName
                font.bold: true
                font.pixelSize: root.px(38)
                font.letterSpacing: root.px(3)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "ddd dd MMM yyyy").toUpperCase()
                color: win.redDim
                font.family: win.fontName
                font.pixelSize: root.px(12)
                font.letterSpacing: root.px(2)
            }
        }

        // ---- login block ----
        Item {
            id: cluster
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * win.uiY
            width: root.px(560)
            height: root.px(170)
            transform: Translate { x: win.shakeX }
            opacity: hud.bootDone ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }

            // profile select: outlined boxes like the in-game menu
            Row {
                id: pickRow
                opacity: (win.stage === "pick" && !win.launching) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                spacing: root.px(8)

                Repeater {
                    model: users
                    delegate: Item {
                        id: card
                        width: root.px(210)
                        height: root.px(46)
                        property bool active: win.sel === index

                        opacity: 0
                        ParallelAnimation {
                            running: true
                            PauseAnimation { duration: 100 * index }
                            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 320 }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: card.active ? win.red : win.panel
                            border.width: root.bw
                            border.color: win.red
                        }
                        Column {
                            x: root.px(12)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Text {
                                text: title
                                color: card.active ? win.ink : win.red
                                font.family: win.fontName
                                font.bold: true
                                font.pixelSize: root.px(16)
                                font.letterSpacing: root.px(1.5)
                            }
                            Text {
                                text: tag
                                color: card.active ? win.ink : win.redDim
                                font.family: win.fontName
                                font.pixelSize: root.px(11)
                                font.letterSpacing: root.px(1.5)
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: root.px(6)
                            text: "0" + (index + 1)
                            color: card.active ? win.ink : win.redDim
                            font.family: win.fontName
                            font.pixelSize: root.px(10)
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !win.busy
                            onEntered: if (win.stage === "pick") win.sel = index
                            onClicked: { win.sel = index; win.pick(index) }
                        }
                    }
                }
            }
            Text {
                opacity: pickRow.opacity
                visible: opacity > 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.px(58)
                text: "<  >  SELECT        ENTER  CONFIRM"
                color: win.redDim
                font.family: win.fontName
                font.pixelSize: root.px(11)
                font.letterSpacing: root.px(2)
            }

            // password prompt
            Column {
                id: passPanel
                opacity: (win.stage === "password" && !win.launching) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                width: root.px(320)
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                spacing: root.px(6)

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "// AUTHORIZATION REQUIRED"
                    color: win.redDim
                    font.family: win.fontName
                    font.pixelSize: root.px(11)
                    font.letterSpacing: root.px(2)
                }

                // name with RGB-split glitch
                Item {
                    width: parent.width
                    height: root.px(28)
                    Text {
                        width: parent.width
                        x: win.glitchOn ? -root.px(4) : 0
                        horizontalAlignment: Text.AlignHCenter
                        text: win.chosenTitle
                        color: "#7a0010"
                        opacity: win.glitchOn ? 0.9 : 0
                        font.family: win.fontName; font.bold: true
                        font.pixelSize: root.px(22); font.letterSpacing: root.px(2)
                    }
                    Text {
                        width: parent.width
                        x: win.glitchOn ? root.px(4) : 0
                        horizontalAlignment: Text.AlignHCenter
                        text: win.chosenTitle
                        color: "#ffb0b6"
                        opacity: win.glitchOn ? 0.8 : 0
                        font.family: win.fontName; font.bold: true
                        font.pixelSize: root.px(22); font.letterSpacing: root.px(2)
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: win.chosenTitle
                        color: win.red
                        font.family: win.fontName; font.bold: true
                        font.pixelSize: root.px(22); font.letterSpacing: root.px(2)
                    }
                }

                Rectangle {
                    id: box
                    width: parent.width
                    height: root.px(40)
                    color: win.panel
                    border.width: root.bw
                    border.color: win.busy ? win.redHi : win.red

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: root.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text.length === 0 && !win.busy
                        text: "PASSPHRASE"
                        color: win.redFaint
                        font.family: win.fontName
                        font.pixelSize: root.px(15)
                        font.letterSpacing: root.px(2)
                    }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.margins: root.px(12)
                        verticalAlignment: TextInput.AlignVCenter
                        color: win.redHi
                        font.family: win.fontName
                        font.pixelSize: root.px(18)
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        enabled: !win.busy
                        cursorDelegate: Rectangle {
                            width: root.px(9)
                            color: win.red
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: input.activeFocus
                                NumberAnimation { to: 0; duration: 500 }
                                NumberAnimation { to: 1; duration: 500 }
                            }
                        }
                        onAccepted: {
                            win.busy = true
                            win.setStatus("", win.red)
                            Greetd.respond(text)
                            text = ""
                        }
                        Keys.onEscapePressed: {
                            Greetd.cancelSession()
                            win.busy = false
                            win.setStatus("", win.red)
                            win.stage = "pick"
                        }
                    }

                    // "authenticating" sweep bar
                    Rectangle {
                        id: bar
                        visible: win.busy
                        anchors.bottom: parent.bottom
                        height: root.px(3)
                        width: root.px(70)
                        color: win.red
                        SequentialAnimation on x {
                            loops: Animation.Infinite
                            running: win.busy
                            NumberAnimation { from: 0; to: box.width - bar.width; duration: 700; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: box.width - bar.width; to: 0; duration: 700; easing.type: Easing.InOutQuad }
                        }
                    }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: win.busy ? "AUTHENTICATING..." : "ENTER  LOGIN        ESC  BACK"
                    color: win.busy ? win.redHi : win.redDim
                    font.family: win.fontName
                    font.pixelSize: root.px(11)
                    font.letterSpacing: root.px(2)
                }
            }

            // status line
            Text {
                id: status
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.px(118)
                color: win.red
                font.family: win.fontName
                font.bold: true
                font.pixelSize: root.px(14)
                font.letterSpacing: root.px(3)
            }

            // power buttons
            ListModel {
                id: powerModel
                ListElement { label: "REBOOT"; verb: "reboot" }
                ListElement { label: "SHUTDOWN"; verb: "poweroff" }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.px(146)
                spacing: root.px(8)
                opacity: win.launching ? 0 : 1
                Repeater {
                    model: powerModel
                    delegate: Rectangle {
                        width: root.px(96)
                        height: root.px(22)
                        color: ma.containsMouse ? win.red : "transparent"
                        border.width: root.bw
                        border.color: win.redDim
                        Text {
                            anchors.centerIn: parent
                            text: label
                            color: ma.containsMouse ? win.ink : win.redDim
                            font.family: win.fontName
                            font.bold: true
                            font.pixelSize: root.px(11)
                            font.letterSpacing: root.px(2)
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["systemctl", verb])
                        }
                    }
                }
            }
        }

        // ---- fade to black on successful login ----
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: win.fading ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
    }
}
