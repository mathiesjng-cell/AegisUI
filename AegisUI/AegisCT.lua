-- AegisCT: own floating combat numbers.
-- The client's numbers over enemies cannot be styled, so in mode Crits/All we switch them
-- off (CVar CombatDamage) and draw our own from the combat log:
--   * hits are summed per target for 0.3 s, then shown as ONE number (readable at 100+ events/s)
--   * crits are gold and bigger, numbers rise and fade
--   * the number is placed above the enemy's nameplate (matched by name), with a fallback
--   * damage you take rises over your character (red)
-- Needs enemy nameplates switched on (default key V) to sit exactly above the enemy.

local L = AegisL.t

local FONT = "Fonts\\ARIALN.TTF"
local WINDOW = 0.3
local POOL = 30
local MAXN = 6          -- numbers per 0.3 s window
local MODES = { "off", "crit", "all" }
local SIZES = { small = 13, medium = 16, large = 20 }

local function cfg()
	AegisDB = AegisDB or {}
	AegisDB.ct = AegisDB.ct or {}
	return AegisDB.ct
end

local function mode()
	return cfg().mode or "off"
end
local function sizeKey()
	return cfg().size or "medium"
end

-- accumulators ---------------------------------------------------------
local sums, crits = {}, {}
local takenSum, takenCrit = 0, false

local function addDealt(name, amount, isCrit)
	if mode() == "crit" and not isCrit then
		return
	end
	sums[name] = (sums[name] or 0) + amount
	if isCrit then
		crits[name] = true
	end
end

local function addTaken(amount, isCrit)
	if mode() == "crit" and not isCrit then
		return
	end
	takenSum = takenSum + amount
	if isCrit then
		takenCrit = true
	end
end

-- short form for numbers from 1000 up: 1097 -> 1.1k, 28750 -> 28.8k, 1200000 -> 1.2M
local function short(n)
	if n >= 1000000000 then
		return (math.floor(n / 100000000 + 0.5) / 10) .. "B"
	elseif n >= 1000000 then
		return (math.floor(n / 100000 + 0.5) / 10) .. "M"
	elseif n >= 1000 then
		if n >= 100000 then
			return math.floor(n / 1000 + 0.5) .. "k"
		end
		return (math.floor(n / 100 + 0.5) / 10) .. "k"
	end
	return tostring(n)
end

-- number frames --------------------------------------------------------
local pool = {}
local function getSlot()
	local oldest, oi
	for i = 1, POOL do
		local s = pool[i]
		if not s then
			local f = CreateFrame("Frame", nil, UIParent)
			f:SetFrameStrata("TOOLTIP")
			f:SetWidth(100)
			f:SetHeight(30)
			f:EnableMouse(false)
			f.fs = f:CreateFontString(nil, "OVERLAY")
			f.fs:SetPoint("CENTER", f, "CENTER", 0, 0)
			f.active = false
			f.t0 = 0
			pool[i] = f
			return f
		end
		if not s.active then
			return s
		end
		if not oldest or s.t0 < oldest then
			oldest, oi = s.t0, i
		end
	end
	return pool[oi]
end

-- push a new number away from the ones still on screen (they would run into each other)
local function freeSpot(x, y, w, h)
	local now = GetTime()
	local tries = 0
	while tries < 5 do
		local hit = false
		for i = 1, POOL do
			local o = pool[i]
			if o and o.active then
				local p = (now - o.t0) / o.dur
				local oy = o.y + o.rise * p
				if math.abs(o.x - x) < (o.w + w) / 2 and math.abs(oy - y) < (o.h + h) / 2 then
					hit = true
					break
				end
			end
		end
		if not hit then
			return x, y
		end
		tries = tries + 1
		-- mostly upwards (stack), now and then a small step to the side
		if math.mod(tries, 2) == 1 then
			y = y + h
		elseif math.mod(tries, 4) == 2 then
			x = x + w * 0.6
		else
			x = x - w * 1.2
		end
	end
	return x, y
end

local function spawn(text, x, y, big, r, g, b, taken)
	local f = getSlot()
	local size = SIZES[sizeKey()] or 16
	if big then
		size = size + 6
	elseif taken then
		size = size - 2
	end
	f.w = string.len(text) * size * 0.62
	f.h = size + 2
	f.active = false
	x, y = freeSpot(x, y, f.w, f.h)
	f.fs:SetFont(FONT, size, "THICKOUTLINE")
	if f.fs.SetShadowColor then
		f.fs:SetShadowColor(0, 0, 0, 1)
		f.fs:SetShadowOffset(1, -1)
	end
	f.fs:SetText(text)
	f.fs:SetTextColor(r, g, b)
	f.x, f.y = x, y
	f.rise = big and 55 or 40
	f.dur = big and 1.5 or 1.0
	f.t0 = GetTime()
	f.active = true
	f:ClearAllPoints()
	f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	f:SetAlpha(1)
	f:Show()
