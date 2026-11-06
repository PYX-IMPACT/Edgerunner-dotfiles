// Hud.qml - animated cyberpunk boot / login HUD, built from native QML elements.
// Drop next to shell.qml (e.g. /etc/greetd/Hud.qml) and use it as `Hud { anchors.fill: parent }`.
// Everything is laid out on a 960x540 reference stage that is scaled to fit the window.
import QtQuick

Item {
    id: hud

    // ---- settings ----------------------------------------------------------
    property string fontName: "Rajdhani"     // labels
    property string monoName: "monospace"    // scrolling log text
    property bool skipBoot: false            // true = jump straight to the idle HUD
    property int bootMs: 3800                // length of the boot-in sequence
    // ------------------------------------------------------------------------

    readonly property color red: "#ff3c4a"
    readonly property color redHi: "#ff7a84"
    readonly property color redDim: "#99ff3c4a"
    readonly property color glow: "#22ff3c4a"

    property real boot: 0                    // 0..1 boot progress
    readonly property bool bootDone: boot >= 1
    property real phase: 0                   // 0..2pi looping, drives the centre pulse
    property real pulse: 1                   // 1..0..1 breathing, drives the top bar
    property int tick: 0                     // fast counter for glyph flicker
    property int statA: 4335
    property int statB: 2047
    property string leaderA: "15549"
    property string leaderB: "152-99"

    readonly property real s: Math.min(width / 960, height / 540)
    readonly property real progress: clamp01((boot - 0.10) / 0.45)
    readonly property real consoleFade: 1 - clamp01((boot - 0.55) / 0.06)
    readonly property var steps: ["MOUNT CORE", "HANDSHAKE", "LOAD ICE", "SYNC NEURAL", "VERIFY"]

    function clamp01(v) { return Math.max(0, Math.min(1, v)) }

    // 0 -> 1 with a stuttery flicker while it comes in
    function appear(start, dur) {
        var v = clamp01((boot - start) / dur)
        if (v >= 1) return 1
        if (v <= 0) return 0
        return (Math.floor(v * 9) % 2 === 0) ? v : v * 0.3
    }

    function hex(n) {
        var d = "0123456789ABCDEF", r = ""
        for (var i = 0; i < n; i++) r += d[Math.floor(Math.random() * 16)]
        return r
    }

    // ---- animation drivers ---------------------------------------------------
    NumberAnimation on boot { from: 0; to: 1; duration: hud.skipBoot ? 1 : hud.bootMs; running: true }
    NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 2400; loops: Animation.Infinite }
    SequentialAnimation on pulse {
        loops: Animation.Infinite
        NumberAnimation { to: 0; duration: 1800; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 1800; easing.type: Easing.InOutSine }
    }
    Timer { interval: 120; running: true; repeat: true; onTriggered: hud.tick++ }
    Timer {
        interval: 900; running: true; repeat: true
        onTriggered: {
            hud.statA = 4000 + Math.floor(Math.random() * 900)
            hud.statB = 1900 + Math.floor(Math.random() * 300)
            hud.leaderA = String(10000 + Math.floor(Math.random() * 89999))
            hud.leaderB = (100 + Math.floor(Math.random() * 899)) + "-" + (10 + Math.floor(Math.random() * 89))
        }
    }

    // ---- reusable pieces -----------------------------------------------------
    // (inline components cannot see `hud`, so they carry their own colours)

    component PanelFrame: Item {
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1.5
            color: "transparent"
            border.width: 3
            border.color: "#1fff3c4a"
        }
        Rectangle {
            anchors.fill: parent
            color: "#40050001"
            border.width: 1
            border.color: "#ff3c4a"
        }
    }

    component TagBox: Rectangle {
        id: tb
        property string line1: ""
        property string line2: ""
        property string family: "Rajdhani"
        property real p: 1                   // 0..1 typing progress
        color: "#70100002"
        border.width: 1
        border.color: "#ff3c4a"
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: tb.line1.substring(0, Math.round(tb.line1.length * tb.p))
                color: "#ff3c4a"
                font.family: tb.family
                font.pixelSize: 7
                font.bold: true
                font.letterSpacing: 1
            }
            Text {
                visible: tb.line2 !== ""
                text: tb.line2.substring(0, Math.round(tb.line2.length * tb.p))
                color: "#ff3c4a"
                font.family: tb.family
                font.pixelSize: 7
                font.bold: true
                font.letterSpacing: 1
            }
        }
    }

    component LogPanel: Item {
        id: lp
        property int rows: 24
        property string family: "monospace"
        property int interval: 170
        clip: true

        function hx(n) {
            var d = "0123456789ABCDEF", r = ""
            for (var i = 0; i < n; i++) r += d[Math.floor(Math.random() * 16)]
            return r
        }
        function gen() {
            var ops = ["MOV", "PUSH", "POP", "CALL", "JMP", "XOR", "LOAD", "SYNC", "PING", "AUTH", "TRACE", "HASH"]
            var r = Math.random()
            if (r > 0.93) return ""
            var pad = r < 0.2 ? "     " : (r < 0.3 ? "  " : "")
            return pad + hx(4) + "  " + ops[Math.floor(Math.random() * ops.length)] + " " + hx(2)
                   + (r > 0.45 ? "  " + hx(4) + " " + hx(4) : "")
        }

        ListModel { id: lm }
        Component.onCompleted: {
            for (var i = 0; i < lp.rows; i++) lm.append({ line: lp.gen() })
        }
        Column {
            Repeater {
                model: lm
                delegate: Text {
                    height: 6.8
                    text: line
                    color: "#c8ff3c4a"
                    font.family: lp.family
                    font.pixelSize: 6
                }
            }
        }
        Timer {
            interval: lp.interval
            running: true
            repeat: true
            onTriggered: { lm.remove(0); lm.append({ line: lp.gen() }) }
        }
    }

    // ---- background ----------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#240406" }
            GradientStop { position: 0.45; color: "#0a0102" }
            GradientStop { position: 1.0; color: "#030000" }
        }
    }

    // ---- curved top bar (painted once, glow comes from canvas shadow) ---------
    Canvas {
        id: barCanvas
        anchors.fill: parent
        opacity: hud.clamp01(hud.boot / 0.08) * (0.86 + 0.14 * hud.pulse)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.save()
            ctx.translate((width - 960 * hud.s) / 2, (height - 540 * hud.s) / 2)
            ctx.scale(hud.s, hud.s)

            ctx.beginPath()
            ctx.moveTo(72, 58)
            ctx.quadraticCurveTo(480, 76, 888, 58)
            ctx.lineTo(888, 65)
            ctx.quadraticCurveTo(480, 83, 72, 65)
            ctx.closePath()
            ctx.shadowColor = "#ff3c4a"
            ctx.shadowBlur = 16 * hud.s
            ctx.fillStyle = "#ff3c4a"
            ctx.fill()

            ctx.shadowBlur = 0
            ctx.beginPath()
            ctx.moveTo(72, 61.5)
            ctx.quadraticCurveTo(480, 79.5, 888, 61.5)
            ctx.strokeStyle = "#ffa0a8"
            ctx.lineWidth = 1.2
            ctx.stroke()

            // notch near the right end
            ctx.beginPath()
            ctx.moveTo(765, 56)
            ctx.lineTo(765, 76)
            ctx.strokeStyle = "#050000"
            ctx.lineWidth = 1.5
            ctx.stroke()
            ctx.restore()
        }
    }

    // ---- leader lines under the left panel ------------------------------------
    Canvas {
        id: leaderCanvas
        anchors.fill: parent
        opacity: hud.appear(0.64, 0.10)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.save()
            ctx.translate((width - 960 * hud.s) / 2, (height - 540 * hud.s) / 2)
            ctx.scale(hud.s, hud.s)
            ctx.strokeStyle = "#ff3c4a"
            ctx.lineWidth = 1
            ctx.shadowColor = "#ff3c4a"
            ctx.shadowBlur = 5 * hud.s
            ctx.beginPath()
            ctx.moveTo(173, 254); ctx.lineTo(228, 358)
            ctx.moveTo(173, 254); ctx.lineTo(272, 358)
            ctx.moveTo(272, 254); ctx.lineTo(272, 358)
            ctx.stroke()
            ctx.restore()
        }
    }

    // ---- everything else lives on a scaled 960x540 stage ---------------------
    Item {
        id: stage
        width: 960
        height: 540
        anchors.centerIn: parent
        scale: hud.s

        // tiny label printed on the bar
        Text {
            x: 78; y: 57.5
            text: "NETWATCH // NODE 04 // SECURE CHANNEL"
            color: "#55000a"
            font.family: hud.fontName
            font.pixelSize: 5
            font.bold: true
            font.letterSpacing: 1
            opacity: hud.appear(0.03, 0.05)
        }

        // ---------- boot console (hex rows + progress bar) ----------
        Column {
            x: 218; y: 182
            spacing: 33
            Repeater {
                model: 6
                delegate: Text {
                    text: "PSSRD : 0X" + hud.hex(2) + ", ADDR:0X" + hud.hex(2)
                    color: hud.red
                    font.family: hud.fontName
                    font.pixelSize: 7
                    font.bold: true
                    font.letterSpacing: 1
                    opacity: hud.appear(0.08 + index * 0.05, 0.04) * hud.consoleFade
                }
            }
        }
        Item {
            x: 373; y: 290
            width: 326; height: 50
            opacity: hud.appear(0.06, 0.06) * hud.consoleFade
            TagBox { width: 78; height: 13; line1: "SYSTEM REBOOT"; family: hud.fontName }
            Rectangle {
                y: 23
                width: parent.width; height: 8
                color: "transparent"
                border.width: 1
                border.color: hud.red
                Rectangle {
                    x: 2; y: 2
                    height: 4
                    width: (parent.width - 4) * hud.progress
                    color: hud.red
                }
            }
            Text {
                y: 34
                text: "INIT // " + hud.steps[Math.min(4, Math.floor(hud.progress * 5))]
                color: hud.redDim
                font.family: hud.fontName
                font.pixelSize: 6
                font.letterSpacing: 1
            }
            Text {
                y: 34
                anchors.right: parent.right
                text: Math.round(hud.progress * 100) + "%"
                color: hud.red
                font.family: hud.fontName
                font.pixelSize: 8
                font.bold: true
            }
        }

        // ---------- centre diamond of ringed dots ----------
        Repeater {
            model: 25
            delegate: Item {
                id: dot
                property int ix: index % 5 - 2
                property int iy: Math.floor(index / 5) - 2
                property int d: Math.abs(ix) + Math.abs(iy)
                visible: d <= 2
                x: 480 + ix * 9 - 3.5
                y: 215 + iy * 9 - 3.5
                width: 7; height: 7
                opacity: (0.25 + 0.75 * (0.5 + 0.5 * Math.sin(hud.phase - d * 1.1)))
                         * (0.3 + 0.7 * hud.clamp01(hud.boot / 0.5))
                Rectangle {
                    anchors.fill: parent
                    radius: 3.5
                    color: "transparent"
                    border.width: 1
                    border.color: hud.red
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 3; height: 3; radius: 1.5
                    color: hud.redHi
                }
            }
        }

        // ---------- left panel ----------
        Item {
            x: 72; y: 75
            width: 200; height: 179
            opacity: hud.appear(0.58, 0.12)
            PanelFrame { anchors.fill: parent }
            Rectangle { width: parent.width; height: 3; color: hud.red }
            LogPanel { x: 5; y: 8; width: 190; height: 168; rows: 24; family: hud.monoName; interval: 170 }
        }
        Text {
            x: 76; y: 257
            text: "LOCAL NODE // 6F4A-2E91\nARRAY INTEGRITY 99.2%"
            color: hud.redDim
            font.family: hud.fontName
            font.pixelSize: 5
            font.letterSpacing: 1
            opacity: hud.appear(0.62, 0.08)
        }
        Text {
            x: 203; y: 361
            text: hud.leaderA
            color: hud.red
            font.family: hud.fontName
            font.pixelSize: 6
            font.bold: true
            font.letterSpacing: 1
            opacity: hud.appear(0.66, 0.08)
        }
        Text {
            x: 248; y: 361
            text: hud.leaderB
            color: hud.red
            font.family: hud.fontName
            font.pixelSize: 6
            font.bold: true
            font.letterSpacing: 1
            opacity: hud.appear(0.66, 0.08)
        }

        // ---------- stats next to the left panel ----------
        Row {
            x: 280; y: 82
            spacing: 4
            opacity: hud.appear(0.66, 0.08)
            Rectangle { y: 2; width: 5; height: 5; color: "transparent"; border.width: 1; border.color: hud.red }
            Text {
                text: "W " + hud.statA + "\nC " + hud.statB
                color: hud.red
                font.family: hud.fontName
                font.pixelSize: 7
                font.bold: true
                font.letterSpacing: 1
            }
        }

        // ---------- right panel (log) ----------
        Item {
            x: 765; y: 65
            width: 120; height: 218
            opacity: hud.appear(0.62, 0.12)
            PanelFrame { anchors.fill: parent }
            Rectangle { width: parent.width; height: 6; color: hud.red }
            Text {
                x: 3; y: 0.5
                text: "SUBSYSTEM LOG // LIVE"
                color: "#55000a"
                font.family: hud.fontName
                font.pixelSize: 5
                font.bold: true
                font.letterSpacing: 1
            }
            LogPanel { x: 4; y: 10; width: 112; height: 206; rows: 30; family: hud.monoName; interval: 210 }
        }

        // ---------- right panel (glyph grid) ----------
        Item {
            x: 765; y: 287
            width: 120; height: 78
            opacity: hud.appear(0.68, 0.10)
            PanelFrame { anchors.fill: parent }
            Repeater {
                model: 21
                delegate: Text {
                    x: 12 + (index % 7) * 14
                    y: 7 + Math.floor(index / 7) * 11
                    text: "\\"
                    color: hud.red
                    font.family: hud.monoName
                    font.pixelSize: 9
                    font.bold: true
                    opacity: Math.sin(hud.tick * 0.55 + index * 1.9) > -0.25 ? 1 : 0.15
                }
            }
            Text {
                x: 4; y: 50
                text: "W " + hud.statA + "\nC " + hud.statB
                color: hud.red
                font.family: hud.fontName
                font.pixelSize: 6
                font.bold: true
                font.letterSpacing: 1
            }
        }
        Text {
            x: 767; y: 369
            text: "UPLINK 02 // PACKET LOSS 0.0%\nRELAY CHAIN ESTABLISHED"
            color: hud.redDim
            font.family: hud.fontName
            font.pixelSize: 5
            font.letterSpacing: 1
            opacity: hud.appear(0.72, 0.08)
        }

        // ---------- bottom tag boxes (sit below the login block) ----------
        TagBox {
            x: 410; y: 432; width: 97; height: 27
            line1: "CYBERWARE"; line2: "DIAGNOSTICS"; family: hud.fontName
            p: hud.clamp01((hud.boot - 0.78) / 0.10)
            opacity: hud.appear(0.78, 0.06)
        }
        TagBox {
            x: 509; y: 432; width: 97; height: 27
            line1: "SECURITY"; line2: "SYSTEMS"; family: hud.fontName
            p: hud.clamp01((hud.boot - 0.83) / 0.10)
            opacity: hud.appear(0.83, 0.06)
        }
        TagBox {
            x: 509; y: 462; width: 97; height: 27
            line1: "NETWORK"; line2: "FRAMEWORK"; family: hud.fontName
            p: hud.clamp01((hud.boot - 0.88) / 0.10)
            opacity: hud.appear(0.88, 0.06)
        }

        // ---------- status blip ----------
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 508
            text: "SYSTEM ONLINE"
            color: hud.redDim
            font.family: hud.fontName
            font.pixelSize: 7
            font.bold: true
            font.letterSpacing: 3
            opacity: hud.appear(0.92, 0.05) * (hud.tick % 8 < 5 ? 1 : 0.35)
        }
    }
}
