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
	-- a cache only counts while its price is covered by the run gold (AZS_RUN.gold >= AZS_RUN.chest)
	local run0 = AZS_RUN
	local afford = true
	if type(run0) == "table" and tonumber(run0.chest) and tonumber(run0.gold) and tonumber(run0.chest) > 0 then
		afford = tonumber(run0.gold) >= tonumber(run0.chest)
	end
	if not afford then
		c = nil
	end
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
frame:EnableMouse(false)
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

local function drawArrow(angle)
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

-- the update step only sets the wanted angle; the arrow turns towards it a little every frame
-- (shortest way round), so the rotation looks smooth instead of jumping at 20 Hz
local function setArrow(angle)
	N.want = angle
	if N.have == nil then
		N.have = angle
		drawArrow(angle)
	end
end

local TWO_PI = math.pi * 2
local function smoothArrow(dt)
	if N.want == nil or N.have == nil then
		return
	end
	local d = N.want - N.have
	d = d - TWO_PI * math.floor((d + math.pi) / TWO_PI)
	if math.abs(d) < 0.002 then
		if N.have ~= N.want then
			N.have = N.want
			drawArrow(N.have)
		end
		return
	end
	local k = dt * 16
	if k > 1 then
		k = 1
	end
	N.have = N.have + d * k
	drawArrow(N.have)
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
	-- the box only catches the mouse while the layout is unlocked (so clicks and the camera work through it)
	local wantMouse = not (AegisUI and AegisUI.locked)
	if N.mouse ~= wantMouse then
		N.mouse = wantMouse
		frame:EnableMouse(wantMouse)
	end
	smoothArrow(arg1 or 0)
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

-- Timer widget: run clock, boss list of the zone, guardians (UP / respawn) ---------

local TW = 176
local ROW_H = 14
local MAX_ROWS = 15
local T = { acc = 0, rows = {}, bosses = {} }
local tf = CreateFrame("Frame", "AegisTimerFrame", UIParent)
tf:SetWidth(TW)
tf:SetHeight(54)
tf:SetPoint("LEFT", UIParent, "LEFT", 24, 120)
tf:SetFrameStrata("MEDIUM")
tf:SetMovable(true)
tf:EnableMouse(false)
tf:SetClampedToScreen(true)
tf:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 } })
tf:SetBackdropColor(0.04, 0.05, 0.08, 0.7)
tf:SetBackdropBorderColor(0.55, 0.43, 0.15, 1)
if AegisSkin and AegisSkin.TrackPanel then
	pcall(AegisSkin.TrackPanel, tf, { 0.04, 0.05, 0.08 }, { 0.55, 0.43, 0.15 }, nil, "nav")
end
tf:RegisterForDrag("LeftButton")
tf:SetScript("OnDragStart", function()
	if AegisUI and AegisUI.locked then
		return
	end
	this:StartMoving()
end)
tf:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
	local point, _, rel, x, y = this:GetPoint(1)
	if point then
		AegisNavDB = AegisNavDB or {}
		AegisNavDB.tpoint, AegisNavDB.trel, AegisNavDB.tx, AegisNavDB.ty = point, rel, x, y
	end
end)

local function getRow(i)
	local r = T.rows[i]
	if r then
		return r
	end
	r = {}
	local y = -6 - (i - 1) * ROW_H
	r.name = tf:CreateFontString(nil, "OVERLAY")
	r.name:SetFont(FONT, 11)
	r.name:SetPoint("TOPLEFT", tf, "TOPLEFT", 8, y)
	r.name:SetWidth(TW - 66)
	r.name:SetJustifyH("LEFT")
	r.val = tf:CreateFontString(nil, "OVERLAY")
	r.val:SetFont(FONT, 11)
	r.val:SetPoint("TOPRIGHT", tf, "TOPRIGHT", -8, y)
	r.val:SetJustifyH("RIGHT")
	r.st = tf:CreateTexture(nil, "OVERLAY")
	r.st:SetTexture(SOLID)
	r.st:SetHeight(1)
	r.st:SetVertexColor(0.85, 0.85, 0.85, 0.8)
	r.st:SetPoint("LEFT", r.name, "LEFT", 0, 0)
	r.st:Hide()
	T.rows[i] = r
	return r
end

-- one line: name (left), value (right), colours, alpha; strike = crossed out
local function setRow(i, name, val, nr, ng, nb, vr, vg, vb, alpha, strike)
	local r = getRow(i)
	r.name:SetText(name)
	r.name:SetTextColor(nr, ng, nb)
	r.name:SetAlpha(alpha)
	r.val:SetText(val or "")
	r.val:SetTextColor(vr, vg, vb)
	r.val:SetAlpha(alpha)
	r.name:Show()
	r.val:Show()
	if strike then
		local w = r.name:GetStringWidth() or 40
		if w > TW - 66 then
			w = TW - 66
		end
		r.st:SetWidth(w)
		r.st:SetAlpha(alpha)
		r.st:Show()
	else
		r.st:Hide()
	end
end

local function hideRowsFrom(n)
	local i
	for i = n, table.getn(T.rows) do
		T.rows[i].name:Hide()
		T.rows[i].val:Hide()
		T.rows[i].st:Hide()
	end
end

local function clock(sec)
	sec = math.floor(sec)
	local h = math.floor(sec / 3600)
	local m = math.floor(math.mod(sec, 3600) / 60)
	return string.format("%02d:%02d:%02d", h, m, math.mod(sec, 60))
end

local function mmss(sec)
	sec = math.floor(sec)
	return string.format("%d:%02d", math.floor(sec / 60), math.mod(sec, 60))
end

