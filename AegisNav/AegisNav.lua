-- AegisNav: TomTom-style waypoint arrow for Azeroth Survivors (WoW 1.12 client, Lua 5.0).
-- Targets come from the game itself: AZS_GetGuardians() and AZS_GetLairs() (map coords mx/my, 0..1).
-- The arrow is a rotated texture (8-argument SetTexCoord). Heading uses GetPlayerFacing if the
-- client has it, otherwise it is derived from your last movement (so walk a few steps first).

local L = AegisL.t

local SOLID = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local ARROW = "Interface\\AddOns\\AegisNav\\arrow"

local N = {
	enabled = true,
	manual = nil,     -- nil = auto, otherwise index into the target list (/aegisnav next)
	aspect = 1.5,     -- map width / height, needed to turn map units into a real angle
	yards = 2400,     -- rough width of the map in yards (only used for the distance text)
	heading = nil,    -- clockwise from north, radians
	lx = nil,
	ly = nil,
	acc = 0,
}

local function say(text)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisNav:|r " .. text)
	end
end

local function coordsOf(e)
	if type(e) ~= "table" then
		return nil
	end
	local x = e.mx or e.x or e.mapX
	local y = e.my or e.y or e.mapY
	x = tonumber(x)
	y = tonumber(y)
	if x and y and (x ~= 0 or y ~= 0) then
		return x, y
	end
	return nil
end

-- Target list ----------------------------------------------------------
-- Guardians carry no coordinates, their lair does (same id). Chests have their own coordinates.

local function worldOf(e)
	if type(e) == "table" and e.mx then
		local wx, wy = tonumber(e.x), tonumber(e.y)
		if wx and wy then
			return wx, wy
		end
	end
	return nil
end

local function collect()
	local list = {}
	local lairs = {}
	local ok2, l = pcall(AZS_GetLairs or function() end)
	if ok2 and type(l) == "table" then
		local i
		for i = 1, table.getn(l) do
			local x, y = coordsOf(l[i])
			if x then
				local wx, wy = worldOf(l[i])
				lairs[table.getn(lairs) + 1] = { x = x, y = y, wx = wx, wy = wy, id = l[i].id, index = l[i].index or i,
					active = l[i].active, left = tonumber(l[i].left) }
			end
		end
	end
	local used = {}
	local ok, g = pcall(AZS_GetGuardians or function() end)
	if ok and type(g) == "table" then
		local i, j
		for i = 1, table.getn(g) do
			local e = g[i]
			local x, y = coordsOf(e)
			local wx, wy = worldOf(e)
			if not x then
				for j = 1, table.getn(lairs) do
					if lairs[j].id and lairs[j].id == e.id then
						x, y = lairs[j].x, lairs[j].y
						wx, wy = lairs[j].wx, lairs[j].wy
						used[j] = true
					end
				end
			end
			if x then
				list[table.getn(list) + 1] = { name = e.name or ("Guardian " .. i), x = x, y = y, wx = wx, wy = wy,
					kind = "guardian", awake = e.awake, raw = e }
			end
		end
	end
	local okb, bs = pcall(AZS_GetBosses or function() end)
	if okb and type(bs) == "table" then
		local i, j
		for i = 1, table.getn(bs) do
			local x, y = coordsOf(bs[i])
			local wx, wy = worldOf(bs[i])
			if not x and bs[i].id then
				-- no map position of its own: use the lair with the same id
				for j = 1, table.getn(lairs) do
					if lairs[j].id and lairs[j].id == bs[i].id then
						x, y = lairs[j].x, lairs[j].y
						wx, wy = lairs[j].wx, lairs[j].wy
						used[j] = true
					end
				end
			end
			if x then
				list[table.getn(list) + 1] = { name = bs[i].name or "Boss", x = x, y = y, wx = wx, wy = wy, kind = "boss", awake = true, raw = bs[i] }
			end
		end
	end
	local ok3, c = pcall(function() return AZS_CHESTS end)
	if ok3 and type(c) == "table" then
		local i
		for i = 1, table.getn(c) do
			local x, y = coordsOf(c[i])
			local wx, wy = worldOf(c[i])
			if x then
				list[table.getn(list) + 1] = { name = L("Chest"), x = x, y = y, wx = wx, wy = wy, kind = "chest" }
			end
		end
	end
	local j
	for j = 1, table.getn(lairs) do
		if not used[j] then
			list[table.getn(list) + 1] = { name = "Lair " .. lairs[j].index, x = lairs[j].x, y = lairs[j].y, wx = lairs[j].wx, wy = lairs[j].wy,
				kind = "lair", index = lairs[j].index, active = lairs[j].active, left = lairs[j].left }
		end
	end
	return list
