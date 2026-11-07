-- ~/.config/hypr/animations.lua      (repo: home/.config/hypr/animations.lua)
-- Edgerunners S2 motion pack v2: sharp, fast, no wobble, no bounce.
-- Hard-cut opens, snap-away closes, crisp moves, red-hot border + the universal red spark overlay.
--
-- Load it from the END of hyprland.lua so it overrides any older hl.animation() lines:
--     require("animations")
--
-- Speeds are in deciseconds (speed = 2.5 -> 250ms). Flip the switches below first.

local FX = {
  sparks          = true,   -- universal red spark overlay (Quickshell, see sparks/shell.qml)
  spinning_border = false,  -- rotating gradient border (re-renders every frame: costs GPU/battery)
  glow            = true,   -- red-hot glow around the focused window
  rofi_dim        = true,   -- dim everything behind the SUPER+R menu
}

-- ------------------------------------------------------------------ curves --
-- No overshoot, no springs: everything starts fast and lands hard.
hl.curve("expo",     { type = "bezier", points = { {0.16, 1.00}, {0.30, 1.00} } })  -- explosive start, clean stop
hl.curve("cut",      { type = "bezier", points = { {0.70, 0.00}, {0.20, 1.00} } })  -- aggressive in-out
hl.curve("inExpo",   { type = "bezier", points = { {0.70, 0.00}, {0.84, 0.00} } })  -- slow tick, then gone
hl.curve("linear",   { type = "bezier", points = { {0, 0}, {1, 1} } })

-- -------------------------------------------------------------- animations --
hl.animation({ leaf = "global", enabled = true, speed = 3, bezier = "expo" })

-- 1) APP OPENING: near-full-size pop (only 8% travel) + fast fade = a hard "cut in"
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 2.5, bezier = "expo",   style = "popin 92%" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 1.5, bezier = "linear" })

-- 3) CLOSING APPS: held for a beat, then snapped out
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "inExpo", style = "popin 96%" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 1.2, bezier = "linear" })

-- 4) MOVING / RESIZING and 5) FLOAT <-> TILE: crisp slide, no bounce
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "expo" })

-- focus changes / shadows / dimming: near-instant
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 1.5, bezier = "linear" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 2,   bezier = "linear" })
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 2,   bezier = "linear" })

-- 2) SUPER+R MENU and other layers: sharp pop-in, instant-ish out
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2,   bezier = "expo",   style = "popin 92%" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5, bezier = "inExpo", style = "popin 96%" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.5, bezier = "linear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.2, bezier = "linear" })

-- 6) EXTRAS: hard workspace slide (no fade), scratchpad drop, border colour switch
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3,   bezier = "expo", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "expo", style = "slidevert" })
hl.animation({ leaf = "border",           enabled = true, speed = 3,   bezier = "linear" })
hl.animation({ leaf = "zoomFactor",       enabled = true, speed = 3,   bezier = "expo" })

if FX.spinning_border then
  hl.animation({ leaf = "borderangle", enabled = true, speed = 60, bezier = "linear", style = "loop" })
else
  hl.animation({ leaf = "borderangle", enabled = false })
end

-- ------------------------------------------------------------- look & feel --
hl.config({
  general = {
    border_size = 2,
    col = {
      -- Edgerunners S2: blood red -> hot pink -> warning yellow
      active_border   = { colors = { "rgba(ff1f3dff)", "rgba(ff5c7aff)", "rgba(fcee09ff)" }, angle = 45 },
      inactive_border = "rgba(3a0f18aa)",
    },
  },
  decoration = {
    glow        = { enabled = FX.glow, range = 16, color = 0x88ff1f3d, color_inactive = 0x00000000 },
  },
})

-- ------------------------------------------------------------- layer rules --
-- Quickshell launcher (namespace "launcher"): it animates itself (stepped wipe), so Hyprland only fades it.
hl.layer_rule({
  name  = "edgerunner-launcher",
  match = { namespace = "launcher" },
  blur = true, ignore_alpha = 0.3, dim_around = FX.rofi_dim,
  animation = "fade",
})
-- plain rofi, if you still use it
hl.layer_rule({
  name  = "edgerunner-rofi",
  match = { namespace = "rofi" },
  blur = true, ignore_alpha = 0.3, dim_around = FX.rofi_dim,
  animation = "popin 92%",
})
hl.layer_rule({
  name  = "edgerunner-waybar",
  match = { namespace = "waybar" },
  blur = true, ignore_alpha = 0.3,
  animation = "slide top",
})
hl.layer_rule({
  name  = "edgerunner-quickshell",
  match = { namespace = "quickshell" },
  blur = true, ignore_alpha = 0.2,
})
-- (find your real layer names with:  hyprctl layers)

-- ----------------------------------------------------------- red spark FX --
-- A click-through fullscreen Quickshell overlay that fires red lightning + sparks on
-- window open / close / float-toggle / workspace-move and when SUPER+R opens.
if FX.sparks then
  hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -c sparks")
  end)
end
