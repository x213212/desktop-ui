import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.panels.lock
import qs.modules.ii.bar as Bar
import Quickshell
import Quickshell.Services.SystemTray

MouseArea {
    id: root
    required property LockContext context
    property bool active: false
    property bool showInputField: active || context.currentText.length > 0
    // User-selected lock-only scale.  Keeping this local prevents the desktop
    // bar and application typography from being enlarged as a side effect.
    readonly property real lockFontScale: 1.0
    readonly property bool requirePasswordToPower: Config.options.lock.security.requirePasswordToPower
    readonly property MprisPlayer activePlayer: {
        const preferred = Config.options.bar.media.preferredPlayer.trim().toLowerCase()
        if (preferred.length === 0) return MprisController.activePlayer
        const _ = MprisController.players.count
        for (const p of MprisController.players) {
            if ((p.identity ?? "").toLowerCase().includes(preferred) ||
                (p.desktopEntry ?? "").toLowerCase().includes(preferred))
                return p
        }
        return MprisController.activePlayer
    }

    property var    artUrl:      activePlayer?.trackArtUrl ?? ""

    // Force focus on entry
    function forceFieldFocus() {
        passwordBox.forceActiveFocus();
    }
    Connections {
        target: context
        function onShouldReFocus() {
            forceFieldFocus();
        }
    }
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: mouse => {
        forceFieldFocus();
    }
    onPositionChanged: mouse => {
        forceFieldFocus();
    }

    // Toolbar appearing animation
    property real toolbarScale: 0.9
    property real toolbarOpacity: 0
    Behavior on toolbarScale {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
        }
    }
    Behavior on toolbarOpacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    // Init
    Component.onCompleted: {
        forceFieldFocus();
        toolbarScale = 1;
        toolbarOpacity = 1;
    }

    // Key presses
    property bool ctrlHeld: false
    Keys.onPressed: event => {
        root.context.resetClearTimer();
        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = true;
        }
        if (event.key === Qt.Key_Escape) { // Esc to clear
            root.context.currentText = "";
        } 
        forceFieldFocus();
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = false;
        }
        forceFieldFocus();
    }

    // RippleButton {
    //     anchors {
    //         top: parent.top
    //         left: parent.left
    //         leftMargin: 10
    //         topMargin: 10
    //     }
    //     implicitHeight: 40
    //     colBackground: Appearance.colors.colLayer2
    //     onClicked: {
    //         context.unlocked(LockContext.ActionEnum.Unlock);
    //         GlobalStates.screenLocked = false;
    //     }
    //     contentItem: StyledText {
    //         text: "[[ DEBUG BYPASS ]]"
    //     }
    // }

    Loader {
        anchors.fill: parent
        z: -1
        // A session-lock surface does not inherit the desktop wallpaper.
        // Render the selected desktop image on every compositor so Hyprland
        // does not fall back to a blank/solid lock background.
        active: true

        sourceComponent: Image {
            anchors.fill: parent
            source: (Config.options.background.lockWall || Config.options.background.wallpaperPath).length > 0
                ? (Config.options.background.lockWall || Config.options.background.wallpaperPath)
                : Qt.resolvedUrl("../../../assets/images/default_wallpaper.png")
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            retainWhileLoading: true
        }
    }

    LockWeatherEffects {
        anchors.fill: parent
        z: -0.5
    }

    // Lightweight live weather: reuses the bar service, so locking adds no polling.
    Toolbar {
        id: weatherIsland
        visible: Config.options.lock.showToolbars
        implicitWidth: Math.min(900, Math.max(520, root.width - 48))
        implicitHeight: 140
        padding: 14
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 32
        }
        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                    iconSize: 34 * root.lockFontScale
                    fill: 1
                    color: Appearance.colors.colPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledText {
                    text: `${Weather.data?.city ?? "目前位置"} · ${Weather.data?.description ?? "讀取中"}`
                    font.pixelSize: 22 * root.lockFontScale
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                StyledText {
                    text: Weather.data?.temp ?? "--°"
                    font.pixelSize: 34 * root.lockFontScale
                    font.weight: Font.Light
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: 16 * root.lockFontScale
                color: Appearance.colors.colOnSurfaceVariant
                text: {
                    const probability = Number(Weather.data?.rainProbability ?? -1)
                    const probabilityText = probability >= 0 ? `${probability}%` : "--"
                    const rainTime = Weather.data?.nextRainTime
                        ? `${Weather.data.nextRainTime} 前後` : "一小時內"
                    return `體感 ${Weather.data?.tempFeelsLike ?? "--°"} · 短時降水 ${probabilityText}（${rainTime}） · 濕度 ${Weather.data?.humidity ?? "--"} · 風速 ${Weather.data?.wind ?? "--"}`
                }
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: 14 * root.lockFontScale
                color: Appearance.colors.colSubtext
                text: `近 15 分鐘雨量 ${Weather.data?.precip ?? "--"} · 氣壓 ${Weather.data?.press ?? "--"} · 能見度 ${Weather.data?.visib ?? "--"} · 日出 ${Weather.data?.sunrise ?? "--"} · 日落 ${Weather.data?.sunset ?? "--"} · 更新 ${Weather.data?.lastRefresh || "等待資料"}`
            }

            OpenMeteoAttribution {
                Layout.alignment: Qt.AlignHCenter
                interactive: false
                font.pixelSize: 12 * root.lockFontScale
                color: Appearance.colors.colSubtext
            }
        }
    }

    // The desktop clock is below the session-lock surface. Bind to the
    // existing DateTime singleton here so the lock owns no extra clock timer.
    Toolbar {
        id: clockIsland
        anchors.centerIn: parent
        implicitWidth: 460
        implicitHeight: 166
        padding: 18
        enableShadow: false
        colBackground: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, 0.08)
        radius: 38
        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
            spacing: -4

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: DateTime.time
                font.pixelSize: 92 * root.lockFontScale
                font.weight: Font.Light
                font.features: ({ "tnum": 1 })
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: DateTime.longDate
                font.pixelSize: 25 * root.lockFontScale
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }

    // Main toolbar: password box
    Toolbar {
        id: mainIsland
        implicitHeight: 68
        padding: 10
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 20
        }
        Behavior on anchors.bottomMargin {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        // Fingerprint
        Loader {
            Layout.leftMargin: 10
            Layout.rightMargin: 6
            Layout.alignment: Qt.AlignVCenter
            active: root.context.fingerprintsConfigured
            visible: active

            sourceComponent: MaterialSymbol {
                id: fingerprintIcon
                fill: 1
                text: "fingerprint"
                iconSize: Appearance.font.pixelSize.hugeass * root.lockFontScale
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        ToolbarTextField {
            id: passwordBox
            implicitWidth: 300
            Layout.rightMargin: -Layout.leftMargin
            placeholderText: GlobalStates.screenUnlockFailed ? Translation.tr("Incorrect password") : Translation.tr("Enter password")

            // Style
            clip: true
            font.pixelSize: 18 * root.lockFontScale
            selectedTextColor: materialShapeChars ? "transparent" : Appearance.colors.colOnSecondaryContainer
            selectionColor: materialShapeChars ? "transparent" : Appearance.colors.colSecondaryContainer

            // Password
            enabled: !root.context.unlockInProgress
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData

            // Synchronizing (across monitors) and unlocking
            onTextChanged: root.context.currentText = this.text
            onAccepted: {
                root.context.tryUnlock(ctrlHeld);
            }
            Connections {
                target: root.context
                function onCurrentTextChanged() {
                    passwordBox.text = root.context.currentText;
                }
            }

            Keys.onPressed: event => {
                root.context.resetClearTimer();
            }
            
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: passwordBox.width - 8
                    height: passwordBox.height
                    radius: height / 2
                }
            }

            // Shake when wrong password
            ErrorShakeAnimation {
                id: wrongPasswordShakeAnim
                target: passwordBox
            }
            Connections {
                target: GlobalStates
                function onScreenUnlockFailedChanged() {
                    if (GlobalStates.screenUnlockFailed) wrongPasswordShakeAnim.restart();
                }
            }

            // We're drawing dots manually
            property bool materialShapeChars: Config.options.lock.materialShapeChars
            color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, materialShapeChars ? 1 : 0)
            Loader {
                active: passwordBox.materialShapeChars
                anchors {
                    fill: parent
                    leftMargin: passwordBox.padding
                    rightMargin: passwordBox.padding
                }
                sourceComponent: PasswordChars {
                    glyphScale: root.lockFontScale
                    length: root.context.currentText.length
                    selectionStart: passwordBox.selectionStart
                    selectionEnd: passwordBox.selectionEnd
                    cursorPosition: passwordBox.cursorPosition
                }
            }
        }

        ToolbarButton {
            id: confirmButton
            implicitWidth: height
            toggled: true
            enabled: !root.context.unlockInProgress
            colBackgroundToggled: Appearance.colors.colPrimary

            onClicked: root.context.tryUnlock()

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                iconSize: 29 * root.lockFontScale
                text: {
                    if (root.context.targetAction === LockContext.ActionEnum.Unlock) {
                        return root.ctrlHeld ? "coffee" : "arrow_right_alt";
                    } else if (root.context.targetAction === LockContext.ActionEnum.Poweroff) {
                        return "power_settings_new";
                    } else if (root.context.targetAction === LockContext.ActionEnum.Reboot) {
                        return "restart_alt";
                    }
                }
                color: confirmButton.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
            }
        }
    }

    // Left toolbar
    Toolbar {
        id: leftIsland
        visible: Config.options.lock.showToolbars
        anchors {
            right: mainIsland.left
            top: mainIsland.top
            bottom: mainIsland.bottom
            rightMargin: 10
        }
        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        // Username
        IconAndTextPair {
            Layout.leftMargin: 8
            icon: "account_circle"
            visible: !Config.options.lock.showMedia || MprisController.activePlayer === null
            text: SystemInfo.username
        }

        // Media player info 
        Loader {
            Layout.leftMargin: 2
            Layout.rightMargin: 2
            Layout.alignment: Qt.AlignVCenter
            active: Config.options.lock.showMedia && MprisController.activePlayer !== null
            visible: active
            
            sourceComponent: Item {
                implicitWidth: mediaRow.implicitWidth
                implicitHeight: mediaRow.implicitHeight

                Component.onCompleted: MprisController.acquirePositionUpdates()
                Component.onDestruction: MprisController.releasePositionUpdates()
                
                readonly property MprisPlayer activePlayer: MprisController.activePlayer
                readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || ""
                
                RowLayout {
                    id: mediaRow
                    spacing: 8
                    anchors.centerIn: parent
                    
                    Rectangle {
                        id: artRect
                        implicitWidth: 40 * root.lockFontScale
                        implicitHeight: 40 * root.lockFontScale
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimaryContainer
                        Layout.alignment: Qt.AlignVCenter
                        clip: true 

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: artRect.width
                                height: artRect.height
                                radius: artRect.radius
                            }
                        }

                        StyledImage {
                            anchors.centerIn: parent
                            width: artRect.width
                            height: artRect.height
                            source: root.artUrl
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                            antialiasing: true
                            sourceSize.width: artRect.width * 2
                            sourceSize.height: artRect.height * 2
                            visible: root.artUrl !== ""
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            fill: 1
                            text: "music_note"
                            iconSize: Appearance.font.pixelSize.normal * root.lockFontScale
                            color: Appearance.colors.colOnSecondaryContainer
                            visible: root.artUrl === ""
                        }
                    }
                    
                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: -2
                        
                        StyledText {
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: Math.min(implicitWidth, 180) 
                            color: Appearance.colors.colOnSurfaceVariant
                            text: {
                                var artist = activePlayer?.trackArtist || " ";
                                return artist.length > 25 ? artist.substring(0, 25) + "..." : artist;
                            }
                            font.pixelSize: Appearance.font.pixelSize.smaller * root.lockFontScale
                        }
                        
                        StyledText {
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: Math.min(implicitWidth, 180) 
                            color: Appearance.colors.colOnSurfaceVariant
                            text: {
                                var title = cleanedTitle;
                                return title.length > 30 ? title.substring(0, 30) + "..." : title;
                            }
                            font.weight: Font.Medium
                            font.pixelSize: Appearance.font.pixelSize.small * root.lockFontScale
                        }
                    }
                    
                    ClippedFilledCircularProgress {
                        id: mediaCircProg
                        Layout.alignment: Qt.AlignVCenter
                        lineWidth: Appearance.rounding.unsharpen
                        value: activePlayer?.position / activePlayer?.length
                        implicitSize: 24 * root.lockFontScale
                        colPrimary: Appearance.colors.colOnSurfaceVariant
                        enableAnimation: false
                        
                        Item {
                            anchors.centerIn: parent
                            width: mediaCircProg.implicitSize
                            height: mediaCircProg.implicitSize
                            
                            MaterialSymbol {
                                anchors.centerIn: parent
                                fill: 1
                                text: "music_note"
                                iconSize: Appearance.font.pixelSize.normal * root.lockFontScale
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }
                }
            }
        }

        // Keyboard layout (Xkb)
        Loader {
            Layout.rightMargin: 8
            Layout.fillHeight: true
            active: !Config.options.lock.showMedia || MprisController.activePlayer === null
            visible: active

            sourceComponent: Row {
                spacing: 8

                MaterialSymbol {
                    id: keyboardIcon
                    anchors.verticalCenter: parent.verticalCenter
                    fill: 1
                    text: "keyboard_alt"
                    iconSize: Appearance.font.pixelSize.huge * root.lockFontScale
                    color: Appearance.colors.colOnSurfaceVariant
                }
                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: StyledText {
                        text: HyprlandXkb.currentLayoutCode
                        color: Appearance.colors.colOnSurfaceVariant
                        animateChange: true
                    }
                }
            }
        }

        // Keyboard layout (Fcitx)
        Bar.SysTray {
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            showSeparator: false
            showOverflowMenu: false
            pinnedItems: SystemTray.items.values.filter(i => i.id == "Fcitx")
            visible: pinnedItems.length > 0
        }
    }

    // Right toolbar
    Toolbar {
        id: rightIsland
        visible: Config.options.lock.showToolbars
        anchors {
            left: mainIsland.right
            top: mainIsland.top
            bottom: mainIsland.bottom
            leftMargin: 10
        }

        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        IconAndTextPair {
            visible: Battery.available
            icon: Battery.isCharging ? "bolt" : "battery_android_full"
            text: Math.round(Battery.percentage * 100)
            color: (Battery.isLow && !Battery.isCharging) ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
        }

        IconToolbarButton {
            id: sleepButton
            onClicked: Session.suspend()
            text: "dark_mode"
        }

        PasswordGuardedIconToolbarButton {
            id: powerButton
            text: "power_settings_new"
            targetAction: LockContext.ActionEnum.Poweroff
        }

        PasswordGuardedIconToolbarButton {
            id: rebootButton
            text: "restart_alt"
            targetAction: LockContext.ActionEnum.Reboot
        }
    }

    component PasswordGuardedIconToolbarButton: IconToolbarButton {
        id: guardedBtn
        required property var targetAction

        toggled: root.context.targetAction === guardedBtn.targetAction

        onClicked: {
            if (!root.requirePasswordToPower) {
                root.context.unlocked(guardedBtn.targetAction);
                return;
            }
            if (root.context.targetAction === guardedBtn.targetAction) {
                root.context.resetTargetAction();
            } else {
                root.context.targetAction = guardedBtn.targetAction;
                root.context.shouldReFocus();
            }
        }
    }

    component IconAndTextPair: Row {
        id: pair
        required property string icon
        required property string text
        property color color: Appearance.colors.colOnSurfaceVariant
        property real iconSize: 26 * root.lockFontScale
        property real fontPixelSize: 18 * root.lockFontScale

        spacing: 4
        Layout.fillHeight: true
        Layout.leftMargin: 10
        Layout.rightMargin: 10
        

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            fill: 1
            text: pair.icon
            iconSize: pair.iconSize
            animateChange: true
            color: pair.color
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: pair.text
            color: pair.color
            font.pixelSize: pair.fontPixelSize
        }
    }
}
