import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications

// One HUD notification. The look changes with `kind`:
//   call    red portrait, cyan name, red "INCOMING CALL", boxed answer/reject prompts
//   message cyan portrait, "NEW MESSAGE" header
//   job     gold  - default "NEW ..." card (like NEW JOB / TRACK JOB)
//   update  orange - low urgency / finished / saved things (like JOB UPDATED)
//   system  magenta - network, bluetooth, battery, package manager ...
//   alert   red + hazard stripes - critical urgency
// Force a kind from the sender with:  notify-send -h string:x-cp-type:call ...
Item {
    id: card

    required property var notif
    required property var pal

    // ───────────────────────── kind detection ─────────────────────────
    function hint(name) {
        const h = card.notif.hints;
        if (!h) return "";
        const v = h[name];
        return (v === undefined || v === null) ? "" : String(v);
    }

    function actionText() {
        let s = "";
        const a = card.notif.actions;
        for (let i = 0; i < a.length; i++)
            s += " " + a[i].text;
        return s.toLowerCase();
    }

    function detectKind() {
        const n = card.notif;
        const forced = hint("x-cp-type");
        if (["call", "message", "job", "update", "system", "alert"].indexOf(forced) >= 0)
            return forced;
        if (n.urgency === NotificationUrgency.Critical)
            return "alert";

        const app = (String(n.appName || "") + " " + String(n.desktopEntry || "")).toLowerCase();
        const cat = hint("category").toLowerCase();
        const text = (String(n.summary || "") + " " + String(n.body || "")).toLowerCase();
        const acts = actionText();

        if (cat.indexOf("call") === 0
                || /\b(answer|decline|reject|hang ?up|pick ?up)\b/.test(acts)
                || /incoming call|is calling|ringing/.test(text))
            return "call";
        if (cat.indexOf("im") === 0 || cat.indexOf("email") === 0
                || /discord|vesktop|webcord|telegram|signal|whatsapp|element|slack|teams|thunderbird|geary|evolution|mail|messag|fractal|nheko|caprine|zulip/.test(app))
            return "message";
        if (cat.indexOf("network") === 0 || cat.indexOf("device") === 0 || cat.indexOf("power") === 0
                || /networkmanager|nm-applet|network|blueman|bluetooth|upower|battery|udisks|polkit|brightness|volume|pipewire|wireplumber|systemd|pacman|paru|yay|hypr/.test(app))
            return "system";
        if (n.urgency === NotificationUrgency.Low
                || /updat|install|complet|finish|done|synced|saved|copied|download|screenshot|success/.test(text))
            return "update";
        return "job";
    }

    readonly property string kind: detectKind()
    readonly property bool portrait: kind === "call" || kind === "message"

    readonly property color accent: kind === "job" ? pal.gold
                                  : kind === "update" ? pal.orange
                                  : kind === "message" ? pal.cyan
                                  : kind === "system" ? pal.magenta
                                  : pal.red
    readonly property color titleColor: kind === "call" ? pal.cyan : pal.ink
    readonly property string label: ({
        "job": "NEW NOTICE", "update": "UPDATED", "message": "NEW MESSAGE",
        "system": "SYSTEM", "alert": "WARNING", "call": "INCOMING CALL"
    })[kind]
    readonly property string glyph: ({
        "job": "+", "update": ">", "message": "@", "system": "#", "alert": "!", "call": "T"
    })[kind]

    // little tag line: TRN_DISCORD_B02D95 for people, CONNECTION 201.89.43 for the rest
    readonly property string tag: {
        const id = Number(notif.id) || 0;
        if (portrait) {
            const h = ("000000" + ((id * 2654435761) % 16777216).toString(16)).slice(-6).toUpperCase();
            const app = String(notif.appName || "SYS").toUpperCase().replace(/[^A-Z0-9]+/g, "_").slice(0, 10);
            return "TRN_" + app + "_" + h;
        }
        const p2 = n => ("0" + n).slice(-2);
        return "CONNECTION " + (100 + (id * 37) % 156) + "." + p2((id * 91) % 100) + "." + p2((id * 13) % 100);
    }

    // ───────────────────────── image / icon ─────────────────────────
    // Resolve an icon name / path to something loadable, or "" if it doesn't exist.
    // Never hand an unchecked name to the image provider: it answers with the
    // purple/black "missing texture" checkerboard instead of failing.
    function resolveIcon(name) {
        let n = String(name || "");
        if (n === "") return "";
        if (n.indexOf("image://icon/") === 0)
            n = n.slice("image://icon/".length).split("?")[0];
        if (n.indexOf("file://") === 0) return n;
        if (n.charAt(0) === "/") return "file://" + n;
        return Quickshell.iconPath(n, true);      // "" when the theme has no such icon
    }

    readonly property string imgSrc: {
        const img = String(notif.image || "");
        // real pictures (album art, avatars, screenshots) are used as-is
        if (img !== "" && img.indexOf("image://icon/") !== 0)
            return img;
        // otherwise try the icon names in order; first one that really exists wins
        const cands = [img, notif.appIcon, notif.desktopEntry, String(notif.appName || "").toLowerCase()];
        for (let i = 0; i < cands.length; i++) {
            const r = resolveIcon(cands[i]);
            if (r !== "") return r;
        }
        return "";      // -> falls back to the big letter
    }
    readonly property bool hasImg: imgSrc !== ""

    // ───────────────────────── actions ─────────────────────────
    readonly property int actionCount: {
        let c = 0;
        for (let i = 0; i < notif.actions.length; i++)
            if (String(notif.actions[i].text) !== "") c++;
        return c;
    }

    // ───────────────────────── geometry ─────────────────────────
    readonly property real iconW: portrait ? 56 : 46
    readonly property real iconH: portrait ? 72 : 58
    readonly property real ghost: 14      // how far the stacked frames recede up-left
    readonly property real padV: 14
    readonly property real iconR: 26      // gap between icon and the card's right edge
    readonly property real textX: 22
    readonly property real textR: iconR + iconW + 18   // space reserved on the right for the icon

    height: Math.max(textCol.implicitHeight, iconH + ghost) + padV * 2

    // ───────────────────────── lifetime ─────────────────────────
    property real life: 1
    readonly property int lifetime: notif.expireTimeout > 0 ? notif.expireTimeout * 1000
                                                             : (kind === "alert" ? 12000 : 6000)
    NumberAnimation on life {
        from: 1
        to: 0
        duration: card.lifetime
        running: true
        paused: hover.hovered       // hovering a card keeps it alive
        onFinished: card.notif.expire()
    }
    HoverHandler { id: hover }

    // glitchy slide-in from the right
    opacity: 0
    transform: Translate {
        id: slide
        x: 70
    }
    ParallelAnimation {
        running: true
        NumberAnimation { target: slide; property: "x"; to: 0; duration: 260; easing.type: Easing.OutCubic }
        SequentialAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 70 }
            NumberAnimation { target: card; property: "opacity"; to: 0.3; duration: 60 }
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 60 }
            NumberAnimation { target: card; property: "opacity"; to: 0.55; duration: 40 }
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 90 }
        }
    }

    // soft neon glow for headline text only (kept tight so it never turns into a muddy shadow)
    component Glow: MultiEffect {
        property color tint: "#2de2e6"
        shadowEnabled: true
        shadowColor: tint
        shadowBlur: 0.45
        shadowOpacity: 0.5
        blurMax: 14
    }

    // click anywhere to dismiss (lowest layer so action buttons win)
    MouseArea {
        anchors.fill: parent
        onClicked: card.notif.dismiss()
    }

    // ───────────────────────── backdrop ─────────────────────────
    // crisp dark gradient that fades out toward the left: readable, no blurry box
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0.03, 0.02, 0.06, 0.0) }
            GradientStop { position: 0.3; color: Qt.rgba(0.03, 0.02, 0.06, 0.64) }
            GradientStop { position: 1.0; color: Qt.rgba(0.03, 0.02, 0.06, 0.88) }
        }
    }
    // accent bar on the right edge (pulses on alerts)
    Rectangle {
        x: parent.width - width
        width: 3
        height: parent.height
        color: card.accent
        SequentialAnimation on opacity {
            running: card.kind === "alert"
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 450 }
            NumberAnimation { to: 1.0; duration: 450 }
        }
    }
    // hairline at the top, fading left
    Rectangle {
        width: parent.width
        height: 1
        opacity: 0.45
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: card.accent }
        }
    }
    // time-left line along the bottom (starts full, drains toward the right edge)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: parent.width * card.life
        height: 2
        color: card.accent
        opacity: 0.75
    }
    // hazard stripes for alerts
    Item {
        visible: card.kind === "alert"
        x: 0
        width: parent.width - 3
        height: 5
        clip: true
        Repeater {
            model: Math.ceil(card.width / 10) + 2
            Rectangle {
                required property int index
                x: index * 10 - 4
                y: -3
                width: 4
                height: 12
                rotation: 35
                color: card.pal.red
                opacity: 0.8
            }
        }
    }

    // ───────────────────────── icon / portrait ─────────────────────────
    Item {
        id: icon
        x: card.width - card.iconR - card.iconW
        y: (card.height - height + card.ghost) / 2
        width: card.iconW
        height: card.iconH

        // stacked frames receding up-right
        CutFrame { x: card.ghost;      y: -card.ghost;     width: parent.width; height: parent.height; cut: 9; lw: 1; stroke: card.accent; opacity: 0.2 }
        CutFrame { x: card.ghost / 2;  y: -card.ghost / 2; width: parent.width; height: parent.height; cut: 9; lw: 1; stroke: card.accent; opacity: 0.4 }
        CutFrame { anchors.fill: parent; cut: 9; fill: Qt.rgba(0, 0, 0, 0.55); stroke: "transparent"; lw: 0 }

        Item {
            id: iconMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            CutFrame { anchors.fill: parent; cut: 9; fill: "black"; stroke: "transparent"; lw: 0 }
        }
        Image {
            anchors.fill: parent
            visible: card.hasImg
            source: card.imgSrc
            fillMode: Image.PreserveAspectCrop
            layer.enabled: card.hasImg
            layer.effect: MultiEffect {
                colorization: 0.6
                colorizationColor: card.accent
                maskEnabled: true
                maskSource: iconMask
            }
        }
        // no image: big letter instead
        Text {
            anchors.centerIn: parent
            visible: !card.hasImg
            text: card.kind === "alert" ? "!" : String(card.notif.appName || "?").charAt(0).toUpperCase()
            color: card.accent
            font.family: card.pal.font
            font.pixelSize: card.portrait ? 34 : 28
            font.weight: Font.Bold
            layer.enabled: true
            layer.effect: Glow { tint: card.accent }
        }
        CutFrame { anchors.fill: parent; cut: 9; lw: 1.5; stroke: card.accent }
    }

    // little HUD detail, top left
    Text {
        anchors.left: parent.left
        anchors.leftMargin: 10
        y: 4
        text: "///"
        color: card.accent
        opacity: 0.5
        font.family: card.pal.font
        font.pixelSize: 10
        font.weight: Font.Bold
    }

    // ───────────────────────── text ─────────────────────────
    Column {
        id: textCol
        x: card.textX
        y: card.padV + (card.height - card.padV * 2 - height) / 2
        width: card.width - card.textX - card.textR
        spacing: 3

        // tag line
        Text {
            width: parent.width
            text: card.tag
            horizontalAlignment: Text.AlignRight
            color: card.portrait ? card.pal.cyan : card.pal.red
            opacity: 0.7
            elide: Text.ElideRight
            font.family: card.pal.font
            font.pixelSize: 9
            font.weight: Font.Bold
            font.letterSpacing: 2.5
        }

        // header: [+] NEW NOTICE
        Row {
            visible: card.kind !== "call"
            layoutDirection: Qt.RightToLeft
            x: parent.width - width
            spacing: 8
            height: 17

            CutFrame {
                width: 17
                height: 17
                cut: 4
                lw: 1.2
                stroke: card.accent
                Text {
                    anchors.centerIn: parent
                    text: card.glyph
                    color: card.accent
                    font.family: card.pal.font
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card.label
                color: card.accent
                font.family: card.pal.font
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 3
                layer.enabled: true
                layer.effect: Glow { tint: card.accent }
            }
        }

        // title
        Text {
            width: parent.width
            text: card.notif.summary
            horizontalAlignment: Text.AlignRight
            color: card.titleColor
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: card.pal.font
            font.pixelSize: 20
            font.weight: Font.DemiBold
            font.letterSpacing: 1.5
            font.capitalization: Font.AllUppercase
            layer.enabled: true
            layer.effect: Glow { tint: card.titleColor }
        }

        // calls: red sub-line (the body, or INCOMING CALL if empty)
        Text {
            visible: card.kind === "call"
            width: parent.width
            text: card.notif.body !== "" ? card.notif.body : "INCOMING CALL"
            horizontalAlignment: Text.AlignRight
            color: card.pal.red
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: card.pal.font
            font.pixelSize: 14
            font.weight: Font.Bold
            font.letterSpacing: 3
            font.capitalization: Font.AllUppercase
            layer.enabled: true
            layer.effect: Glow { tint: card.pal.red }
        }

        // everything else: quiet readable body
        Text {
            visible: card.kind !== "call" && text !== ""
            width: parent.width
            text: card.notif.body
            horizontalAlignment: Text.AlignRight
            color: card.pal.dim
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: card.pal.font
            font.pixelSize: 14
            font.weight: Font.Medium
            font.letterSpacing: 0.6
            lineHeight: 0.95
        }

        // action prompts: [A] ANSWER   [R] REJECT
        Row {
            visible: card.actionCount > 0
            layoutDirection: Qt.RightToLeft
            x: parent.width - width
            topPadding: 7
            spacing: 22

            Repeater {
                model: card.notif.actions

                delegate: MouseArea {
                    id: act
                    required property var modelData
                    visible: String(modelData.text) !== ""
                    width: visible ? actRow.implicitWidth : 0
                    height: 22
                    hoverEnabled: true
                    onClicked: act.modelData.invoke()

                    Row {
                        id: actRow
                        layoutDirection: Qt.RightToLeft
                        spacing: 8
                        opacity: act.containsMouse ? 1.0 : 0.85

                        CutFrame {
                            width: 20
                            height: 20
                            cut: 5
                            lw: 1.2
                            stroke: card.kind === "call" ? card.pal.red : card.pal.cyan
                            fill: act.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: String(act.modelData.text).charAt(0).toUpperCase()
                                color: card.kind === "call" ? card.pal.red : card.pal.cyan
                                font.family: card.pal.font
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: act.modelData.text
                            color: card.kind === "call" ? card.pal.cyan : card.pal.red
                            font.family: card.pal.font
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            font.letterSpacing: 2.5
                            font.capitalization: Font.AllUppercase
                        }
                    }
                }
            }
        }
    }
}