local function timerUpdate()
	local rt = AZS_GetRunTime and AZS_GetRunTime()
	local phase = AZS_GetPhase and AZS_GetPhase()
	AegisNavDB = AegisNavDB or {}

	-- the boss list belongs to one run: after /reload the saved list is picked up again, a new run starts clean
	if not T.restored then
		T.restored = true
		if AegisNavDB.tboss and rt and AegisNavDB.tlastrt and rt >= AegisNavDB.tlastrt - 3 then
			T.bosses = AegisNavDB.tboss
		end
	end
	if not phase or phase == "ready" or (rt and T.lastRt and rt + 5 < T.lastRt) then
		T.bosses = {}
	end
	T.lastRt = rt

	-- boss list: bosses still to come, alive ones, and the ones that are gone (slain)
	local pass = (T.pass or 0) + 1
	T.pass = pass
	local okU, up = pcall(AZS_GetUpcomingBosses or function() end)
	if okU and type(up) == "table" then
		local i
		for i = 1, table.getn(up) do
			local key = up[i].index or i
			local b = T.bosses[key] or {}
			b.name, b.final, b.left, b.seen = up[i].name, up[i].final, up[i].left, pass
			T.bosses[key] = b
		end
	end
	local alive = {}
	local okA, al = pcall(AZS_GetBosses or function() end)
	if okA and type(al) == "table" then
		local i
		for i = 1, table.getn(al) do
			if al[i].name then
				alive[al[i].name] = true
			end
		end
	end
	AegisNavDB.tboss, AegisNavDB.tlastrt = T.bosses, rt

	local n = 1
	setRow(n, L("Run"), rt and clock(rt) or "--:--:--", 0.85, 0.75, 0.40, 0.85, 0.75, 0.40, 1, false)

	local keys = {}
	local k, b
	for k, b in pairs(T.bosses) do
		keys[table.getn(keys) + 1] = k
	end
	table.sort(keys)
	local ki
	for ki = 1, table.getn(keys) do
		b = T.bosses[keys[ki]]
		if n < MAX_ROWS and b.name then
			n = n + 1
			if b.seen == pass then
				setRow(n, b.name, b.left and mmss(b.left) or "", 0.92, 0.92, 0.92, 0.85, 0.85, 0.90, 1, false)
			elseif alive[b.name] then
				setRow(n, b.name, "UP", 1, 0.45, 0.35, 1, 0.45, 0.35, 1, false)
			else
				setRow(n, b.name, "", 0.65, 0.65, 0.65, 0.65, 0.65, 0.65, 0.4, true)
			end
		end
	end
	-- endless mode / no list: the game's own "next boss" countdown
	if table.getn(keys) == 0 and type(AZS_RUN) == "table" and tonumber(AZS_RUN.nb) and tonumber(AZS_RUN.nb) >= 0 and n < MAX_ROWS then
		n = n + 1
		setRow(n, tostring(AZS_RUN.nbn or L("Boss")), mmss(tonumber(AZS_RUN.nb)), 0.92, 0.92, 0.92, 0.85, 0.85, 0.90, 1, false)
	end

	-- guardians: UP (asleep), fighting, or the respawn countdown of an empty lair
	local okL, l = pcall(AZS_GetLairs or function() end)
	if okL and type(l) == "table" then
		local i
		for i = 1, table.getn(l) do
			if n < MAX_ROWS then
				n = n + 1
				local nm = l[i].name
				if not nm or nm == "" then
					nm = L("Guardian") .. " " .. (l[i].index or i)
				end
				local st = l[i].state
				local left = tonumber(l[i].left)
				if st == "awake" then
					setRow(n, nm, L("FIGHT"), 0.55, 0.78, 1, 1, 0.45, 0.35, 1, false)
				elseif st == "asleep" or (not st and l[i].active) then
					setRow(n, nm, "UP", 0.55, 0.78, 1, 0.50, 1, 0.50, 1, false)
				elseif left and left > 0 then
					setRow(n, nm, mmss(left), 0.55, 0.78, 1, 0.75, 0.80, 0.90, 0.8, false)
				else
					setRow(n, nm, "...", 0.55, 0.78, 1, 0.75, 0.80, 0.90, 0.6, false)
				end
			end
		end
	end
	hideRowsFrom(n + 1)
	tf:SetHeight(12 + n * ROW_H)
end

tf:SetScript("OnUpdate", function()
	local wantMouse = not (AegisUI and AegisUI.locked)
	if T.mouse ~= wantMouse then
		T.mouse = wantMouse
		tf:EnableMouse(wantMouse)
	end
	T.acc = T.acc + (arg1 or 0)
	if T.acc < 0.25 then
		return
	end
	T.acc = 0
	pcall(timerUpdate)
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
	if AegisNavDB.tpoint then
		tf:ClearAllPoints()
		tf:SetPoint(AegisNavDB.tpoint, UIParent, AegisNavDB.trel or AegisNavDB.tpoint, AegisNavDB.tx or 0, AegisNavDB.ty or 0)
	end
	if AegisNavDB.timerHidden then
		tf:Hide()
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
	AegisUI.register("timer", "Timer", tf, function()
		AegisNavDB = AegisNavDB or {}
		AegisNavDB.tpoint, AegisNavDB.trel, AegisNavDB.tx, AegisNavDB.ty = nil, nil, nil, nil
		tf:ClearAllPoints()
		tf:SetPoint("LEFT", UIParent, "LEFT", 24, 120)
	end)
	AegisUI.api.nav = {
		version = "5.9.2",
		isShown = function()
			return frame:IsShown()
		end,
		timerShown = function()
			return tf:IsShown()
		end,
		setTimerShown = function(on)
			AegisNavDB = AegisNavDB or {}
			AegisNavDB.timerHidden = not on
			if on then tf:Show() else tf:Hide() end
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