end

local function dist2(px, py, t)
	local dx = (t.x - px) * N.aspect
	local dy = t.y - py
	return dx * dx + dy * dy
end

local function nearest(list, px, py, test)
	local best, bd
	local i
	for i = 1, table.getn(list) do
		local t = list[i]
		if test(t) then
			local d = dist2(px, py, t)
			if not bd or d < bd then
				best, bd = t, d
			end
		end
	end
	return best
end

local function choose(list, px, py)
	local n = table.getn(list)
	if n == 0 then
		return nil
	end
	if N.manual then
		return list[math.mod(N.manual, n) + 1]
	end
	-- boss that is up > fighting guardian > any guardian that is up > chest (only when no guardian is left) > lair
	local t = nearest(list, px, py, function(x) return x.kind == "boss" end)
	if t then return t end
	t = nearest(list, px, py, function(x) return x.kind == "guardian" and x.awake end)
	if t then return t end
	t = nearest(list, px, py, function(x) return x.kind == "guardian" end)
	if t then return t end
	t = nearest(list, px, py, function(x) return x.kind == "chest" end)
	if t then return t end
	t = nearest(list, px, py, function(x) return x.kind == "lair" and x.active end)
	if t then return t end
	local soon, best
	local i
	for i = 1, n do
		local x = list[i]
		if x.kind == "lair" and x.left and x.left >= 0 and (not soon or x.left < soon) then
			best, soon = x, x.left
		end
	end
	return best
end

-- Window ---------------------------------------------------------------

local frame = CreateFrame("Frame", "AegisNavFrame", UIParent)
frame:SetWidth(150)
frame:SetHeight(128)
frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 } })
-- the box around the arrow is fully transparent; only arrow, texts and the HP bar show
frame:SetBackdropColor(0.04, 0.05, 0.08, 0)
frame:SetBackdropBorderColor(0.14, 0.16, 0.22, 0)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function()
	if AegisUI and AegisUI.locked then
		return
	end
	this:StartMoving()
end)
frame:SetScript("OnDragStop", function()
	if AegisUI and AegisUI.locked then
		return
	end
	this:StopMovingOrSizing()
	if AegisUI and AegisUI.snapFrame then
		AegisUI.snapFrame(this)
	end
	local point, _, rel, x, y = this:GetPoint(1)
	if point then
		AegisNavDB = AegisNavDB or {}
		AegisNavDB.point, AegisNavDB.rel, AegisNavDB.x, AegisNavDB.y = point, rel, x, y
	end
end)

local gold = frame:CreateTexture(nil, "OVERLAY")
gold:SetTexture(SOLID)
gold:SetVertexColor(0.78, 0.58, 0.22, 0)
gold:SetHeight(1)
gold:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
gold:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

