-- MONITOR CONFIG
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    -- Let Hyprland derive scale per output from EDID/PPI.  The 14-inch 4K
    -- panel resolves to HiDPI while normal-DPI external displays remain 1x.
    scale = "auto",
    -- This desktop is intentionally SDR. Pin the scanout format so output
    -- hotplug cannot transiently rebuild another monitor as XR30 + DCC.
    bitdepth = 8
})

hl.gesture({
    fingers = 3,
    direction = "swipe",
    action = "move"
})
hl.gesture({
    fingers = 3,
    direction = "pinch",
    action = "fullscreen"
})
hl.gesture({
    fingers = 4,
    direction = "horizontal",
    action = "workspace"
})
hl.gesture({
    fingers = 4,
    direction = "up",
    action = function()
        hl.dispatch(hl.dsp.global("quickshell:overviewWorkspacesToggle"))
    end
})
hl.gesture({
    fingers = 4,
    direction = "down",
    action = function()
        hl.dispatch(hl.dsp.global("quickshell:overviewWorkspacesToggle"))
    end
})

hl.config({
    gestures = {
        -- 700 logical pixels made the four-finger gesture feel like it was
        -- dragging behind the hand on the 4K/2x panel. Keep it deliberate,
        -- but let it complete within a comfortable single swipe.
        workspace_swipe_distance = 420,
        workspace_swipe_cancel_ratio = 0.2,
        workspace_swipe_min_speed_to_force = 5,
        workspace_swipe_direction_lock = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new = true
    },
    general = {
        -- Gaps and border
        gaps_in = 4,
        gaps_out = 5,
        gaps_workspaces = 50,

        border_size = 1,

        col = {
            active_border = "rgba(0DB7D455)",
            inactive_border = "rgba(31313600)"
        },
        resize_on_border = true,
        -- Keep the visible border thin, but make its mouse resize target easy to hit.
        extend_border_grab_area = 24,
        hover_icon_on_border = true,

        no_focus_fallback = true,
        allow_tearing = false,
        snap = {
            enabled = true,
            window_gap = 4,
            monitor_gap = 5,
            respect_gaps = true
        }
    },
    decoration = {
        -- 2 = circle, higher = squircle, 4 = very obvious squircle
        -- Fuck clearly visible squircles. 100% Apple brainrot.
        rounding_power = 2.5,
        rounding = 18,

        blur = {
            -- Keep resize redraws cheap and deterministic on the 4K AMD panel.
            enabled = false,
            xray = false,
            special = false,
            new_optimizations = true,
            size = 4,
            passes = 1,
            brightness = 1,
            noise = 0.02,
            contrast = 0.89,
            vibrancy = 0.25,
            vibrancy_darkness = 0.5,
            popups = false,
            popups_ignorealpha = 0.6,
            input_methods = true,
            input_methods_ignorealpha = 0.8
        },
        shadow = {
            -- Tiled windows already have gaps/borders; live shadows only enlarge
            -- the damaged area during every resize frame on the 4K display.
            enabled = false,
            range = 8,
            offset = {0, 2},
            render_power = 3,
            color = "rgba(00000020)"

        },
        -- Dim
        dim_inactive = false,
        dim_strength = 0,
        dim_special = 0.2
    },
    animations = {
        enabled = true
    },
    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = true,
        precise_mouse_move = true,
    },
})
-- Curves
hl.curve("expressiveFastSpatial", {
    type = "bezier",
    points = {{0.42, 1.67}, {0.21, 0.90}}
})
hl.curve("expressiveSlowSpatial", {
    type = "bezier",
    points = {{0.39, 1.29}, {0.35, 0.98}}
})
hl.curve("expressiveDefaultSpatial", {
    type = "bezier",
    points = {{0.38, 1.21}, {0.22, 1.00}}
})
hl.curve("emphasizedDecel", {
    type = "bezier",
    points = {{0.05, 0.7}, {0.1, 1}}
})
hl.curve("emphasizedAccel", {
    type = "bezier",
    points = {{0.3, 0}, {0.8, 0.15}}
})
hl.curve("standardDecel", {
    type = "bezier",
    points = {{0, 0}, {0, 1}}
})
hl.curve("menu_decel", {
    type = "bezier",
    points = {{0.1, 1}, {0, 1}}
})
hl.curve("menu_accel", {
    type = "bezier",
    points = {{0.52, 0.03}, {0.72, 0.08}}
})
hl.curve("stall", {
    type = "bezier",
    points = {{1, -0.1}, {0.7, 0.85}}
})
-- Responsive, evenly distributed motion. The old emphasized-deceleration
-- curve completed almost all visible movement up front and then spent many
-- frames creeping toward the endpoint, which looked like end-of-animation lag.
hl.curve("responsiveFlow", {
    type = "bezier",
    -- Smooth, non-overshooting acceleration with an exact endpoint.
    points = {{0.22, 0.68}, {0.32, 1}}
})
-- Configs
-- windows
hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 2.5,
    bezier = "responsiveFlow",
    style = "popin 96%"
})
hl.animation({
    leaf = "fadeIn",
    enabled = true,
    speed = 2,
    bezier = "responsiveFlow"
})
hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 2,
    bezier = "responsiveFlow",
    style = "popin 97%"
})
hl.animation({
    leaf = "fadeOut",
    enabled = true,
    speed = 2,
    bezier = "responsiveFlow"
})
hl.animation({
    leaf = "windowsMove",
    enabled = false
})
hl.animation({
    leaf = "border",
    enabled = true,
    speed = 2,
    bezier = "responsiveFlow"
})

