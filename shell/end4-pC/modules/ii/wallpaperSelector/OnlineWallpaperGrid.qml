import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string provider: "wallhaven"
    property string resolution: "1080p"
    property int columns: Config.options.wallpaperSelector.columns || 4
    property real previewCellAspectRatio: 4 / 3
    property var hoveredItem: null

    signal wallpaperSelected(string path)
    signal updateThumbnailsRequested()

    readonly property bool unsplashMissingKey:
        root.provider === "unsplash" &&
        (KeyringStorage.keyringData?.apiKeys?.unsplash ?? "").length === 0

    readonly property bool missingKey: root.unsplashMissingKey

    onProviderChanged:   { root.hoveredItem = null; _syncAndFetch() }
    onResolutionChanged: _syncAndFetch()

    function _syncAndFetch() {
        if (root.missingKey) return
        OnlineWallpapers.provider   = root.provider
        OnlineWallpapers.resolution = root.resolution
        OnlineWallpapers.fetch()
    }

    function moveSelection(delta) {
        grid.currentIndex = Math.max(0, Math.min(wallpaperModel.count - 1, grid.currentIndex + delta))
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
    }

    function activateCurrent() {
        const item = wallpaperModel.get(grid.currentIndex)
        if (!item) return
        root.downloadItem(item, true)
    }

    function safeIdentifier(value) {
        const sanitized = String(value ?? "").replace(/[^A-Za-z0-9_-]/g, "").slice(0, 96)
        return sanitized.length > 0 ? sanitized : "wallpaper"
    }

    function extensionForUrl(url) {
        const urlLower = String(url ?? "").toLowerCase().split("?")[0]
        return urlLower.includes(".png") ? "png"
            : urlLower.includes(".webp") ? "webp"
            : urlLower.includes(".jpeg") ? "jpg"
            : "jpg"
    }

    function downloadItem(item, applyAfter) {
        if (!item || downloadProc.running) return
        const provider = String(item.provider ?? "")
        if (provider !== "wallhaven" && provider !== "unsplash") return
        const imageUrl = String(item.full ?? "")
        const downloadLocation = String(item.downloadLocation ?? "")
        if (imageUrl.length === 0 || (provider === "unsplash" && downloadLocation.length === 0)) {
            Quickshell.execDetached([
                "notify-send", Translation.tr("Download failed"),
                Translation.tr("The provider did not return a valid download URL"), "-a", "Shell",
            ])
            return
        }

        const ext = root.extensionForUrl(imageUrl)
        const fileName = `${provider}-${root.safeIdentifier(item.id)}.${ext}`
        const picturesPath = Directories.pictures.toString().replace("file://", "")
        const fullPath = `${picturesPath}/Wallpapers/${fileName}`
        downloadProc.filePath = fullPath
        downloadProc.applyAfter = applyAfter
        downloadProc.provider = provider
        const command = [
            "python3",
            Quickshell.shellPath("scripts/wallpapers/download-online-wallpaper.py"),
            "--provider", provider,
            "--url", imageUrl,
            "--output", fullPath,
        ]
        if (provider === "unsplash") {
            command.push("--download-location", downloadLocation)
        }
        downloadProc.command = command
        downloadProc.running = true
    }

    function trustedAttributionUrl(provider, url) {
        const value = String(url ?? "")
        if (provider === "unsplash"
                && /^https:\/\/(www\.)?unsplash\.com(?:[/?#]|$)/.test(value)) {
            return value
        }
        if (provider === "wallhaven"
                && /^https:\/\/(www\.)?wallhaven\.cc(?:[/?#]|$)/.test(value)) {
            return value
        }
        return ""
    }

    function openAttribution(provider, url) {
        const trustedUrl = root.trustedAttributionUrl(provider, url)
        if (trustedUrl.length > 0) Qt.openUrlExternally(trustedUrl)
    }

    Component.onCompleted: _syncAndFetch()

    ListModel { id: wallpaperModel }

    Connections {
        target: OnlineWallpapers
        function onFetched() {
            if (!OnlineWallpapers.appending) {
                wallpaperModel.clear()
                root.hoveredItem = null
            }
            const startIndex = wallpaperModel.count
            for (const item of OnlineWallpapers.results.slice(startIndex)) {
                wallpaperModel.append(item)
            }
        }
        function onFetchError(message) {
            console.log("[OnlineWallpaperGrid] Error:", message)
        }
    }

    Process {
        id: downloadProc
        property string filePath: ""
        property bool applyAfter: false
        property string provider: ""

        environment: ({
            "UIOS_UNSPLASH_CLIENT_ID": downloadProc.provider === "unsplash"
                ? (KeyringStorage.keyringData?.apiKeys?.unsplash ?? "")
                : "",
        })

        stdout: SplitParser {
            onRead: data => console.log("[download]", data)
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                if (applyAfter) root.wallpaperSelected(filePath)
                Wallpapers.setDirectory(Wallpapers.effectiveDirectory)
                Qt.callLater(() => root.updateThumbnailsRequested())
                Quickshell.execDetached(["notify-send",
                    applyAfter ? Translation.tr("Wallpaper applied") : Translation.tr("Download complete"),
                    filePath, "-a", "Shell"
                ])
            } else {
                Quickshell.execDetached(["notify-send",
                    Translation.tr("Download failed"), filePath, "-a", "Shell"
                ])
            }
            downloadProc.provider = ""
        }
    }

    // Missing key
    Item {
        anchors.fill: parent
        visible: root.missingKey

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "key_off"
                iconSize: 48
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Unsplash API key not set")
                font.pixelSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Open the launcher and run:\n/unsplash YOUR_API_KEY")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.normal
                font.family: Appearance.font.family.main
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Get your free key at unsplash.com/developers")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    // Loading
    StyledIndeterminateProgressBar {
        visible: OnlineWallpapers.loading
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: 4
            rightMargin: 4
        }
    }

    // Grid online
    Item {
        id: gridContainer
        anchors.fill: parent
        visible: !root.missingKey

        GridView {
            id: grid
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            visible: wallpaperModel.count > 0

            property int currentIndex: 0

            cellWidth: width / root.columns
            cellHeight: cellWidth / root.previewCellAspectRatio
            interactive: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: wallpaperModel

            delegate: Item {
                id: delegateItem
                required property var model
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight

                Image {
                    id: thumb
                    anchors.fill: parent
                    anchors.margins: Appearance.sizes.wallpaperSelectorItemMargins
                    source: delegateItem.model.thumb
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: thumb.width
                            height: thumb.height
                            radius: Appearance.rounding.normal
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: delegateItem.index === grid.currentIndex
                            ? Qt.rgba(
                                Appearance.colors.colPrimary.r,
                                Appearance.colors.colPrimary.g,
                                Appearance.colors.colPrimary.b, 0.35)
                            : "transparent"
                        border.width: delegateItem.index === grid.currentIndex ? 2 : 0
                        border.color: Appearance.colors.colPrimary
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer2
                        visible: thumb.status !== Image.Ready
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "image"
                            iconSize: 32
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: {
                        grid.currentIndex = delegateItem.index
                        root.hoveredItem = delegateItem.model
                        root.forceActiveFocus()
                    }
                    onClicked: event => {
                        root.downloadItem(delegateItem.model, event.button === Qt.LeftButton)
                    }
                }

                Rectangle {
                    id: attributionBackground
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: Appearance.sizes.wallpaperSelectorItemMargins
                    }
                    height: attributionRow.implicitHeight + 10
                    radius: Appearance.rounding.normal
                    color: Qt.rgba(0, 0, 0, 0.72)
                    visible: delegateItem.model.provider === "unsplash"
                        || delegateItem.model.provider === "wallhaven"
                    z: 3

                    RowLayout {
                        id: attributionRow
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 4

                        StyledText {
                            id: photographerAttribution
                            Layout.fillWidth: true
                            visible: String(delegateItem.model.author ?? "").length > 0
                            text: delegateItem.model.provider === "unsplash"
                                ? Translation.tr("Photo by %1").arg(delegateItem.model.author)
                                : Translation.tr("By %1").arg(delegateItem.model.author)
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.underline: photographerMouse.containsMouse

                            MouseArea {
                                id: photographerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.trustedAttributionUrl(
                                    delegateItem.model.provider,
                                    delegateItem.model.authorUrl
                                ).length > 0
                                onClicked: root.openAttribution(
                                    delegateItem.model.provider,
                                    delegateItem.model.authorUrl
                                )
                            }
                        }

                        StyledText {
                            id: providerAttribution
                            text: delegateItem.model.provider === "unsplash"
                                ? Translation.tr("on Unsplash")
                                : Translation.tr("on Wallhaven")
                            color: Appearance.colors.colOnLayer0
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.underline: providerMouse.containsMouse

                            MouseArea {
                                id: providerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.trustedAttributionUrl(
                                    delegateItem.model.provider,
                                    delegateItem.model.attributionUrl
                                ).length > 0
                                onClicked: root.openAttribution(
                                    delegateItem.model.provider,
                                    delegateItem.model.attributionUrl
                                )
                            }
                        }
                    }
                }
            }

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: grid.width
                    height: grid.height
                    radius: Appearance.rounding.screenRounding + 5
                }
            }
            onContentYChanged: {
                if (!OnlineWallpapers.loading
                    && contentY + height >= contentHeight - cellHeight * 1.5) {
                    OnlineWallpapers.nextPage()
                }
            }
        }

        // Empty state
        ColumnLayout {
            anchors.centerIn: parent
            visible: wallpaperModel.count === 0 && !OnlineWallpapers.loading
            spacing: 12

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "cloud_off"
                iconSize: 48
                color: Appearance.colors.colSubtext
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("No results — try fetching again")
                color: Appearance.colors.colSubtext
            }

            RippleButton {
                Layout.alignment: Qt.AlignHCenter
                implicitHeight: 36
                buttonRadius: height / 2
                colBackground: Appearance.colors.colSecondaryContainer
                onClicked: OnlineWallpapers.fetch()
                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol {
                        text: "refresh"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: Translation.tr("Retry")
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
        }
    }
}