-- short gold flash behind the arrow when a new target is logged
local flash = frame:CreateTexture(nil, "BACKGROUND")
flash:SetTexture("Interface\\Buttons\\WHITE8X8")
flash:SetBlendMode("ADD")
flash:SetVertexColor(0.78, 0.58, 0.22, 1)
flash:SetWidth(64)
flash:SetHeight(64)
flash:SetPoint("TOP", frame, "TOP", 0, -2)
flash:SetAlpha(0)
local flashLeft = 0
local FLASH_TIME = 0.8
local flashFrame = CreateFrame("Frame")
flashFrame:SetScript("OnUpdate", function()
	if flashLeft <= 0 then
		return
	end
	flashLeft = flashLeft - (arg1 or 0)
	if flashLeft <= 0 then
		flash:SetAlpha(0)
		return
	end
	-- two quick pulses over 0.8 s
	local ph = (FLASH_TIME - flashLeft) / FLASH_TIME
	local a = math.abs(math.sin(ph * math.pi * 2)) * (1 - ph) * 0.65
	flash:SetAlpha(a)
end)

local arrow = frame:CreateTexture(nil, "ARTWORK")
arrow:SetTexture(ARROW)
arrow:SetWidth(56)
arrow:SetHeight(56)
arrow:SetPoint("TOP", frame, "TOP", 0, -6)

local nameText = frame:CreateFontString(nil, "OVERLAY")
nameText:SetFont(FONT, 11, "OUTLINE")
nameText:SetPoint("TOP", arrow, "BOTTOM", 0, -2)
nameText:SetTextColor(1, 0.85, 0.4, 1)

local distText = frame:CreateFontString(nil, "OVERLAY")
distText:SetFont("Fonts\\ARIALN.TTF", 13, "OUTLINE")
distText:SetPoint("TOP", nameText, "BOTTOM", 0, -2)
distText:SetTextColor(1, 1, 1, 1)

-- HP bar of the guardian that is awake (being fought), from the game's own guardian data
local hpBack = CreateFrame("Frame", nil, frame)
hpBack:SetWidth(134)
hpBack:SetHeight(16)
hpBack:SetPoint("BOTTOM", frame, "BOTTOM", 0, 6)
hpBack:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 } })
hpBack:SetBackdropColor(0.04, 0.05, 0.08, 0.96)
hpBack:SetBackdropBorderColor(0.14, 0.16, 0.22, 1)

local hpGold = hpBack:CreateTexture(nil, "OVERLAY")
hpGold:SetTexture(SOLID)
hpGold:SetVertexColor(0.78, 0.58, 0.22, 1)
hpGold:SetHeight(1)
hpGold:SetPoint("TOPLEFT", hpBack, "TOPLEFT", 1, -1)
hpGold:SetPoint("TOPRIGHT", hpBack, "TOPRIGHT", -1, -1)

local hpFill = hpBack:CreateTexture(nil, "ARTWORK")
hpFill:SetTexture(SOLID)
hpFill:SetPoint("TOPLEFT", hpBack, "TOPLEFT", 1, -1)
hpFill:SetHeight(14)
hpFill:SetWidth(1)

local hpText = hpBack:CreateFontString(nil, "OVERLAY")
hpText:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
hpText:SetPoint("CENTER", hpBack, "CENTER", 0, 0)

-- enrage hint above the bar (shown for a boss below 30 % HP)
local hpWarn = hpBack:CreateFontString(nil, "OVERLAY")
hpWarn:SetFont(FONT, 10, "OUTLINE")
hpWarn:SetPoint("BOTTOM", hpBack, "TOP", 0, 2)
hpWarn:SetText("! ENRAGE !")
hpWarn:Hide()

local function big(n)
	if n >= 1000000000 then
		return string.format("%.2fB", n / 1000000000)
	elseif n >= 1000000 then
		return string.format("%.2fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(math.floor(n + 0.5))
end

local function readHealth()
	-- 1) a boss that is up (e.g. Warchief Rend Blackhand)
	local okb, bs = pcall(AZS_GetBosses or function() end)
	if okb and type(bs) == "table" then
		local i
		for i = 1, table.getn(bs) do
			local e = bs[i]
			local hp = tonumber(e.hp)
			local mx = tonumber(e.hpm or e.maxhp)
			if hp and mx and mx > 0 and hp > 0 then
				return hp, mx, e.name, true
			end
		end
	end
	-- 2) otherwise the guardian that is awake (= being fought)
	local ok, g = pcall(AZS_GetGuardians or function() end)
	if ok and type(g) == "table" then
		local i
		for i = 1, table.getn(g) do
			local e = g[i]
			if e.awake then
				local hp = tonumber(e.hp)
				local mx = tonumber(e.hpm or e.maxhp)
				if hp and mx and mx > 0 then
					return hp, mx, e.name
				end
			end
		end
	end
	return nil
