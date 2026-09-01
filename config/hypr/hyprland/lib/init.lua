HOME = os.getenv("HOME")
local desktopUiWorkspaceGroupSize = 10

function desktop_ui_workspace_group_size()
    return desktopUiWorkspaceGroupSize
end

local function desktop_ui_host_setting(key)
    local value = os.getenv(key)
    if value and value:match("^[%w_.:-]+$") then
        return value
    end
    local configHome = os.getenv("XDG_CONFIG_HOME") or (HOME .. "/.config")
    local file = io.open(configHome .. "/desktop-ui/host.env", "r")
    if not file then
        return nil
    end
    for line in file:lines() do
        local name, candidate = line:match("^%s*([A-Z0-9_]+)%s*=%s*['\"]?([%w_.:-]+)['\"]?%s*$")
        if name == key then
            file:close()
            return candidate
        end
    end
    file:close()
    return nil
end

local workspaceMonitorRoles = {}
local workspaceRoleConnectors = {}
for role = 0, 9 do
    local connector = desktop_ui_host_setting("UIOS_MONITOR_ROLE_" .. tostring(role))
    if connector and not workspaceMonitorRoles[connector] then
        workspaceMonitorRoles[connector] = role
        workspaceRoleConnectors[role] = connector
    end
end
local workspaceRolesManaged = next(workspaceMonitorRoles) ~= nil

function desktop_ui_monitor_connector(role)
    return workspaceRoleConnectors[math.floor(tonumber(role) or -1)]
end

local function desktop_ui_runtime_monitor_roles()
    local result = {}
    local used = {}
    for connector, role in pairs(workspaceMonitorRoles) do
        result[connector] = role
        used[role] = true
    end

    -- Managed mode is injective and fail-closed: an unconfigured connector
    -- never borrows a runtime ID that may already belong to a stable role.
    if workspaceRolesManaged then
        return result
    end

    local monitors = hl.get_monitors() or {}
    table.sort(monitors, function(left, right)
        local leftId = math.floor(tonumber(left and left.id) or 9999)
        local rightId = math.floor(tonumber(right and right.id) or 9999)
        if leftId == rightId then
            return tostring(left and left.name or "")
                < tostring(right and right.name or "")
        end
        return leftId < rightId
    end)
    for _, monitor in ipairs(monitors) do
        local connector = tostring(monitor and monitor.name or "")
        if connector ~= "" and result[connector] == nil then
            local preferred = math.floor(tonumber(monitor.id) or -1)
            local role = preferred >= 0 and preferred <= 9
                and not used[preferred] and preferred or nil
            if role == nil then
                for candidate = 0, 9 do
                    if not used[candidate] then
                        role = candidate
                        break
                    end
                end
            end
            if role ~= nil then
                result[connector] = role
                used[role] = true
            end
        end
    end
    return result
end

function desktop_ui_monitor_role(connectorName, runtimeMonitorId)
    local connector = tostring(connectorName or "")
    local roles = desktop_ui_runtime_monitor_roles()
    local role = roles[connector]
    if role ~= nil then
        return role
    end
    if workspaceRolesManaged then
        return nil
    end
    local fallback = math.floor(tonumber(runtimeMonitorId) or -1)
    if fallback >= 0 and fallback <= 9 then
        return fallback
    end
    return nil
end

function desktop_ui_workspace_group_for_monitor(monitor, allowMergedGroup)
    if type(monitor) == "string" then
        monitor = hl.get_monitor(monitor)
    end
    if not monitor then
        return nil
    end
    local role = desktop_ui_monitor_role(monitor.name, monitor.id)
    if role == nil then
        return nil
    end
    local monitors = hl.get_monitors() or {}
    local activeWorkspace = monitor.active_workspace
    local activeId = math.floor(tonumber(activeWorkspace and activeWorkspace.id) or 0)
    if allowMergedGroup and #monitors <= 1 and activeId >= 1 and activeId <= 100 then
        return math.floor((activeId - 1) / desktopUiWorkspaceGroupSize)
    end
    return role
end

function desktop_ui_workspace_for_monitor_slot(monitor, slot, allowMergedGroup)
    slot = math.floor(tonumber(slot) or 1)
    slot = math.max(1, math.min(desktopUiWorkspaceGroupSize, slot))
    local group = desktop_ui_workspace_group_for_monitor(monitor, allowMergedGroup)
    if group == nil or group < 0 or group > 9 then
        return nil
    end
    return group * desktopUiWorkspaceGroupSize + slot
end

function is_file_exists(name)
   local f = io.open(name, "r")
   if f ~= nil then
      io.close(f)
      return true
   else
      return false
   end
end

function create_if_not_exists(path)
   if not is_file_exists(path) then
      os.execute("mkdir -p \"$(dirname \"" .. path .. "\")\"")
      os.execute("echo '-- This file will not be overwritten across dots-hyprland updates.\n-- The file name is for the sake of organization and does not matter\n-- See the corresponding files in ~/.config/hypr/hyprland for examples' > \"" .. path .. "\"")
      return true
   end
   return false
end

function workspace_in_group(i)
    -- A special workspace can report a large internal ID (for example
    -- 2147483644). Deriving the group from that ID creates giant numbered
    -- workspaces and traps all following Super+number actions in that group.
    -- Monitor IDs are stable, ordinary and already define the intended group:
    -- monitor 0 -> 1..10, monitor 1 -> 11..20, and so on.
    local monitor = hl.get_active_monitor()
    return desktop_ui_workspace_for_monitor_slot(monitor, i, true)
end
