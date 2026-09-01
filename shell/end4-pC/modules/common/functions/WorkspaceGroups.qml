pragma Singleton
import Quickshell

Singleton {
    id: root

    // This width is a compositor/session invariant, not a presentation option.
    // The bar may show fewer buttons, but connector ownership stays 1..10,
    // 11..20, and so on.
    readonly property int groupSize: 10
    readonly property int maxGroups: 10

    function runtimeGroup(runtimeMonitorId) {
        const id = Number(runtimeMonitorId)
        return Number.isFinite(id)
            ? Math.max(0, Math.min(root.maxGroups - 1, Math.floor(id))) : 0
    }

    function configuredRole(connectorName) {
        if (!connectorName)
            return -1
        for (let role = 0; role < root.maxGroups; ++role) {
            const configured = Quickshell.env(`UIOS_MONITOR_ROLE_${role}`) || ""
            if (configured.length > 0 && connectorName === configured)
                return role
        }
        return -1
    }

    function managedMode() {
        for (let role = 0; role < root.maxGroups; ++role) {
            if ((Quickshell.env(`UIOS_MONITOR_ROLE_${role}`) || "").length > 0)
                return true
        }
        return false
    }

    function ownerGroup(connectorName, runtimeMonitorId) {
        const configured = root.configuredRole(connectorName)
        if (configured >= 0)
            return configured
        if (root.managedMode())
            return -1
        return root.runtimeGroup(runtimeMonitorId)
    }

    function hasStableOwner(connectorName) {
        return root.configuredRole(connectorName) >= 0
    }

    function groupForWorkspaceId(workspaceId) {
        const id = Number(workspaceId)
        // Reject named/special/lock workspaces. Hyprland's temporary special
        // workspace IDs live near INT32_MAX; ordinary numbered IDs stay below.
        if (!Number.isFinite(id) || id < 1 || id >= 2147483000)
            return -1
        const group = Math.floor((Math.floor(id) - 1) / root.groupSize)
        return group < root.maxGroups ? group : -1
    }

    function presentationGroup(connectorName, runtimeMonitorId,
                               activeWorkspaceId, activeMonitorCount) {
        const owner = root.ownerGroup(connectorName, runtimeMonitorId)
        const active = root.groupForWorkspaceId(activeWorkspaceId)
        if (owner < 0)
            return -1
        if (active < 0)
            return owner
        // Never expand the bar into a group outside the shared invariant.
        if (root.hasStableOwner(connectorName) && active >= root.maxGroups)
            return owner

        // One active output physically hosts merged groups. Once multiple
        // outputs exist, presentation returns to connector ownership even if
        // Hyprland briefly reports a workspace borrowed during the merge.
        const count = Math.max(0, Math.floor(Number(activeMonitorCount) || 0))
        if (count <= 1)
            return active
        return owner
    }

    function firstWorkspaceId(group) {
        const value = Number(group)
        if (!Number.isFinite(value) || value < 0 || value >= root.maxGroups)
            return -1
        return Math.floor(value) * root.groupSize + 1
    }

    function containsWorkspace(group, workspaceId) {
        const value = Number(group)
        return Number.isFinite(value) && value >= 0 && value < root.maxGroups
            && root.groupForWorkspaceId(workspaceId) === Math.floor(value)
    }
}