end

local function updateBar()
	local hp, mx, nm, isBoss = readHealth()
	if not hp then
		hpBack:Hide()
		return
	end
	hpBack:Show()
	local frac = hp / mx
	if frac < 0 then
		frac = 0
	elseif frac > 1 then
		frac = 1
	end
	hpFill:SetWidth(math.max(1, 132 * frac))
	-- green (full) -> orange -> red (empty), same ramp as the player card
	local cr, cg, cb
	if frac > 0.5 then
		local k = (frac - 0.5) * 2
		cr, cg, cb = 0.96 + (0.10 - 0.96) * k, 0.62 + (0.80 - 0.62) * k, 0.18 + (0.45 - 0.18) * k
	else
		local k = frac * 2
		cr, cg, cb = 0.74 + (0.96 - 0.74) * k, 0.16 + (0.62 - 0.16) * k, 0.26 + (0.18 - 0.26) * k
	end
	if isBoss and frac < 0.30 then
		-- phase 2: pulsing dark red <-> gold, gold frame and a warning text
		local p = 0.5 + 0.5 * math.sin(GetTime() * 6)
		cr = 0.55 + (0.78 - 0.55) * p
		cg = 0.08 + (0.58 - 0.08) * p
		cb = 0.12 + (0.22 - 0.12) * p
		hpBack:SetBackdropBorderColor(0.78, 0.58 * p + 0.1, 0.22 * p, 1)
		hpGold:SetVertexColor(1, 0.3 + 0.5 * p, 0.1, 1)
		hpWarn:SetTextColor(1, 0.35 + 0.5 * p, 0.15 + 0.1 * p)
		hpWarn:Show()
	else
		hpBack:SetBackdropBorderColor(0.14, 0.16, 0.22, 1)
		hpGold:SetVertexColor(0.78, 0.58, 0.22, 1)
		hpWarn:Hide()
	end
	hpFill:SetVertexColor(cr, cg, cb, 1)
	if mx == 100 then
		hpText:SetText(math.floor(frac * 100 + 0.5) .. "%")
	else
		hpText:SetText(big(hp) .. " / " .. big(mx) .. "  " .. math.floor(frac * 100 + 0.5) .. "%")
	end
end

local function setArrow(angle)
	-- rotate the texture window around its centre; negative = arrow turns clockwise
	local c = math.cos(angle)
	local s = math.sin(angle)
	local function pt(x, y)
		local ox, oy = x - 0.5, y - 0.5
		return 0.5 + ox * c - oy * s, 0.5 + ox * s + oy * c
	end
	local ulx, uly = pt(0, 0)
	local llx, lly = pt(0, 1)
	local urx, ury = pt(1, 0)
	local lrx, lry = pt(1, 1)
	arrow:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

-- Update ---------------------------------------------------------------

local function currentHeading(px, py)
	if GetPlayerFacing then
		local f = GetPlayerFacing()
		if f then
			return -f
		end
	end
	if N.lx then
		local dx = (px - N.lx) * N.aspect
		local dy = py - N.ly
		if dx * dx + dy * dy > 0.0000004 then
			N.heading = math.atan2(dx, -dy)
			N.lx, N.ly = px, py
		end
	else
		N.lx, N.ly = px, py
	end
	return N.heading
end

