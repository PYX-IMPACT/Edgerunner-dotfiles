// DecryptText.qml - a Text that decrypts in place, like install.sh: scrambled glyphs resolve left to right.
// Set `target` to the real string. It re-runs every time `target` changes, or when you call run().
// Scrambled glyphs use scrambleColor, resolved letters use the normal `color`. Nothing random about colours.
//
//     DecryptText { target: "ACCESS GRANTED"; color: "#6ee7e7"; font.pixelSize: 15 }
import QtQuick

Text {
    id: t
    property string target: ""
    property int stepMs: 22            // ms per frame
    property int perStep: 3            // letters resolved per frame
    property int startDelay: 0         // ms to wait before starting (for staggering)
    property string scrambleColor: "#7a2a2c"
    property int frame: 0

    textFormat: Text.StyledText
    readonly property var glyphs: ["▓", "▒", "░", "█", "▌", "▐", "╳", "┼", "0", "1", "A", "F", "7", "#", "%", "@", "/"]

    function esc(c) { return c === "&" ? "&amp;" : (c === "<" ? "&lt;" : (c === ">" ? "&gt;" : c)) }
    function plain() { var o = ""; for (var i = 0; i < target.length; i++) o += esc(target[i]); return o }
    function render() {
        var out = "", done = frame * perStep
        for (var i = 0; i < target.length; i++) {
            var c = target[i]
            if (i < done || c === " ") out += esc(c)
            else out += "<font color=\"" + scrambleColor + "\">" + glyphs[Math.floor(Math.random() * glyphs.length)] + "</font>"
        }
        text = out
    }
    function begin() { render(); tick.restart() }
    function run() {
        tick.stop(); delayT.stop(); frame = 0
        if (target.length === 0) { text = ""; return }
        if (startDelay > 0) { text = ""; delayT.restart() } else begin()
    }

    Timer { id: delayT; interval: t.startDelay; onTriggered: t.begin() }
    Timer {
        id: tick; interval: t.stepMs; repeat: true
        onTriggered: {
            t.frame++
            if (t.frame * t.perStep >= t.target.length) { tick.stop(); t.text = t.plain() }
            else t.render()
        }
    }
    onTargetChanged: run()
    Component.onCompleted: run()
}
