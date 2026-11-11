-- No Capes: hides the cape of every Helldiver, on this machine only. Switched in the pause menu (Mods)
-- or in Obsidian, through the hide_capes option.
local capes = obsidian.module("src/capes")
local api = obsidian.import("obsidian.api")

local env = {
	slaves = function() return api.game.slaves("customization") end,
	unit = function() return api.game.global("Unit") end,
	hidden = api.world and api.world.hidden,
}

local on = obsidian.settings.get("hide_capes") ~= false
-- A row bound to the option came with Obsidian API 1.16.0. Older ones keep the option in Obsidian only.
if api.mod_settings and api.mod_settings.BINDS then
	local page = api.mod_settings.page({ en = "No Capes" })
	on = page:toggle("hide_capes", { option = true, default = true,
		label = { en = "Hide capes" },
		info = { en = "Hides every Helldiver cape on this machine: the player, other players and bots." },
		on_change = function(value) capes.set(value, env) end }) ~= false
end
capes.on = on

-- Wraps the engine call every cape is shown with, so no other mod or game script can show one while the
-- mod is on. The mod loads after Photo Mode (obsidian.json), so this wrapper sits outside its calls.
obsidian.hook("Unit", "set_unit_visibility", capes.visibility)

local failed = false
obsidian.on_frame(function()
	local ok, err = pcall(capes.frame, env)
	if not ok and not failed then
		failed = true
		obsidian.log("No Capes: " .. tostring(err))
	end
end)

obsidian.log("No Capes ready, capes " .. (on and "hidden" or "shown"))
