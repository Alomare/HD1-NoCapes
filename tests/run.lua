-- Offline tests for everything that doesn't need the game. From the repository's root:
--   luajit tests/run.lua
local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL " .. name .. "\n" .. err)
	end
end

local function eq(got, want, what)
	if got ~= want then error((what or "value") .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end

-- A fresh copy of the module for each test.
local function load_capes()
	return dofile("src/capes.lua")
end

-- A game with Helldivers: each { cape = true|false, visible = bool } gets a body, and a cape unless false.
local function world(list)
	local units, slaves = {}, {}
	local U = {}
	function U.alive(u) return type(u) == "table" and u.alive == true end
	function U.set_unit_visibility(u, on) u.shown = on end
	for i, h in ipairs(list) do
		local body = { alive = true, name = "body" .. i }
		local state = { visible = h.visible ~= false }
		if h.cape ~= false then
			state.cape_unit = { alive = true, shown = true, name = "cape" .. i }
		end
		slaves[body] = { state = state }
		units[i] = { body = body, state = state }
	end
	local env = { slaves = function() return slaves end, unit = function() return U end, hidden_set = {} }
	env.hidden = function(u) return env.hidden_set[u] == true end
	return env, units, U
end

-- What the loader's wrapper does: the hook with the original first.
local function hooked(capes, U)
	local original = U.set_unit_visibility
	U.set_unit_visibility = function(...) return capes.visibility(original, ...) end
end

test("a frame hides every cape", function()
	local capes = load_capes()
	local env, units = world({ {}, {}, { cape = false }, {} })
	capes.frame(env)
	eq(units[1].state.cape_unit.shown, false, "player cape")
	eq(units[2].state.cape_unit.shown, false, "other cape")
	eq(units[4].state.cape_unit.shown, false, "bot cape")
end)

test("a known cape can't be shown while on", function()
	local capes = load_capes()
	local env, units, U = world({ {} })
	hooked(capes, U)
	capes.frame(env)
	U.set_unit_visibility(units[1].state.cape_unit, true)
	eq(units[1].state.cape_unit.shown, false, "after a show")
end)

test("other units are shown as asked", function()
	local capes = load_capes()
	local env, units, U = world({ {} })
	hooked(capes, U)
	capes.frame(env)
	U.set_unit_visibility(units[1].body, true)
	eq(units[1].body.shown, true, "body")
	U.set_unit_visibility(units[1].body, false)
	eq(units[1].body.shown, false, "body hidden")
end)

test("a new cape is hidden on the next frame", function()
	local capes = load_capes()
	local env, units = world({ {} })
	capes.frame(env)
	local new = { alive = true, shown = true }
	units[1].state.cape_unit.alive = false
	units[1].state.cape_unit = new
	capes.frame(env)
	eq(new.shown, false, "new cape")
end)

test("off gives capes back as the game would draw them", function()
	local capes = load_capes()
	local env, units, U = world({ {}, { visible = false }, {} })
	hooked(capes, U)
	env.hidden_set[units[3].body] = true
	capes.frame(env)
	capes.set(false, env)
	eq(units[1].state.cape_unit.shown, true, "shown Helldiver")
	eq(units[2].state.cape_unit.shown, false, "Helldiver in a hellpod")
	eq(units[3].state.cape_unit.shown, false, "Helldiver hidden by another mod")
	U.set_unit_visibility(units[2].state.cape_unit, true)
	eq(units[2].state.cape_unit.shown, true, "shown by the game while off")
	capes.frame(env)
	eq(units[2].state.cape_unit.shown, true, "frames leave capes alone while off")
end)

test("on again hides at once", function()
	local capes = load_capes()
	local env, units = world({ {} })
	capes.set(false, env)
	capes.set(true, env)
	eq(units[1].state.cape_unit.shown, false, "cape")
end)

test("no game state, no error", function()
	local capes = load_capes()
	capes.frame({ slaves = function() return {} end, unit = function() return nil end })
	capes.set(false, { slaves = function() return {} end, unit = function() return nil end })
end)

test("hidden capes cost no engine call until the next full pass", function()
	local capes = load_capes()
	local env, units, U = world({ {}, {}, {} })
	local calls = 0
	local alive, set = U.alive, U.set_unit_visibility
	U.alive = function(...) calls = calls + 1 return alive(...) end
	U.set_unit_visibility = function(...) calls = calls + 1 return set(...) end
	capes.frame(env)
	eq(calls, 6, "first frame")
	calls = 0
	for _ = 2, capes.FULL - 1 do capes.frame(env) end
	eq(calls, 0, "frames in between")
	capes.frame(env)
	eq(calls, 6, "full pass")
end)

test("a cape shown past the wrapper is hidden by the next full pass", function()
	local capes = load_capes()
	local env, units = world({ {} })
	capes.frame(env)
	local cape = units[1].state.cape_unit
	cape.shown = true -- mesh by mesh, which the wrapper doesn't see
	for _ = 2, capes.FULL do capes.frame(env) end
	eq(cape.shown, false, "after a full pass")
end)

test("a new cape is hidden on the first frame, between full passes", function()
	local capes = load_capes()
	local env, units = world({ {} })
	capes.frame(env)
	capes.frame(env)
	local new = { alive = true, shown = true }
	units[1].state.cape_unit.alive = false
	units[1].state.cape_unit = new
	capes.frame(env)
	eq(new.shown, false, "new cape")
end)

test("a dead cape is skipped", function()
	local capes = load_capes()
	local env, units = world({ {} })
	units[1].state.cape_unit.alive = false
	capes.frame(env)
	eq(units[1].state.cape_unit.shown, true, "dead cape untouched")
end)

-- main.lua with a fake loader and API: the row is bound to the option, the hook wraps Unit, frames hide.
local function boot(setting, binds)
	local env, units, U = world({ {} })
	local loaded, frames, hooks, logs = {}, {}, {}, {}
	local row
	local api = {
		game = { slaves = env.slaves, global = function(name) return name == "Unit" and U or nil end },
		world = { hidden = env.hidden },
		mod_settings = { BINDS = binds, page = function(title)
			return { toggle = function(_, id, opts)
				row = { id = id, opts = opts, title = title }
				if setting == nil then return opts.default end
				return setting
			end }
		end },
	}
	obsidian = {
		module = function(name)
			if loaded[name] == nil then loaded[name] = dofile(name .. ".lua") end
			return loaded[name]
		end,
		import = function(id) return id == "obsidian.api" and api or nil end,
		settings = { get = function(id) if id == "hide_capes" then return setting end end },
		hook = function(target, method, fn) hooks[#hooks + 1] = { target = target, method = method, fn = fn } end,
		on_frame = function(fn) frames[#frames + 1] = fn end,
		log = function(s) logs[#logs + 1] = s end,
	}
	dofile("main.lua")
	local b = { env = env, units = units, U = U, frames = frames, hooks = hooks, logs = logs, row = row, capes = loaded["src/capes"] }
	obsidian = nil
	return b
end

test("main: hides on the first frame, and the hook keeps the cape hidden", function()
	local b = boot(nil, true)
	eq(#b.hooks, 1, "hooks")
	eq(b.hooks[1].target, "Unit", "hook target")
	eq(b.hooks[1].method, "set_unit_visibility", "hook method")
	eq(b.row.id, "hide_capes", "row id")
	eq(b.row.opts.option, true, "row bound to the option")
	b.frames[1]()
	local cape = b.units[1].state.cape_unit
	eq(cape.shown, false, "after a frame")
	hooked(b.capes, b.U)
	b.U.set_unit_visibility(cape, true)
	eq(cape.shown, false, "after a show")
end)

test("main: the pause menu row switches capes back on", function()
	local b = boot(true, true)
	b.frames[1]()
	b.row.opts.on_change(false)
	eq(b.units[1].state.cape_unit.shown, true, "cape back")
	b.row.opts.on_change(true)
	eq(b.units[1].state.cape_unit.shown, false, "cape hidden again")
end)

test("main: option off in Obsidian leaves capes alone", function()
	local b = boot(false, true)
	b.frames[1]()
	eq(b.units[1].state.cape_unit.shown, true, "cape")
end)

test("main: an API without bound rows still reads the option", function()
	local b = boot(false, nil)
	eq(b.row, nil, "no row")
	b.frames[1]()
	eq(b.units[1].state.cape_unit.shown, true, "cape")
end)

print(passed .. " passed, " .. failed .. " failed")
os.exit(failed == 0 and 0 or 1)
