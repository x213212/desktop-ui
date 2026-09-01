import qs.modules.common.widgets
import qs.services

QuickToggleButton {
    id: root
    toggled: Idle.inhibit
    buttonIcon: "coffee"
    downAction: () => {
        Idle.toggleInhibit()
    }
    StyledToolTip {
        text: Translation.tr("Keep system awake")
    }

}
