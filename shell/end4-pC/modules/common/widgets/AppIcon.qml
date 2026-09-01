import QtQuick

Image {
    id: root

    property real implicitSize: 26
    property bool animated: true
    property bool roundToIconSize: false

    width: implicitSize
    height: implicitSize

    asynchronous: true
    cache: true
    fillMode: Image.PreserveAspectFit
    mipmap: true
    smooth: true
}