end

local anim = CreateFrame("Frame")
anim:SetScript("OnUpdate", function()
	local now = GetTime()
	for i = 1, POOL do
		local f = pool[i]
		if f and f.active then
			local p = (now - f.t0) / f.dur
			if p >= 1 then
				f.active = false
				f:Hide()
			else
				f:ClearAllPoints()
				f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", f.x, f.y + f.rise * p)
				if p > 0.6 then
					f:SetAlpha(1 - (p - 0.6) / 0.4)
				end
			end
		end
	end
end)

-- nameplate lookup -----------------------------------------------------
local plates = {}
local plateCount = 0
local function findPlates()
	plateCount = 0
	-- plates[name] = { x, y } in UIParent coordinates, best (most opaque) plate per name
	for k in pairs(plates) do
		plates[k] = nil
	end
	local ratio = 1
	local ps, us = WorldFrame:GetEffectiveScale(), UIParent:GetEffectiveScale()
	if ps and us and us > 0 then
		ratio = ps / us
	end
	local midX, midY = (GetScreenWidth() or 1024) / 2, (GetScreenHeight() or 768) * 0.45
	local tname = UnitExists("target") and UnitName("target") or nil
	local kids = { WorldFrame:GetChildren() }
	for i = 1, table.getn(kids) do
		local f = kids[i]
		if f:IsShown() and f:GetName() == nil then
			local w = f:GetWidth()
			if w and w > 60 and w < 200 then
				plateCount = plateCount + 1
				local regs = { f:GetRegions() }
				for j = 1, table.getn(regs) do
					local r = regs[j]
					if r:GetObjectType() == "FontString" then
						local t = r:GetText()
						if t and sums[t] then
							local cx, cy = f:GetCenter()
							if cx and cy then
								-- plates use WorldFrame scale; convert to UIParent units
								local fs = f:GetEffectiveScale()
								local k = 1
								if fs and us and us > 0 then
									k = fs / us
								end
								local px, py = cx * k, cy * k
								-- several enemies share a name: the hit one is unknown. Prefer the
								-- target's plate, else the plate closest to the hero (screen centre).
								local score = math.abs(px - midX) + math.abs(py - midY)
								if tname and t == tname and f:GetAlpha() >= 0.99 then
									score = -1
								end
								local old = plates[t]
								if not old or score < old[3] then
									plates[t] = { px, py, score }
								end
							end
						end
					end
				end
			end
		end
	end
end

-- flush ----------------------------------------------------------------
local sw = 0
local function flush()
	local any = false
	for _ in pairs(sums) do
		any = true
		break
	end
	local n = 0
	if any then
		findPlates()
		local sc = UIParent:GetEffectiveScale()
		local midx = (GetScreenWidth() or 1024) / 2
		local topy = (GetScreenHeight() or 768) * 0.62
		-- only enemies whose nameplate is on screen get a number (no pile at a fixed spot);
		-- without any nameplates (switched off) fall back to the screen centre.
		-- At most MAXN numbers per window: crits first, then the biggest.
		local list = {}
		for name, amount in pairs(sums) do
			local p = plates[name]
			if p or plateCount == 0 then
				local score = amount
				if crits[name] then
					score = score + 1e9
				end
				list[table.getn(list) + 1] = { name = name, amount = amount, crit = crits[name], p = p, score = score }
			end
			sums[name] = nil
			crits[name] = nil
		end
		table.sort(list, function(a, b)
			return a.score > b.score
		end)
		local cnt = table.getn(list)
		if cnt > MAXN then
			cnt = MAXN
		end
		for n = 1, cnt do
			local e = list[n]
			local x, y
			if e.p then
				x, y = e.p[1], e.p[2] + 28
			else
				x, y = midx, topy
			end
			local jit = (math.mod(n, 3) - 1) * 22 + (math.random() - 0.5) * 14
			if e.crit then
				spawn(short(e.amount), x + jit, y, true, 1, 0.694, 0)
			else
				spawn(short(e.amount), x + jit, y, false, 1, 1, 1)
			end
		end
	end
	if takenSum > 0 then
		local x = (GetScreenWidth() or 1024) / 2 + (math.random() - 0.5) * 60
		local y = (GetScreenHeight() or 768) * 0.42
		if takenCrit then
			spawn("-" .. short(takenSum), x, y, true, 1, 0.25, 0.2, true)
		else
			spawn("-" .. short(takenSum), x, y, false, 0.95, 0.4, 0.3, true)
		end
		takenSum, takenCrit = 0, false
	end
