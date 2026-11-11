-- Hides the cape of every Helldiver on this machine: the player, other players and bots.
--
-- Every cape is a unit CustomizationComponent spawns and links to the Helldiver, held in the slave state
-- as cape_unit (customization_component.lua:94). The component itself shows it again whenever the
-- Helldiver does (the state's visible, after a hellpod), and other mods show it with
-- Unit.set_unit_visibility too (Photo Mode's Cape toggle). So capes are hidden once a frame, after the
-- game's update, and the wrapper on Unit.set_unit_visibility (visibility below) turns a request to show
-- a known cape into one to hide it, so nothing brings one back in between. A hidden cape is left alone
-- until the next full pass (M.FULL), so most frames make no engine call at all.
--
-- env: slaves() -> unit -> context map of the customization component, unit() -> the Unit table,
-- hidden(unit) -> whether another mod has the whole Helldiver hidden (api.world.hidden), optional.
local M = { on = true }

-- Cape units seen by a pass -> the Helldiver wearing it. Weak, so capes the game destroys drop out.
M.capes = setmetatable({}, { __mode = "k" })
-- Capes hidden since the last full pass. A cape in here costs a table lookup a frame and no engine call:
-- the wrapper keeps it hidden. Cleared every FULL frames, so a cape shown some other way (mesh by mesh,
-- which the wrapper doesn't see) is hidden again within that time.
M.done = setmetatable({}, { __mode = "k" })
M.FULL = 30
M.count = 0

local function cape_of(ctx)
	local state = type(ctx) == "table" and ctx.state
	if type(state) ~= "table" then return nil end
	return state.cape_unit, state
end

local function alive(U, unit)
	local ok, yes = pcall(U.alive, unit)
	return ok and yes == true
end

-- Once a frame: a cape not hidden yet is hidden at once, before the frame is drawn, so a new one (an
-- Armory pick, a respawn) never shows. Every FULL frames every cape is hidden again.
function M.frame(env)
	if not M.on then return end
	M.count = M.count + 1
	if M.count >= M.FULL then
		M.count = 0
		M.done = setmetatable({}, { __mode = "k" })
	end
	local U
	for unit, ctx in pairs(env.slaves()) do
		local cape = cape_of(ctx)
		if cape and not M.done[cape] then
			U = U or env.unit()
			if not U then return end
			if alive(U, cape) then
				M.capes[cape] = unit
				pcall(U.set_unit_visibility, cape, false)
				M.done[cape] = true
			end
		end
	end
end

-- The wrapper on Unit.set_unit_visibility (obsidian.hook): a known cape stays hidden while the mod is on.
function M.visibility(original, unit, on, ...)
	if on == true and M.on and M.capes[unit] then on = false end
	return original(unit, on, ...)
end

-- Switches the mod on or off at once. Off gives every cape back as the game would draw it: hidden while
-- the Helldiver is (in a hellpod, or hidden whole by another mod), shown otherwise.
function M.set(on, env)
	on = on ~= false
	if on == M.on then return end
	M.on = on
	M.done = setmetatable({}, { __mode = "k" })
	if on then return M.frame(env) end
	local U = env.unit()
	if not U then return end
	for unit, ctx in pairs(env.slaves()) do
		local cape, state = cape_of(ctx)
		if cape and alive(U, cape) then
			local hidden = env.hidden and select(2, pcall(env.hidden, unit)) == true
			pcall(U.set_unit_visibility, cape, state.visible ~= false and not hidden)
		end
	end
end

return M