local function update()
	local px, py = 0, 0
	if GetPlayerMapPosition then
		px, py = GetPlayerMapPosition("player")
	end
	if not px or (px == 0 and py == 0) then
		nameText:SetText(L("no position"))
		distText:SetText("")
		return
	end
	local list = collect()
	local t = choose(list, px, py)
	N.cur = t
	local key = nil
	if t then
		key = tostring(t.name) .. ":" .. tostring(t.x) .. ":" .. tostring(t.y)
	end
	if key and key ~= N.lastKey then
		flashLeft = FLASH_TIME
	end
	N.lastKey = key
	if not t then
		nameText:SetText(L("no target"))
		distText:SetText("")
		setArrow(0)
		return
	end

	local dx = (t.x - px) * N.aspect
	local dy = t.y - py
	local d = math.sqrt(dx * dx + dy * dy) * N.yards
	-- exact yards from the game's world coordinates when both sides have them
	local run = AZS_RUN
	if t.wx and type(run) == "table" and tonumber(run.px) and tonumber(run.py) then
		local nx, ey = t.wx - tonumber(run.px), t.wy - tonumber(run.py)
		d = math.sqrt(nx * nx + ey * ey)
	end
	local bearing = math.atan2(dx, -dy)
	local head = currentHeading(px, py)

	local label = t.name
	if t.kind == "guardian" and t.awake then
		label = label .. L(" (combat)")
	elseif t.kind == "boss" then
		label = label .. " (Boss)"
	end
	if t.kind == "lair" then
		if t.active then
			label = label .. L(" (active)")
		elseif t.left and t.left >= 0 then
			label = label .. " in " .. math.floor(t.left) .. "s"
		end
	end
	nameText:SetText(label)

	if d < 15 then
		distText:SetText(L("here!"))
	else
		distText:SetText(math.floor(d + 0.5) .. " yd")
	end

	if head then
		setArrow(-(bearing - head))
	else
		-- no heading yet: point north-up and ask for movement
		setArrow(0)
		distText:SetText(distText:GetText() .. L("  (running)"))
	end
end

-- keep chosen parts of the game's own HUD hidden (the game may re-show them, so re-check now and then)
local function enforceHud()
	if not AZS_SetHudShown or not AZS_IsHudShown or not AegisNavDB or not AegisNavDB.hud then
		return
	end
	local name, want
	for name, want in pairs(AegisNavDB.hud) do
		local shown = AZS_IsHudShown(name) and true or false
		if shown ~= want then
			AZS_SetHudShown(name, want)
		end
	end
end

frame:SetScript("OnUpdate", function()
	N.acc = N.acc + (arg1 or 0)
	N.hudAcc = (N.hudAcc or 0) + (arg1 or 0)
	if N.hudAcc > 2 then
		N.hudAcc = 0
		pcall(enforceHud)
	end
	if N.acc < 0.05 then
		return
	end
	N.acc = 0
	local ok, err = pcall(update)
	pcall(updateBar)
	if not ok and not N.told then
		N.told = true
		say(L("Error: ") .. tostring(err))
	end
end)

-- Saved position + commands -------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
	if arg1 ~= "AegisNav" then
		return
	end
	AegisNavDB = AegisNavDB or {}
	if not AegisNavDB.hud then
		AegisNavDB.hud = { bosses = false }
	end
	if AegisNavDB.point then
		frame:ClearAllPoints()
		frame:SetPoint(AegisNavDB.point, UIParent, AegisNavDB.rel or AegisNavDB.point, AegisNavDB.x or 0, AegisNavDB.y or 0)
	end
	if AegisNavDB.aspect then
		N.aspect = AegisNavDB.aspect
	end
	if AegisNavDB.yards then
		N.yards = AegisNavDB.yards
	end
	if AegisNavDB.hidden then
		frame:Hide()
	end
end)

