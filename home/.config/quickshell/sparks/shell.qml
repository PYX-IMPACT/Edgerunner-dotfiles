// ~/.config/quickshell/sparks/shell.qml   (repo: home/.config/quickshell/sparks/)
// Universal red spark: a click-through fullscreen overlay that a rigid HUD (spiked red trace, yellow brackets, cyan ticks, typed label)
// when windows open / close / toggle floating / move workspace, and when the SUPER+R menu opens.
// Runs as its own Quickshell instance:   quickshell -c sparks
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "sparklib.js" as Lib

ShellRoot {
    id: root

    property var geo: ({ x: 0, y: 0, w: 0, h: 0 })   // last known active-window rect (global coords)
    property string pending: ""                      // effect to fire when the next query returns
    property double lastBurst: 0
    property bool settled: false                     // true only for the query started by the settle delay
    signal burst(var rect, string kind, var extra)

    function fire(rect, kind, extra) {
        var now = Date.now()
        if (kind !== "ws") {
            if (now - lastBurst < 60) return          // debounce event storms (workspace swipes are exempt)
            lastBurst = now
        }
        burst(rect, kind, extra)
    }

    // ---- workspace swipe: sweep direction follows which way the workspace number went
    property int lastWs: 0
    function onWorkspace(d) {
        var id = parseInt(d.split(",")[0])
        if (isNaN(id) || id <= 0 || id === lastWs) return
        var dir = id > lastWs ? -1 : 1
        lastWs = id
        fire({ x: 0, y: 0, w: 0, h: 0 }, "ws", { dir: dir, text: "// WS " + (id < 10 ? "0" : "") + id })
    }

    // ---- 4-finger move: hyprland sends no event while a window is dragged, so watch the active window.
    // Only a floating window that changes position (same size) counts as "moved". Costs one tiny hyprctl call
    // per 100ms; set moveWatch to false to turn it off.
    property bool moveWatch: true
    property var wprev: null
    property bool moving: false
    property int still: 0
    Process {
        id: mq
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector { onStreamFinished: root.poll(this.text) }
    }
    Timer { interval: 100; repeat: true; running: root.moveWatch; onTriggered: mq.running = true }
    function poll(text) {
        var o
        try { o = JSON.parse(text) } catch (e) { wprev = null; return }
        if (!o || !o.at || !o.size) { wprev = null; moving = false; return }
        var cur = { a: o.address, x: o.at[0], y: o.at[1], w: o.size[0], h: o.size[1], fl: o.floating }
        var p = wprev
        wprev = cur
        geo = { x: cur.x, y: cur.y, w: cur.w, h: cur.h }
        if (!p || p.a !== cur.a || !cur.fl) { moving = false; still = 0; return }
        var moved = (p.x !== cur.x || p.y !== cur.y) && p.w === cur.w && p.h === cur.h
        if (moved) {
            moving = true; still = 0
            burst({ x: p.x, y: p.y, w: p.w, h: p.h }, "ghost", null)      // trail at the spot it just left
        } else if (moving) {
            still++
            if (still >= 2) { moving = false; still = 0; fire(geo, "move") }   // dropped
        }
    }

    // Ask Hyprland for the active window rectangle.
    Process {
        id: query
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                var o
                try { o = JSON.parse(this.text) } catch (e) { return }
                if (!o || !o.at || !o.size) return
                root.geo = { x: o.at[0], y: o.at[1], w: o.size[0], h: o.size[1] }
                if (root.pending !== "" && root.settled) {
                    root.settled = false
                    var k = root.pending
                    root.pending = ""
                    root.fire(root.geo, k)
                }
            }
        }
    }
    // Real rectangle of the launcher layer (hyprctl layers), so the menu effect hugs the actual panel.
    property var lrect: null
    Process {
        id: lq
        command: ["hyprctl", "-j", "layers"]
        stdout: StdioCollector {
            onStreamFinished: {
                var o
                try { o = JSON.parse(this.text) } catch (e) { return }
                for (var mon in o) {
                    var lv = o[mon].levels
                    for (var k in lv) {
                        for (var i = 0; i < lv[k].length; i++) {
                            var l = lv[k][i]
                            if (l.namespace === "launcher" || l.namespace === "rofi") {
                                root.lrect = { x: l.x, y: l.y, w: l.w, h: l.h }
                                root.fire(root.lrect, "menu")
                                return
                            }
                        }
                    }
                }
            }
        }
    }
    Timer { id: ldelay; interval: 45; onTriggered: lq.running = true }

    // Fast path for new windows: find the window by its address (no waiting for focus to move) and fire right away.
    property string openAddr: ""
    property int openTries: 0
    Process {
        id: cq
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                var arr
                try { arr = JSON.parse(this.text) } catch (e) { return }
                for (var i = 0; i < arr.length; i++) {
                    var c = arr[i]
                    if (c.address === root.openAddr && c.at && c.size && c.size[0] > 50 && c.size[1] > 50) {
                        root.geo = { x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1] }
                        root.fire(root.geo, "open")
                        return
                    }
                }
                if (root.openTries < 3) { root.openTries++; retry.restart() }   // not listed or sized yet: ask again shortly
            }
        }
    }
    Timer { id: retry; interval: 25; onTriggered: cq.running = true }
    function openFast(data) {
        openAddr = "0x" + data.split(",")[0]
        openTries = 0
        cq.running = true
    }

    // The launcher calls this the moment it starts closing, so the close effect does not wait for the layer to unmap.
    property bool menuEarlyClose: false
    Timer { id: ecClear; interval: 1500; onTriggered: root.menuEarlyClose = false }
    IpcHandler {
        target: "sparks"
        function menuclose(): void {
            if (!root.lrect) return
            root.menuEarlyClose = true
            ecClear.restart()
            root.fire(root.lrect, "close")
        }
    }

    Timer { id: delay; interval: 25; onTriggered: { root.settled = true; query.running = true } }
    function ask(kind) { pending = kind; delay.restart() }      // fire an effect after the layout settles
    function refresh() { query.running = true }                 // just update the cached rect, never touches pending

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":         root.openFast(event.data); break  // look the window up by address and fire at once
            case "closewindow":        root.fire(root.geo, "close"); break   // use the cached rect: window is gone
            case "changefloatingmode": root.ask(event.data.split(",")[1] === "1" ? "float" : "tile"); break
            case "movewindowv2":       root.ask("move"); break
            case "activewindowv2":     root.refresh(); break
            case "workspacev2":        root.onWorkspace(event.data); break               // just refresh the cached rect
            case "openlayer":          if (event.data === "launcher" || event.data === "rofi") ldelay.restart(); break      // wait for the panel to size itself
            case "closelayer":
                if ((event.data === "launcher" || event.data === "rofi") && root.lrect) {
                    if (root.menuEarlyClose) root.menuEarlyClose = false       // already fired when the menu began closing
                    else root.fire(root.lrect, "close")
                }
                break
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "edgerunner-sparks"
            mask: Region {}                       // empty input region = fully click-through

            Canvas {
                id: cv
                anchors.fill: parent
                property var pool: ({})
                property bool live: false
                onPaint: live = Lib.draw(getContext("2d"), pool, width, height, Date.now())
            }
            Timer {                               // only ticks while something is on screen
                interval: 16; repeat: true; running: cv.live
                onTriggered: cv.requestPaint()
            }

            Connections {
                target: root
                function onBurst(rect, kind, extra) {
                    if (kind === "ws") {                          // full-screen effect on the focused monitor only
                        var fm = Hyprland.focusedMonitor
                        if (fm && fm.name !== win.modelData.name) return
                        Lib.burst(cv.pool, { x: 0, y: 0, w: win.width, h: win.height }, "ws", Date.now(), extra)
                        cv.live = true
                        cv.requestPaint()
                        return
                    }
                    var r = { x: rect.x - win.modelData.x, y: rect.y - win.modelData.y, w: rect.w, h: rect.h }
                    if (r.x + r.w < 0 || r.y + r.h < 0 || r.x > win.width || r.y > win.height) return   // on another screen
                    Lib.burst(cv.pool, r, kind, Date.now(), extra)
                    cv.live = true
                    cv.requestPaint()
                }
            }
        }
    }
}