end

-- events ---------------------------------------------------------------
local ev = CreateFrame("Frame")
local DEALT = { CHAT_MSG_SPELL_SELF_DAMAGE = true, CHAT_MSG_COMBAT_SELF_HITS = true }
local PERIODIC = { CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE = true, CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE = true }
local TAKEN = {
	CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = true, CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE = true,
	CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS = true, CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE = true,
}

local function onChat(evt, msg)
	if not msg then
		return
	end
	if DEALT[evt] then
		local _, _, sp, name, num = string.find(msg, "^Your (.-) crits (.-) for (%d+)")
		if num then
			addDealt(name, tonumber(num), true)
			return
		end
		_, _, sp, name, num = string.find(msg, "^Your (.-) hits (.-) for (%d+)")
		if num then
			addDealt(name, tonumber(num), false)
			return
		end
		_, _, name, num = string.find(msg, "^You crit (.-) for (%d+)")
		if num then
			addDealt(name, tonumber(num), true)
			return
		end
		_, _, name, num = string.find(msg, "^You hit (.-) for (%d+)")
		if num then
			addDealt(name, tonumber(num), false)
		end
	elseif PERIODIC[evt] then
		local _, _, name, num = string.find(msg, "^(.-) suffers (%d+) .- damage from your")
		if num then
			addDealt(name, tonumber(num), false)
		end
	elseif TAKEN[evt] then
		local _, _, num = string.find(msg, " crits you for (%d+)")
		if num then
			addTaken(tonumber(num), true)
			return
		end
		_, _, num = string.find(msg, " hits you for (%d+)")
		if num then
			addTaken(tonumber(num), false)
		end
	end
end

local EVENTS = {
	"CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_COMBAT_SELF_HITS",
	"CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
	"CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
	"CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS", "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
}

local ticker = CreateFrame("Frame")
local function apply()
	local on = mode() ~= "off"
	for i = 1, table.getn(EVENTS) do
		if on then
			ev:RegisterEvent(EVENTS[i])
		else
			ev:UnregisterEvent(EVENTS[i])
		end
	end
	if on then
		ticker:SetScript("OnUpdate", function()
			sw = sw + arg1
			if sw >= WINDOW then
				sw = 0
				flush()
			end
		end)
		-- our numbers replace the client's
		if not cfg().owned then
			local ok, v = pcall(GetCVar, "CombatDamage")
			cfg().prev = (ok and v) or "1"
			cfg().owned = true
		end
		pcall(SetCVar, "CombatDamage", "0")
	else
		ticker:SetScript("OnUpdate", nil)
		for k in pairs(sums) do
			sums[k] = nil
			crits[k] = nil
		end
		takenSum, takenCrit = 0, false
		if cfg().owned then
			pcall(SetCVar, "CombatDamage", cfg().prev or "1")
			cfg().owned = nil
		end
	end
end

ev:SetScript("OnEvent", function()
	onChat(event, arg1)
end)

local function hubHook()
	if not AegisUI or AegisUI.hooked_ct then
		return
	end
	AegisUI.hooked_ct = true
	AegisUI.api.ct = {
		getMode = function()
			return mode()
		end,
		cycleMode = function()
			local cur = mode()
			local nxt = "crit"
			if cur == "crit" then
				nxt = "all"
			elseif cur == "all" then
				nxt = "off"
			end
			cfg().mode = nxt
			apply()
		end,
		getSize = function()
			return sizeKey()
		end,
		cycleSize = function()
			local cur = sizeKey()
			local nxt = "medium"
			if cur == "medium" then
				nxt = "large"
			elseif cur == "large" then
				nxt = "small"
			end
			cfg().size = nxt
		end,
		test = function()
			local x, y = (GetScreenWidth() or 1024) / 2, (GetScreenHeight() or 768) * 0.62
			spawn("1234", x - 40, y, false, 1, 1, 1)
			spawn("5678", x + 40, y, true, 1, 0.694, 0)
			spawn("-210", x, (GetScreenHeight() or 768) * 0.42, false, 0.95, 0.4, 0.3, true)
		end,
	}
end
hubHook()
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:SetScript("OnEvent", function()
	hubHook()
	apply()
end)