SLASH_AEGISNAV1 = "/aegisnav"
SlashCmdList["AEGISNAV"] = function(msg)
	msg = string.lower(msg or "")
	AegisNavDB = AegisNavDB or {}
	local _, _, cmd, arg = string.find(msg, "^(%S*)%s*(%S*)")
	if cmd == "next" then
		N.manual = (N.manual or -1) + 1
		say(L("Target changed. /aegisnav auto = automatic again."))
	elseif cmd == "auto" then
		N.manual = nil
		say(L("Automatic target (fighting guardian, chest, guardian, lair)."))
	elseif cmd == "aspect" and tonumber(arg) then
		N.aspect = tonumber(arg)
		AegisNavDB.aspect = N.aspect
		say(L("Map aspect ratio ") .. N.aspect)
	elseif cmd == "yards" and tonumber(arg) then
		N.yards = tonumber(arg)
		AegisNavDB.yards = N.yards
		say(L("Map width ") .. N.yards .. L(" yd (only used for the distance display)"))
	elseif cmd == "hud" then
		-- /aegisnav hud <name> on|off : show or hide one of the game's own HUD parts (names: see /aegismeter inspect)
		local _, _, hname, hstate = string.find(msg, "^hud%s+(%S+)%s*(%S*)")
		if not hname then
			say(L("Usage: /aegisnav hud <name> on|off"))
		elseif not AZS_SetHudShown then
			say(L("AZS_SetHudShown is missing in this client."))
		else
			AegisNavDB.hud = AegisNavDB.hud or {}
			if hstate == "on" then
				AegisNavDB.hud[hname] = true
				AZS_SetHudShown(hname, true)
			elseif hstate == "off" then
				AegisNavDB.hud[hname] = false
				AZS_SetHudShown(hname, false)
			end
			say(hname .. L(" visible: ") .. tostring(AZS_IsHudShown and AZS_IsHudShown(hname)))
		end
	elseif cmd == "info" then
		local list = collect()
		local i
		say(table.getn(list) .. L(" targets, heading ") .. tostring(N.heading) .. ", GetPlayerFacing " .. tostring(GetPlayerFacing ~= nil))
		for i = 1, table.getn(list) do
			local t = list[i]
			say(t.name .. " " .. t.kind .. " x=" .. string.format("%.3f", t.x) .. " y=" .. string.format("%.3f", t.y) .. " active=" .. tostring(t.active) .. " left=" .. tostring(t.left))
		end
	else
		if frame:IsShown() then
			frame:Hide()
			AegisNavDB.hidden = true
		else
			frame:Show()
			AegisNavDB.hidden = false
		end
	end
end

-- Hub integration ------------------------------------------------------

local function hubHook()
	if not AegisUI or AegisUI.hooked_nav then
		return
	end
	AegisUI.hooked_nav = true
	AegisUI.register("nav", "Arrow / boss HP", frame, function()
		AegisNavDB = AegisNavDB or {}
		AegisNavDB.point, AegisNavDB.rel, AegisNavDB.x, AegisNavDB.y = nil, nil, nil, nil
		frame:ClearAllPoints()
		frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
	end)
	AegisUI.api.nav = {
		version = "5.4.14",
		isShown = function()
			return frame:IsShown()
		end,
		setShown = function(on)
			AegisNavDB = AegisNavDB or {}
			if on then
				frame:Show()
			else
				frame:Hide()
			end
			AegisNavDB.hidden = not on
		end,
		-- parts of the game's own HUD (names from AZS_HUD_CVARS), kept hidden by enforceHud
		getHudHidden = function(name)
			return AegisNavDB ~= nil and AegisNavDB.hud ~= nil and AegisNavDB.hud[name] == false
		end,
		setHudHidden = function(name, hidden)
			AegisNavDB = AegisNavDB or {}
			AegisNavDB.hud = AegisNavDB.hud or {}
			AegisNavDB.hud[name] = not hidden
			if AZS_SetHudShown then
				AZS_SetHudShown(name, not hidden)
			end
		end,
	}
end

hubHook()
local hookEv = CreateFrame("Frame")
hookEv:RegisterEvent("PLAYER_LOGIN")
hookEv:SetScript("OnEvent", hubHook)
