import QtQuick
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root
    
    property bool colorize: false
    property color color
    property string source: ""
    property string iconFolder: Qt.resolvedUrl(Quickshell.shellPath("assets/icons"))  // The folder to check first
    width: 30
    height: 30

    function resolvedSource(): string {
        const value = root.source.trim();
        if (value.length === 0)
            return root.iconFolder + "/desktop-symbolic.svg";
        if (value.includes("/") || value.includes(":"))
            return value;

        let fileName = value;
        if (!fileName.endsWith(".svg")) {
            if (!fileName.endsWith("-symbolic"))
                fileName += "-symbolic";
            fileName += ".svg";
        }
        return root.iconFolder + "/" + fileName;
    }
    
    IconImage {
        id: iconImage
        anchors.fill: parent
        source: root.resolvedSource()
        implicitSize: root.height
    }

    Loader {
        active: root.colorize
        anchors.fill: iconImage
        sourceComponent: ColorOverlay {
            source: iconImage
            color: root.color
        }
    }
}
