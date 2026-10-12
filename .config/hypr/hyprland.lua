-- Hyprland configuration

local home     = os.getenv("HOME")
local terminal = "kitty"
local menu     = home .. "/.config/rofi/launcher.sh"
local media    = home .. "/.config/waybar/scripts/media.sh"
local mainMod  = "SUPER"


-- Monitors

hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = 1,
})

hl.monitor({
    output    = "HDMI-A-1",
    mode      = "1920x1080@100",
    position  = "1920x-840",
    scale     = 1,
    transform = 1,
})

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


-- Environment

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


-- Autostart

hl.on("hyprland.start", function()
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Papirus'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'Iosevka Nerd Font Mono Medium 11'")

    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd(home .. "/.config/waybar/launch.sh")
    hl.exec_cmd("hyprpaper")
end)


-- Look and feel

hl.config({
    general = {
        gaps_in  = 2,
        gaps_out = 4,

        border_size = 3,

        col = {
            active_border   = "rgba(2f2f2fff)",
            inactive_border = "rgba(131313ff)",
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 5,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = false,
        },

        blur = {
            enabled           = true,
            size              = 8,
            passes            = 2,
            new_optimizations = true,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})


-- Animations

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })


-- Input

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse  = 1,
        accel_profile = "flat",
        sensitivity   = 0,
        scroll_factor = 2.0,

        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true,
            scroll_factor        = 2.0,
        },
    },
})

-- Three-finger horizontal swipe changes workspace
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})


-- Keybindings: general

hl.bind(mainMod .. " + Return",      hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + D",           hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + Q",   hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + C",   hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + SHIFT + E",   hl.dsp.exit())


-- Keybindings: focus and move windows (vim keys and arrows)

local directions = {
    H = "left",  J = "down",  K = "up",  L = "right",
    left = "left", down = "down", up = "up", right = "right",
}

for key, dir in pairs(directions) do
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ direction = dir }))
end


-- Keybindings: workspaces

for i = 1, 10 do
    local key = i % 10 -- workspace 10 is on key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scroll through existing workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Scratchpad
hl.bind(mainMod .. " + minus",         hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratchpad" }))


-- Keybindings: layout, groups and floating

hl.bind(mainMod .. " + B",             hl.dsp.layout("preselect r"))
hl.bind(mainMod .. " + V",             hl.dsp.layout("preselect d"))
hl.bind(mainMod .. " + E",             hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + W",             hl.dsp.group.toggle())
hl.bind(mainMod .. " + S",             hl.dsp.group.toggle())
hl.bind(mainMod .. " + Tab",           hl.dsp.group.next())
hl.bind(mainMod .. " + F",             hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + space",         hl.dsp.window.cycle_next({ floating = true }))

-- Move and resize windows with the mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- Keybindings: resize mode (SUPER + R, then vim keys or arrows; Enter or Esc to leave)

local resize_steps = {
    H = { -10, 0 },  J = { 0, 10 },  K = { 0, -10 },  L = { 10, 0 },
    left = { -10, 0 }, down = { 0, 10 }, up = { 0, -10 }, right = { 10, 0 },
}

hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
    for key, step in pairs(resize_steps) do
        hl.bind(key, hl.dsp.window.resize({ x = step[1], y = step[2], relative = true }), { repeating = true })
    end
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("escape", hl.dsp.submap("reset"))
end)


-- Keybindings: volume, brightness and media

hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl --quiet --exponent=4 --min-value=970 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl --quiet --exponent=4 --min-value=970 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(media .. " next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(media .. " previous"),   { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(media .. " play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(media .. " play-pause"), { locked = true })


-- Keybindings: screenshots, saved to ~/Pictures/Screenshots and copied to the clipboard

local screenshot_full = [[sh -c 'f="$HOME/Pictures/Screenshots/Screenshot-$(date +%F_%T).png"; mkdir -p "${f%/*}" && grim "$f" && wl-copy < "$f"']]
local screenshot_area = [[sh -c 'r=$(slurp) || exit; f="$HOME/Pictures/Screenshots/Screenshot-$(date +%F_%T).png"; mkdir -p "${f%/*}" && grim -g "$r" "$f" && wl-copy < "$f"']]

hl.bind("Print",        hl.dsp.exec_cmd(screenshot_full))
hl.bind("CTRL + Print", hl.dsp.exec_cmd(screenshot_area))


-- Window rules

hl.window_rule({
    -- Ignore maximize requests from apps
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})
