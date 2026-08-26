-- Your Hyprland configuration.
--
-- This file is yours. Strata never edits it, and updates to the image never
-- overwrite it.
--
-- The line below loads Strata's defaults from /etc/strata/hypr/hyprland.lua.
-- Read that file to see what is set; do not edit it, because the image replaces
-- it on update. Delete the line to start from nothing instead.

dofile("/etc/strata/hypr/hyprland.lua")

-- ---------------------------------------------------------------------------
-- Your settings go below. Anything here runs after the defaults, so it wins.
--
-- Examples:
--
--   hl.bind("SUPER + T", hl.dsp.exec_cmd("foot"))
--
--   hl.config({
--       general = { gaps_out = 16 },
--   })
--
--   hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "auto", scale = 1 })
-- ---------------------------------------------------------------------------
