// GlitchText.qml - text that types in letter by letter, then randomly flickers.
// Drop it next to your Quickshell widgets and use it anywhere you'd use Text:
//
//     GlitchText { text: "UPGRADE U"; color: "#ffffff"; font.pixelSize: 20; font.letterSpacing: 2 }
//     GlitchText { text: model.title; charDelay: 18; flickerMin: 1500; flickerMax: 5000 }
//
// Changing `text` re-types it from the start (nice for new notifications / track changes).
import QtQuick

Item {
    id: root
    property string text: ""
    property color color: "#ffffff"
    property color glitchColor: "#ff1f3d"
    property alias font: label.font
    property int charDelay: 28        // ms per letter
    property int flickerMin: 2500     // random gap between flickers (ms)
    property int flickerMax: 7000
    property bool flicker: true

    readonly property var glyphs: ["▓", "▒", "░", "█", "▌", "▐", "╳", "┼", "0", "1", "A", "F", "7", "#", "%", "&", "@", "/"]
    property int shown: 0
    property bool hit: false          // true for a few frames during a flicker

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    function g() { return glyphs[Math.floor(Math.random() * glyphs.length)] }
    function render() {
        var s = text, out = ""
        if (shown >= s.length) {
            if (!hit) { label.text = s; return }
            for (var i = 0; i < s.length; i++)               // flicker frame: corrupt ~18% of letters
                out += (s[i] !== " " && Math.random() < 0.18) ? g() : s[i]
            label.text = out
            return
        }
        out = s.substring(0, shown)
        if (shown < s.length && s[shown] !== " ") out += g()   // glitching lead character
        label.text = out
    }

    Text { id: ghost; x: root.hit ? 2 : 0; y: root.hit ? -1 : 0; color: root.glitchColor
           opacity: root.hit ? 0.85 : 0; font: label.font; text: label.text }
    Text { id: label; color: root.hit ? root.glitchColor : root.color; text: "" }

    Timer {
        id: typer
        interval: root.charDelay; repeat: true
        onTriggered: { root.shown++; root.render(); if (root.shown >= root.text.length) stop() }
    }
    Timer {
        id: hitTimer                    // 3 quick flicker frames
        property int n: 0
        interval: 45; repeat: true
        onTriggered: { n++; root.hit = (n % 2 === 1); root.render(); if (n >= 5) { stop(); root.hit = false; root.render() } }
    }
    Timer {
        id: nextFlicker
        interval: root.flickerMin + Math.random() * (root.flickerMax - root.flickerMin)
        running: root.flicker && root.shown >= root.text.length && root.text.length > 0
        repeat: true
        onTriggered: { hitTimer.n = 0; hitTimer.start(); interval = root.flickerMin + Math.random() * (root.flickerMax - root.flickerMin) }
    }

    onTextChanged: { shown = 0; hit = false; render(); typer.restart() }
    Component.onCompleted: { render(); if (text.length > 0) typer.start() }
}