-- layers
hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = 2.5,
    bezier = "responsiveFlow",
    style = "popin 97%"
})
hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = 2,
    bezier = "responsiveFlow",
    style = "popin 97%"
})
-- fade
hl.animation({
    leaf = "fadeLayersIn",
    enabled = true,
    speed = 2,
    bezier = "responsiveFlow"
})
hl.animation({
    leaf = "fadeLayersOut",
    enabled = true,
    speed = 2,
    bezier = "responsiveFlow"
})
-- workspaces
hl.animation({
    leaf = "workspaces",
    enabled = true,
    -- Keep gestures, but finish a keyboard switch in roughly six 60 Hz frames.
    -- Opaque slide avoids the full-screen blend pass used by slidefade.
    speed = 1,
    bezier = "responsiveFlow",
    style = "slide"
})
-- specialWorkspace
hl.animation({
    leaf = "specialWorkspaceIn",
    enabled = true,
    speed = 2.5,
    bezier = "responsiveFlow",
    style = "slidevert"
})
hl.animation({
    leaf = "specialWorkspaceOut",
    enabled = true,
    speed = 2,
    bezier = "responsiveFlow",
    style = "slidevert"
})
-- zoom
hl.animation({
    leaf = "zoomFactor",
    enabled = true,
    speed = 2,
    bezier = "responsiveFlow"
})

hl.config({
    input = {
        kb_layout = "us",
        numlock_by_default = true,
        repeat_delay = 250,
        repeat_rate = 35,
        -- Neutral fallback for future external mice. Built-in pointing
        -- devices use independent curves below.
        sensitivity = 0,
        accel_profile = "adaptive",

        follow_mouse = 1,
        off_window_axis_events = 2,

        touchpad = {
            natural_scroll = true,
            disable_while_typing = false,
            clickfinger_behavior = true,
            scroll_factor = 1.0
        }
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 0,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        enable_swallow = false,
        swallow_regex = "(foot|kitty|allacritty|Alacritty)",
        on_focus_under_fullscreen = 2,
        allow_session_lock_restore = true,
        -- The lock owns an opaque wallpaper; continuing to render workspaces
        -- underneath only wastes GPU time and can expose a frame on failure.
        session_lock_xray = false,
        initial_workspace_tracking = false,
        -- Late application activation must not pull the user away from the
        -- workspace they are already viewing. Explicit clicks and keybinds
        -- still focus/switch normally.
        focus_on_activate = false
    },

    render = {
        -- Let fullscreen clients bypass composition when the current scene is
        -- compatible, while retaining the compositor as an automatic fallback.
        direct_scanout = 2,
        expand_undersized_textures = false,
        -- This panel is SDR. Avoid promoting the 4K workspace framebuffer to
        -- the experimental FP16/color-management path on every render pass.
        cm_enabled = false,
        use_fp16 = 0,
        -- Hyprland enables triple buffering only when the renderer falls
        -- behind, which is useful for live resize on this 4K panel.
        new_render_scheduling = true,
        commit_timing_enabled = true
    },

    debug = {
        -- Full damage tracking keeps unchanged windows out of redraws; VFR
        -- stops repainting the desktop when no client has submitted damage.
        damage_tracking = 2,
        vfr = true
    },

    binds = {
        scroll_event_delay = 0,
        hide_special_on_workspace_change = true
    },

    cursor = {
        -- The AMD display supports hardware cursor planes.  Keeping pointer
        -- updates off the composited scene minimizes cursor presentation lag.
        -- A DRM dumb buffer avoids modifier/DCC cursor corruption during
        -- mixed-refresh output hotplug without disabling the hardware plane.
        no_hardware_cursors = 0,
        use_cpu_buffer = 1,
        min_refresh_rate = 60,
        zoom_factor = 1,
        zoom_rigid = false,
        zoom_disable_aa = true,
        hotspot_padding = 1
    },

    xwayland = {
        force_zero_scaling = true
    }
})
