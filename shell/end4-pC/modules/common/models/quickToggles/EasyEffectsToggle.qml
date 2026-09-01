import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("EasyEffects")

    available: EasyEffects.available
    toggled: EasyEffects.active
    icon: "graphic_eq"
    activateOnPress: true

    Component.onCompleted: {
        EasyEffects.fetchActiveState()
    }

    mainAction: () => {
        EasyEffects.toggle()
    }

    altAction: () => {
        Quickshell.execDetached(["flatpak", "run", "com.github.wwmm.easyeffects"])
        GlobalStates.sidebarRightOpen = false
    }

    tooltipText: Translation.tr("EasyEffects | Right-click to configure")
}
