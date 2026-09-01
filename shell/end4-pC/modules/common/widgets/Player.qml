pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root
    required property MprisPlayer player
    property bool presentationActive: true
    property bool componentReady: false
    property bool positionUpdatesAcquired: false

    function syncPositionUpdates() {
        if (!root.componentReady
                || root.presentationActive === root.positionUpdatesAcquired)
            return
        if (root.presentationActive)
            MprisController.acquirePositionUpdates()
        else
            MprisController.releasePositionUpdates()
        root.positionUpdatesAcquired = root.presentationActive
    }

    Component.onCompleted: {
        root.componentReady = true
        root.syncPositionUpdates()
        root.refreshArtwork()
    }
    Component.onDestruction: {
        if (root.positionUpdatesAcquired)
            MprisController.releasePositionUpdates()
    }
    onPresentationActiveChanged: {
        root.syncPositionUpdates()
        if (root.componentReady && root.presentationActive)
            root.refreshArtwork()
    }

    property var artUrl: player?.trackArtUrl ?? ""
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: ColorUtils.mix(
        (colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary),
        Appearance.colors.colPrimaryContainer,
        0.8) || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: false
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000
    property int visualizerSmoothing: 2
    property real radius
    property bool showLyrics: false

    property string resolvedArtFilePath: {
        if (!root.downloaded) return ""
        if (root.artUrl.startsWith("file://")) return root.artUrl
        return Qt.resolvedUrl(artFilePath)
    }
    property string displayedArtFilePath: root.presentationActive
        ? root.resolvedArtFilePath : ""

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: artDominantColor
    }

    function refreshArtwork() {
        if (!root.artUrl || root.artUrl.length === 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer
            root.downloaded = false
            return
        }

        if (root.artUrl.startsWith("file://")) {
            root.downloaded = true
            return
        }

        if (root.downloaded) return
        root.downloaded = false
        if (!root.presentationActive) return
        coverArtDownloader.targetFile = root.artUrl
        coverArtDownloader.artFilePath = root.artFilePath
        coverArtDownloader.running = true
    }
    onArtFilePathChanged: {
        if (!root.componentReady) return
        root.downloaded = false
        root.refreshArtwork()
    }

    Process {
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: ["bash", "-c", `[ -f ${artFilePath} ] || curl -4 -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: (exitCode, exitStatus) => {
            root.downloaded = true
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.resolvedArtFilePath
        depth: 0
        rescaleSize: 1
    }

    StyledRectangularShadow {
        target: background
    }

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        color: ColorUtils.applyAlpha(blendedColors.colLayer0, 1)
        radius: root.radius

        layer.enabled: root.presentationActive
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        Image {
            id: blurredArt
            anchors.fill: parent
            source: root.presentationActive ? root.displayedArtFilePath : ""
            sourceSize.width: background.width
            sourceSize.height: background.height
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true

            layer.enabled: root.presentationActive
            layer.effect: StyledBlurEffect {
                source: blurredArt
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
                radius: root.radius
            }
        }

        WaveVisualizer {
            id: visualizerCanvas
            anchors.fill: parent
            renderActive: root.presentationActive
            live: root.presentationActive && root.player?.isPlaying
            points: root.visualizerPoints
            maxVisualizerValue: root.maxVisualizerValue
            smoothing: root.visualizerSmoothing
            color: blendedColors.colPrimary
        }

        Loader {
            id: layoutLoader
            anchors.fill: parent
            // The default controls remain cached, but an open lyrics view owns
            // a LyricsService consumer and must be released while off-screen.
            active: root.presentationActive || !root.showLyrics

            sourceComponent: root.showLyrics ? lyricsComponent : controlsComponent

            Component {
                id: controlsComponent
                PlayerControls {
                    player: root.player
                    presentationActive: root.presentationActive
                    blendedColors: root.blendedColors
                    displayedArtFilePath: root.displayedArtFilePath
                    radius: root.radius
                    onToggleLyrics: root.showLyrics = !root.showLyrics
                }
            }

            Component {
                id: lyricsComponent
                PlayerControlsLyrics {
                    player: root.player
                    presentationActive: root.presentationActive
                    blendedColors: root.blendedColors
                    displayedArtFilePath: root.displayedArtFilePath
                    radius: root.radius
                    artDominantColor: root.artDominantColor
                    onToggleLyrics: root.showLyrics = !root.showLyrics
                }
            }
        }
    }
}
