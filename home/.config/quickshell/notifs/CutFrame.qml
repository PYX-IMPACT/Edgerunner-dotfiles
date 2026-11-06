import QtQuick
import QtQuick.Shapes

// rectangle outline/fill with the top-right and bottom-left corners cut off
// (set mirror: true to cut top-left and bottom-right instead)
Shape {
    id: frame

    property color stroke: "#ff4d4d"
    property color fill: "transparent"
    property real cut: 12
    property real lw: 2
    readonly property real inset: lw / 2
    property bool mirror: false
    function mx(v) { return mirror ? width - v : v }

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: frame.stroke
        strokeWidth: frame.lw
        fillColor: frame.fill
        startX: frame.mx(frame.inset)
        startY: frame.inset
        PathLine { x: frame.mx(frame.width - frame.cut); y: frame.inset }
        PathLine { x: frame.mx(frame.width - frame.inset); y: frame.cut }
        PathLine { x: frame.mx(frame.width - frame.inset); y: frame.height - frame.inset }
        PathLine { x: frame.mx(frame.cut); y: frame.height - frame.inset }
        PathLine { x: frame.mx(frame.inset); y: frame.height - frame.cut }
        PathLine { x: frame.mx(frame.inset); y: frame.inset }
    }
}
