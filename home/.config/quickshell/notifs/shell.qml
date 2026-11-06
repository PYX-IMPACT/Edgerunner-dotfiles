import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris

// Cyberpunk-style HUD notifications. Place at ~/.config/quickshell/notifs/shell.qml
//   right side : notification cards (NotifCard.qml)
//   left side  : NOW PLAYING card for Spotify (MediaPanel.qml) - music notifications go here instead
// Toggle the music card:  qs -c notifs ipc call media toggle
ShellRoot {
    id: root

    // ───────── palette / font: tweak here ─────────
    readonly property var pal: ({
        "cyan": "#2de2e6",
        "red": "#ff4d4d",
        "gold": "#f5c542",
        "orange": "#ff8a3d",
        "magenta": "#d65cff",
        "ink": "#f4f1ea",
        "dim": "#b9b4c6",
        "font": "Rajdhani"
    })
    readonly property int pad: 16   // transparent margin inside the windows so glows are not clipped

    // which MPRIS player the NOW PLAYING card follows
    readonly property string playerMatch: "spotify"
    readonly property var player: {
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; i++) {
            const id = (String(list[i].identity) + " " + String(list[i].desktopEntry)).toLowerCase();
            if (id.indexOf(root.playerMatch) >= 0)
                return list[i];
        }
        return null;
    }

    // notifications from music apps never reach the right-hand stack
    function isMusic(n) {
        const app = (String(n.appName || "") + " " + String(n.desktopEntry || "")).toLowerCase();
        return /spotify|spotifyd|ncspot|rhythmbox|lollypop|amberol|deadbeef|cider|tidal|strawberry|audacious|clementine|mpd|music/.test(app);
    }

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: notif => {
            if (root.isMusic(notif)) {
                mediaPanel.peek();      // untracked = dropped; the music card shows it instead
                return;
            }
            notif.tracked = true;
        }
    }

    // pop the music card for a few seconds whenever the track changes
    Connections {
        target: root.player
        function onTrackTitleChanged() {
            if (root.player && root.player.trackTitle !== ""
                    && root.player.playbackState === MprisPlaybackState.Playing)
                mediaPanel.peek();
        }
    }

    IpcHandler {
        target: "media"
        function toggle(): void { mediaPanel.toggle(); }
        function show(): void { mediaPanel.show(); }
        function hide(): void { mediaPanel.hide(); }
    }

    // ───────── right: notifications ─────────
    PanelWindow {
        visible: server.trackedNotifications.values.length > 0
        anchors {
            top: true
            right: true
        }
        margins {
            top: 14
            right: 14
        }
        implicitWidth: 380 + root.pad * 2
        implicitHeight: column.implicitHeight + root.pad * 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: column }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "cp-notifs"

        Column {
            id: column
            x: root.pad
            y: root.pad
            width: 380
            spacing: 16

            Repeater {
                model: server.trackedNotifications

                delegate: NotifCard {
                    required property var modelData
                    notif: modelData
                    pal: root.pal
                    width: column.width
                }
            }
        }
    }

    // ───────── left: now playing ─────────
    PanelWindow {
        visible: mediaPanel.opacity > 0.01
        anchors {
            left: true
        }
        margins {
            left: 14
        }
        implicitWidth: mediaPanel.width + root.pad * 2
        implicitHeight: mediaPanel.height + root.pad * 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: mediaPanel }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "cp-media"

        MediaPanel {
            id: mediaPanel
            x: root.pad
            y: root.pad
            pal: root.pal
            player: root.player
        }
    }
}
