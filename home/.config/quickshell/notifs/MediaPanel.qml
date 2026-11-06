import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Services.Mpris

// NOW PLAYING card for the left side of the screen. Driven by an MprisPlayer (Spotify).
//   peek()   pop open for a few seconds (track change / music notification)
//   toggle() pin it open / close it
Item {
    id: panel

    required property var pal
    property var player: null

    property bool pinned: false
    property bool peeking: false
    readonly property bool open: pinned || peeking

    function peek() {
        if (!player) return;
        peeking = true;
        peekTimer.restart();
    }
    function toggle() {
        if (open) { pinned = false; peeking = false; }
        else pinned = true;
    }
    function show() { pinned = true; }
    function hide() { pinned = false; peeking = false; }

    Timer {
        id: peekTimer
        interval: 6000
        running: panel.peeking && !hover.hovered && !panel.pinned
        onTriggered: panel.peeking = false
    }

    // ───────── player state ─────────
    readonly property color accent: pal.cyan
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackState === MprisPlaybackState.Playing
    readonly property real length: hasPlayer && player.lengthSupported ? player.length : 0
    readonly property real pos: hasPlayer && player.positionSupported ? player.position : 0
    readonly property real ratio: length > 0 ? Math.max(0, Math.min(1, pos / length)) : 0

    function fmt(t) {
        const s = Math.max(0, Math.floor(t));
        return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2);
    }

    // Mpris does not push position updates, so poll while visible and playing
    Timer {
        interval: 500
        repeat: true
        running: panel.open && panel.playing
        onTriggered: panel.player.positionChanged()
    }
    onOpenChanged: if (open && hasPlayer) player.positionChanged()

    // ───────── geometry / animation ─────────
    readonly property real coverW: 72
    readonly property real ghost: 14

    width: 400
    height: content.implicitHeight + 30

    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    transform: Translate {
        x: panel.open ? 0 : -60
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }

    component Glow: MultiEffect {
        property color tint: "#2de2e6"
        shadowEnabled: true
        shadowColor: tint
        shadowBlur: 0.45
        shadowOpacity: 0.5
        blurMax: 14
    }

    // one transport / toggle button
    component TButton: Item {
        id: b
        property string kind: "play"      // play | pause | next | prev | text
        property string label: ""
        property bool active: false
        property bool off: false
        property bool hot: false
        property color col: "#2de2e6"
        property string fam: "Rajdhani"
        signal clicked()

        width: label !== "" ? 54 : (hot ? 48 : 38)
        height: 26
        opacity: off ? 0.3 : (bh.hovered ? 1.0 : 0.85)

        CutFrame {
            anchors.fill: parent
            cut: 6
            lw: 1.2
            stroke: b.col
            fill: (b.active || b.hot) ? Qt.rgba(b.col.r, b.col.g, b.col.b, b.hot ? 0.2 : 0.14) : "transparent"
        }

        Shape {
            anchors.centerIn: parent
            width: 12
            height: 12
            visible: b.label === ""
            preferredRendererType: Shape.CurveRenderer
            // play
            ShapePath {
                fillColor: b.kind === "play" ? b.col : "transparent"
                strokeColor: "transparent"
                startX: 2; startY: 0
                PathLine { x: 12; y: 6 }
                PathLine { x: 2; y: 12 }
                PathLine { x: 2; y: 0 }
            }
            // pause
            ShapePath {
                fillColor: b.kind === "pause" ? b.col : "transparent"
                strokeColor: "transparent"
                startX: 1; startY: 0
                PathLine { x: 4.5; y: 0 }
                PathLine { x: 4.5; y: 12 }
                PathLine { x: 1; y: 12 }
                PathLine { x: 1; y: 0 }
            }
            ShapePath {
                fillColor: b.kind === "pause" ? b.col : "transparent"
                strokeColor: "transparent"
                startX: 7.5; startY: 0
                PathLine { x: 11; y: 0 }
                PathLine { x: 11; y: 12 }
                PathLine { x: 7.5; y: 12 }
                PathLine { x: 7.5; y: 0 }
            }
            // next: triangle + bar
            ShapePath {
                fillColor: b.kind === "next" ? b.col : "transparent"
                strokeColor: "transparent"
                startX: 0; startY: 0
                PathLine { x: 8; y: 6 }
                PathLine { x: 0; y: 12 }
                PathLine { x: 0; y: 0 }
            }
            ShapePath {
                fillColor: b.kind === "next" ? b.col : "transparent"
                strokeColor: "transparent"
                startX: 9.5; startY: 0
                PathLine { x: 12; y: 0 }
                PathLine { x: 12; y: 12 }
                PathLine { x: 9.5; y: 12 }
                PathLine { x: 9.5; y: 0 }
            }
            // prev: bar + triangle
            ShapePath {
                fillColor: b.kind === "prev" ? b.col : "transparent"
                strokeColor: "transparent"
                startX: 12; startY: 0
                PathLine { x: 4; y: 6 }
                PathLine { x: 12; y: 12 }
                PathLine { x: 12; y: 0 }
            }
            ShapePath {
                fillColor: b.kind === "prev" ? b.col : "transparent"
                strokeColor: "transparent"
                startX: 0; startY: 0
                PathLine { x: 2.5; y: 0 }
                PathLine { x: 2.5; y: 12 }
                PathLine { x: 0; y: 12 }
                PathLine { x: 0; y: 0 }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: b.label !== ""
            text: b.label
            color: b.col
            font.family: b.fam
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }

        HoverHandler { id: bh; enabled: !b.off }
        MouseArea {
            anchors.fill: parent
            enabled: !b.off
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    // right-click anywhere on the card to close it
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: panel.hide()
    }
    HoverHandler { id: hover }

    // ───────── backdrop ─────────
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0.03, 0.02, 0.06, 0.88) }
            GradientStop { position: 0.7; color: Qt.rgba(0.03, 0.02, 0.06, 0.64) }
            GradientStop { position: 1.0; color: Qt.rgba(0.03, 0.02, 0.06, 0.0) }
        }
    }
    Rectangle { width: 3; height: parent.height; color: panel.accent }
    Rectangle {
        width: parent.width
        height: 1
        opacity: 0.45
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: panel.accent }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 4
        text: "///"
        color: panel.accent
        opacity: 0.5
        font.family: panel.pal.font
        font.pixelSize: 10
        font.weight: Font.Bold
    }

    // ───────── content ─────────
    Column {
        id: content
        x: 26
        y: 15
        width: panel.width - 26 - 22
        spacing: 16

        Row {
            id: topRow
            spacing: 18

            // cover art, stacked frames receding up-left
            Item {
                id: cover
                x: panel.ghost
                y: panel.ghost
                width: panel.coverW
                height: panel.coverW

                CutFrame { x: -panel.ghost;     y: -panel.ghost;     width: parent.width; height: parent.height; cut: 9; lw: 1; stroke: panel.accent; opacity: 0.2 }
                CutFrame { x: -panel.ghost / 2; y: -panel.ghost / 2; width: parent.width; height: parent.height; cut: 9; lw: 1; stroke: panel.accent; opacity: 0.4 }
                CutFrame { anchors.fill: parent; cut: 9; fill: Qt.rgba(0, 0, 0, 0.6); stroke: "transparent"; lw: 0 }

                Item {
                    id: coverMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    CutFrame { anchors.fill: parent; cut: 9; fill: "black"; stroke: "transparent"; lw: 0 }
                }
                Image {
                    anchors.fill: parent
                    visible: String(source) !== ""
                    source: panel.hasPlayer ? String(panel.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 0.25
                        colorizationColor: panel.accent
                        maskEnabled: true
                        maskSource: coverMask
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !panel.hasPlayer || String(panel.player.trackArtUrl || "") === ""
                    text: "///"
                    color: panel.accent
                    opacity: 0.6
                    font.family: panel.pal.font
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                CutFrame { anchors.fill: parent; cut: 9; lw: 1.5; stroke: panel.accent }
            }

            Column {
                id: info
                width: content.width - cover.x - panel.coverW - topRow.spacing
                y: panel.ghost
                spacing: 3

                Text {
                    width: parent.width
                    text: "AUDIO // " + (panel.hasPlayer ? String(panel.player.identity).toUpperCase() : "OFFLINE")
                    color: panel.pal.red
                    opacity: 0.7
                    elide: Text.ElideRight
                    font.family: panel.pal.font
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 2.5
                }

                Row {
                    spacing: 8
                    height: 17
                    CutFrame {
                        width: 17
                        height: 17
                        cut: 4
                        lw: 1.2
                        stroke: panel.accent
                        Text {
                            anchors.centerIn: parent
                            text: panel.playing ? ">" : "="
                            color: panel.accent
                            font.family: panel.pal.font
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: !panel.hasPlayer ? "NO SIGNAL" : (panel.playing ? "NOW PLAYING" : "PAUSED")
                        color: panel.accent
                        font.family: panel.pal.font
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 3
                        layer.enabled: true
                        layer.effect: Glow { tint: panel.accent }
                    }
                }

                Text {
                    width: parent.width
                    text: panel.hasPlayer && panel.player.trackTitle !== "" ? panel.player.trackTitle : "---"
                    color: panel.pal.ink
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: panel.pal.font
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    layer.enabled: true
                    layer.effect: Glow { tint: panel.pal.ink }
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: panel.hasPlayer ? String(panel.player.trackArtist || "") : ""
                    color: panel.pal.cyan
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: panel.pal.font
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    font.letterSpacing: 2.5
                    font.capitalization: Font.AllUppercase
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: panel.hasPlayer ? String(panel.player.trackAlbum || "") : ""
                    color: panel.pal.dim
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: panel.pal.font
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6
                }
            }
        }

        // progress: 1:23 ▮▮▮▮▮▯▯▯▯ 3:45   (click or drag to seek)
        Row {
            spacing: 10
            height: 12

            Text {
                width: 32
                anchors.verticalCenter: parent.verticalCenter
                text: panel.fmt(bar.scrubbing ? bar.scrubRatio * panel.length : panel.pos)
                color: bar.scrubbing ? panel.accent : panel.pal.dim
                font.family: panel.pal.font
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1
            }

            Item {
                id: bar
                width: content.width - 32 * 2 - 10 * 2
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                readonly property int segs: 36
                readonly property real gap: 2
                readonly property real segW: (width - gap * (segs - 1)) / segs
                // while dragging, the bar follows the cursor instead of the player position
                property bool scrubbing: false
                property real scrubRatio: 0
                readonly property real shownRatio: scrubbing ? scrubRatio : panel.ratio
                readonly property int head: Math.min(segs - 1, Math.floor(shownRatio * segs))

                Repeater {
                    model: bar.segs
                    Rectangle {
                        required property int index
                        x: index * (bar.segW + bar.gap)
                        width: bar.segW
                        height: index === bar.head ? (bar.scrubbing ? 12 : 10) : 5
                        y: (bar.height - height) / 2
                        color: panel.accent
                        opacity: index <= bar.head ? 1.0 : 0.18
                        Behavior on height { NumberAnimation { duration: 90 } }
                    }
                }

                // exact cursor marker + time tooltip, only while dragging
                Item {
                    id: marker
                    visible: bar.scrubbing
                    x: bar.scrubRatio * bar.width
                    width: 0
                    height: bar.height

                    Rectangle {
                        x: -1
                        y: -4
                        width: 2
                        height: bar.height + 8
                        color: panel.pal.ink
                        layer.enabled: true
                        layer.effect: Glow { tint: panel.accent }
                    }
                    CutFrame {
                        x: -width / 2
                        y: -height - 8
                        width: tipText.implicitWidth + 14
                        height: 20
                        cut: 5
                        lw: 1.2
                        stroke: panel.accent
                        fill: Qt.rgba(0.03, 0.02, 0.06, 0.92)
                        Text {
                            id: tipText
                            anchors.centerIn: parent
                            text: panel.fmt(bar.scrubRatio * panel.length)
                            color: panel.accent
                            font.family: panel.pal.font
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                        }
                    }
                }
                MouseArea {
                    // taller than the bar so it is easy to grab
                    anchors.fill: parent
                    anchors.topMargin: -8
                    anchors.bottomMargin: -8
                    enabled: panel.hasPlayer && panel.player.canSeek && panel.player.positionSupported && panel.length > 0
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    preventStealing: true

                    function ratioAt(x) { return Math.max(0, Math.min(1, x / bar.width)); }

                    onPressed: mouse => {
                        bar.scrubRatio = ratioAt(mouse.x);
                        bar.scrubbing = true;
                    }
                    onPositionChanged: mouse => {
                        if (bar.scrubbing) bar.scrubRatio = ratioAt(mouse.x);
                    }
                    onReleased: mouse => {
                        if (!bar.scrubbing) return;
                        bar.scrubRatio = ratioAt(mouse.x);
                        panel.player.position = bar.scrubRatio * panel.length;
                        bar.scrubbing = false;
                    }
                    onCanceled: bar.scrubbing = false
                }
            }

            Text {
                width: 32
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
                text: panel.fmt(panel.length)
                color: panel.pal.dim
                font.family: panel.pal.font
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
        }

        // controls: SHUF  |<  >/||  >|  LOOP
        Row {
            spacing: 10

            TButton {
                label: "SHUF"
                col: panel.accent
                fam: panel.pal.font
                active: panel.hasPlayer && panel.player.shuffle
                off: !panel.hasPlayer || !panel.player.shuffleSupported
                onClicked: panel.player.shuffle = !panel.player.shuffle
            }
            TButton {
                kind: "prev"
                col: panel.accent
                fam: panel.pal.font
                off: !panel.hasPlayer || !panel.player.canGoPrevious
                onClicked: panel.player.previous()
            }
            TButton {
                kind: panel.playing ? "pause" : "play"
                hot: true
                col: panel.accent
                fam: panel.pal.font
                off: !panel.hasPlayer || !panel.player.canTogglePlaying
                onClicked: panel.player.togglePlaying()
            }
            TButton {
                kind: "next"
                col: panel.accent
                fam: panel.pal.font
                off: !panel.hasPlayer || !panel.player.canGoNext
                onClicked: panel.player.next()
            }
            TButton {
                label: panel.hasPlayer && panel.player.loopState === MprisLoopState.Track ? "LOOP 1" : "LOOP"
                col: panel.accent
                fam: panel.pal.font
                active: panel.hasPlayer && panel.player.loopState !== MprisLoopState.None
                off: !panel.hasPlayer || !panel.player.loopSupported
                onClicked: {
                    const p = panel.player;
                    if (p.loopState === MprisLoopState.None) p.loopState = MprisLoopState.Playlist;
                    else if (p.loopState === MprisLoopState.Playlist) p.loopState = MprisLoopState.Track;
                    else p.loopState = MprisLoopState.None;
                }
            }
        }
    }
}
