-- AegisUnits: dark-style unit displays for Azeroth Survivors (WoW 1.12 client, Lua 5.0).
--   1) player frame with health + mana/rage/energy bars
--   2) restyled mob nameplates (same look as the AegisNav guardian bar)
-- Nameplates only exist when the client shows them (V = enemies, Ctrl+V = friendlies).
-- Lua 5.0: no '#', no select(), no string.match.

local L = AegisL.t

local SOLID = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_NUM = "Fonts\\ARIALN.TTF"

local U = {
	plates = true,
	player = true,
	target = true,
	stockHidden = false,
	known = {},      -- frames we already looked at (value true = nameplate, false = other)
	list = {},       -- the nameplates
	childCount = 0,
	acc = 0,
	scanAcc = 0,
	stockPoint = nil,
}

local function say(text)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUnits:|r " .. text)
	end
end

local function big(n)
	n = n or 0
	if n >= 1000000 then
		return string.format("%.2fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(math.floor(n + 0.5))
end

local function skin(f)
	f:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	f:SetBackdropColor(0.06, 0.07, 0.10, 1)
	f:SetBackdropBorderColor(0.17, 0.19, 0.25, 1)
end

-- Unit cards (player + target) -----------------------------------------
-- Same construction as the AegisMeter window: dark panel, gold top line, header, bordered rows,
-- square portrait like the icon badge. The target card has no power bar, so its HP row is taller.

local C_PANEL = { 0.04, 0.05, 0.08, 0.96 }
local C_EDGE = { 0.14, 0.16, 0.22, 1 }
local C_GOLD = { 0.78, 0.58, 0.22, 1 }
local C_ROW = { 0.06, 0.07, 0.10, 1 }
local C_ROW_EDGE = { 0.17, 0.19, 0.25, 1 }

local PAD = 6
local BAR_W = 220          -- bar width
local HP_H = 16            -- health row height incl. border (with power bar)
local MP_H = 6             -- power row height incl. border
local NAME_H = 14
local ROW_Y = PAD + NAME_H + 2
local BODY_H = NAME_H + 2 + HP_H + 3 + MP_H
local POR = BODY_H
local BAR_X = PAD + POR + 6

local function healthColor(frac)
	-- bright like the meter bars: green when healthy, orange in the middle, deep red when low
	if frac < 0 then
		frac = 0
	elseif frac > 1 then
		frac = 1
	end
	if frac > 0.5 then
		local k = (frac - 0.5) * 2
		return 0.98 - 0.88 * k, 0.55 + 0.30 * k, 0.10 + 0.38 * k
	end
	local k = frac * 2
	return 0.74 + 0.24 * k, 0.16 + 0.39 * k, 0.26 - 0.16 * k
end

local function powerColor(ptype)
	if ptype == 1 then
		return 0.74, 0.16, 0.26
	elseif ptype == 3 then
		return 0.85, 0.80, 0.30
	end
	return 0.30, 0.55, 0.95
end

local function newCard(frameName, unit, hasPower)
	local c = { unit = unit }
	local f = CreateFrame("Button", frameName, UIParent)
	f:SetWidth(BAR_X + BAR_W + PAD)
	f:SetHeight(PAD * 2 + BODY_H)
	f:SetFrameStrata("MEDIUM")
	f:EnableMouse(true)
	f:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	f:SetBackdropColor(C_PANEL[1], C_PANEL[2], C_PANEL[3], C_PANEL[4])
	f:SetBackdropBorderColor(C_EDGE[1], C_EDGE[2], C_EDGE[3], C_EDGE[4])
	if AegisSkin and AegisSkin.TrackPanel then
		-- background only: the border colour follows the unit's reaction
		AegisSkin.TrackPanel(f, { C_PANEL[1], C_PANEL[2], C_PANEL[3] }, C_EDGE, nil, "units", true)
	end
	f:SetScript("OnClick", function()
		TargetUnit(unit)
	end)
	c.frame = f

	-- soft light falling from the top edge (guarded: only if the client has the call)
	local glow = f:CreateTexture(nil, "BACKGROUND")
	glow:SetTexture(SOLID)
	glow:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	glow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	glow:SetHeight(26)
	if glow.SetGradientAlpha then
		glow:SetGradientAlpha("VERTICAL", 0.05, 0.06, 0.10, 0, 0.16, 0.20, 0.32, 0.55)
	else
		glow:SetVertexColor(0.10, 0.12, 0.18, 0.4)
	end

	local gold = f:CreateTexture(nil, "OVERLAY")
	gold:SetTexture(SOLID)
	gold:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 1)
	gold:SetHeight(1)
	gold:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	gold:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)

	local function bracket(point, dx, dy)
		local h = f:CreateTexture(nil, "OVERLAY")
		h:SetTexture(SOLID)
		h:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 0.9)
		h:SetWidth(8)
		h:SetHeight(1)
		h:SetPoint(point, f, point, dx, dy)
		local v = f:CreateTexture(nil, "OVERLAY")
		v:SetTexture(SOLID)
		v:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 0.9)
		v:SetWidth(1)
		v:SetHeight(8)
		v:SetPoint(point, f, point, dx, dy)
	end
	bracket("BOTTOMLEFT", 1, 1)
	bracket("BOTTOMRIGHT", -1, 1)

	local nameFs = f:CreateFontString(nil, "OVERLAY")
	nameFs:SetFont(FONT, 11, "OUTLINE")
	nameFs:SetTextColor(1, 1, 1)
	nameFs:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_X + 2, -(PAD + 1))

	local levelFs = f:CreateFontString(nil, "OVERLAY")
	levelFs:SetFont(FONT_NUM, 10, "")
	levelFs:SetTextColor(0.49, 0.51, 0.58)
	levelFs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD + 2), -(PAD + 2))

	local badge = CreateFrame("Frame", nil, f)
	badge:SetWidth(POR)
	badge:SetHeight(POR)
	badge:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD)
	badge:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	badge:SetBackdropColor(C_ROW[1], C_ROW[2], C_ROW[3], 1)
	badge:SetBackdropBorderColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 0.85)
	local portrait = badge:CreateTexture(nil, "ARTWORK")
	portrait:SetPoint("TOPLEFT", badge, "TOPLEFT", 2, -2)
	portrait:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -2, 2)
	portrait:SetTexCoord(0.06, 0.94, 0.06, 0.94)

	local function row(h, y)
		local r = CreateFrame("Frame", nil, f)
		r:SetWidth(BAR_W)
		r:SetHeight(h)
		r:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_X, -y)
		r:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
			insets = { left = 1, right = 1, top = 1, bottom = 1 } })
		r:SetBackdropColor(C_ROW[1], C_ROW[2], C_ROW[3], C_ROW[4])
		r:SetBackdropBorderColor(C_ROW_EDGE[1], C_ROW_EDGE[2], C_ROW_EDGE[3], C_ROW_EDGE[4])
		local fill = r:CreateTexture(nil, "ARTWORK")
		fill:SetTexture(SOLID)
		fill:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
		fill:SetHeight(h - 2)
		fill:SetWidth(1)
		r.fill = fill
		return r
	end

	local hpH = HP_H
	if not hasPower then
		hpH = HP_H + 3 + MP_H
	end
	local hpBack = row(hpH, ROW_Y)
	local hpText = hpBack:CreateFontString(nil, "OVERLAY")
	hpText:SetFont(FONT, 11, "OUTLINE")
	hpText:SetTextColor(1, 1, 1)
	hpText:SetPoint("LEFT", hpBack, "LEFT", 6, 0)
	local hpPct = hpBack:CreateFontString(nil, "OVERLAY")
	hpPct:SetFont(FONT_NUM, 10, "")
	hpPct:SetTextColor(0.78, 0.80, 0.86)
	hpPct:SetPoint("RIGHT", hpBack, "RIGHT", -6, 0)

	local mpBack
	if hasPower then
		mpBack = row(MP_H, ROW_Y + HP_H + 3)
	end

	local portraitAcc = 0
	local lastName = nil

	c.update = function()
		local innerW = BAR_W - 2
		local hp, hm = UnitHealth(unit), UnitHealthMax(unit)
		if not hm or hm <= 0 then
			hm = 1
		end
		local frac = hp / hm
		if frac > 1 then
			frac = 1
		end
		hpBack.fill:SetWidth(math.max(1, innerW * frac))
		hpBack.fill:SetVertexColor(healthColor(frac))
		if hm == 100 and unit ~= "player" then
			hpText:SetText("")            -- the game only reports a percentage for this unit
			hpPct:SetText(math.floor(frac * 100 + 0.5) .. "%")
		else
			hpText:SetText(big(hp) .. " / " .. big(hm))
			hpPct:SetText("|cff6f7588·|r " .. math.floor(frac * 100 + 0.5) .. "%")
		end

		if mpBack then
			local mp, mm = UnitMana(unit), UnitManaMax(unit)
			if mm and mm > 0 then
				mpBack:Show()
				mpBack.fill:SetWidth(math.max(1, innerW * (mp / mm)))
				mpBack.fill:SetVertexColor(powerColor(UnitPowerType(unit)))
			else
				mpBack:Hide()
			end
		end

		if unit ~= "player" then
			-- edge colour by reaction: hostile red, neutral yellow, friendly green
			local r, g, b = C_EDGE[1], C_EDGE[2], C_EDGE[3]
			if UnitExists(unit) then
				if UnitIsDead(unit) then
					r, g, b = 0.3, 0.3, 0.33
				elseif UnitIsEnemy("player", unit) then
					r, g, b = 0.62, 0.16, 0.2
				elseif UnitIsFriend("player", unit) then
					r, g, b = 0.18, 0.5, 0.3
				else
					r, g, b = 0.72, 0.6, 0.2
				end
			end
			f:SetBackdropBorderColor(r, g, b, 1)
		end

		local nm = UnitName(unit) or ""
		nameFs:SetText(nm)
		local lv = UnitLevel(unit)
		local lvText = "LV " .. (lv or "")
		if lv and lv < 0 then
			lvText = "LV ??"
		end
		-- what the enemy is to the run (game API; "guardian" is only known for the target)
		local kind = AZS_UnitKind and AZS_UnitKind(unit)
		if kind == "final" then
			lvText = lvText .. "  |cffff5a4dFINAL BOSS|r"
		elseif kind == "boss" then
			lvText = lvText .. "  |cffff5a4dBOSS|r"
		elseif kind == "guardian" then
			lvText = lvText .. "  |cffff9a33GUARDIAN|r"
		elseif kind == "elite" then
			lvText = lvText .. "  |cffd2a24aELITE|r"
		elseif not kind then
			local cls = UnitClassification and UnitClassification(unit)
			if cls == "elite" or cls == "rareelite" or cls == "worldboss" then
				lvText = lvText .. "  |cffd2a24aELITE|r"
			end
		end
		levelFs:SetText(lvText)

		portraitAcc = portraitAcc + 1
		if portraitAcc >= 10 or lastName ~= nm then
			portraitAcc = 0
			lastName = nm
			if SetPortraitTexture then
				SetPortraitTexture(portrait, unit)
			end
		end
	end
	return c
end

local playerCard = newCard("AegisUnitsPlayerFrame", "player", true)
local pf = playerCard.frame
local targetCard = newCard("AegisUnitsTargetFrame", "target", false)
local tf = targetCard.frame
tf:Hide()

-- Both cards hang symmetrically around the screen centre: player left, target right.
-- gap = distance of each card's inner edge from the centre line, y = distance from the bottom.
local function layoutCards()
	local gap = (AegisUnitsDB and AegisUnitsDB.gap) or 110
	local y = (AegisUnitsDB and AegisUnitsDB.bottom) or 170
	-- gap / y are in screen units of UIParent; the cards may be scaled (offsets count in card units)
	local ps, ts = pf:GetScale() or 1, tf:GetScale() or 1
	pf:ClearAllPoints()
	pf:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOM", -gap / ps, y / ps)
	tf:ClearAllPoints()
	tf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", gap / ts, y / ts)
end
layoutCards()

pf:SetMovable(true)
pf:SetClampedToScreen(true)
pf:RegisterForDrag("LeftButton")
pf:SetScript("OnDragStart", function()
	if AegisUI and AegisUI.locked then
		return
	end
	this:StartMoving()
end)
pf:SetScript("OnDragStop", function()
	if AegisUI and AegisUI.locked then
		return
	end
	this:StopMovingOrSizing()
	if AegisUI and AegisUI.snapFrame then
		AegisUI.snapFrame(this)
	end
	local right, bottom = this:GetRight(), this:GetBottom()
	if right and bottom then
		AegisUnitsDB = AegisUnitsDB or {}
		local k = this:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local gap = UIParent:GetWidth() / 2 - right * k
		if gap < 20 then
			gap = 20
		end
		AegisUnitsDB.gap = gap
		AegisUnitsDB.bottom = bottom * k
	end
	layoutCards()   -- the target card mirrors the new position
end)

-- the target card can be dragged too (while unlocked); both cards stay symmetric
-- smooth alpha fade (0.15 -> 1 in 0.15 s); the card's size never changes
tf:SetScript("OnUpdate", function()
	local t = this.aTarget or 1
	local a = this:GetAlpha()
	if a ~= t then
		local step = (arg1 or 0) * (0.85 / 0.15)
		if a < t then
			a = math.min(t, a + step)
		else
			a = math.max(t, a - step)
		end
		this:SetAlpha(a)
	end
end)
tf:SetMovable(true)
tf:SetClampedToScreen(true)
tf:RegisterForDrag("LeftButton")
tf:SetScript("OnDragStart", function()
	if AegisUI and AegisUI.locked then
		return
	end
	this:StartMoving()
end)
tf:SetScript("OnDragStop", function()
	if AegisUI and AegisUI.locked then
		return
	end
	this:StopMovingOrSizing()
	if AegisUI and AegisUI.snapFrame then
		AegisUI.snapFrame(this)
	end
	local left, bottom = this:GetLeft(), this:GetBottom()
	if left and bottom then
		AegisUnitsDB = AegisUnitsDB or {}
		local k = this:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local gap = left * k - UIParent:GetWidth() / 2
		if gap < 20 then
			gap = 20
		end
		AegisUnitsDB.gap = gap
		AegisUnitsDB.bottom = bottom * k
	end
	layoutCards()
end)

-- Nameplates -----------------------------------------------------------

local function isNamePlate(f)
	if f:GetObjectType() ~= "Button" then
		return false
	end
	local region = f:GetRegions()
	if not region or region:GetObjectType() ~= "Texture" then
		return false
	end
	return region:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
end

local function stylePlate(p)
	local border, glow, name, level, levelicon, raidicon = p:GetRegions()
	local bar = p:GetChildren()
	if not bar then
		return
	end
	p.my = { border = border, glow = glow, name = name, level = level, levelicon = levelicon, raidicon = raidicon, bar = bar }

	border:SetTexture(nil)
	glow:SetTexture(nil)
	bar:SetStatusBarTexture(SOLID)
	skin(bar)
	bar:SetBackdropColor(0.04, 0.05, 0.08, 0.96)
	local topLine = bar:CreateTexture(nil, "OVERLAY")
	topLine:SetTexture(SOLID)
	topLine:SetVertexColor(0.78, 0.58, 0.22, 0.9)
	topLine:SetHeight(1)
	topLine:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
	topLine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, -1)

	name:SetFont(FONT, 10, "OUTLINE")
	level:SetFont(FONT_NUM, 9, "OUTLINE")

	local txt = bar:CreateFontString(nil, "OVERLAY")
	txt:SetFont(FONT_NUM, 9, "OUTLINE")
	txt:SetPoint("CENTER", bar, "CENTER", 0, 0)
	p.my.txt = txt

	-- elite / boss / guardian marker: small gold crown (textures only) on the bar's top-left corner
	local crown = {}
	local function piece(x, y, w, h)
		local t = bar:CreateTexture(nil, "OVERLAY")
		t:SetTexture(SOLID)
		t:SetVertexColor(1, 0.82, 0.30, 1)
		t:SetWidth(w)
		t:SetHeight(h)
		t:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 2 + x, 1 + y)
		t:Hide()
		crown[table.getn(crown) + 1] = t
	end
	piece(0, 0, 11, 2)    -- band
	piece(0, 2, 3, 3)     -- left point
	piece(4, 2, 3, 5)     -- middle point
	piece(8, 2, 3, 3)     -- right point
	p.my.crown = crown
	-- inner gold glow, only used while a boss / guardian is targeted
	local inner = bar:CreateTexture(nil, "ARTWORK")
	inner:SetTexture(SOLID)
	inner:SetVertexColor(1, 0.82, 0.30, 0.16)
	inner:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
	inner:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
	inner:Hide()
	p.my.inner = inner
end

local function refreshPlate(p)
	local m = p.my
	if not m then
		return
	end
	local bar = m.bar
	bar:ClearAllPoints()
	bar:SetPoint("TOP", p, "TOP", 0, -15)
	local isTarget = UnitExists("target") and p:GetAlpha() >= 0.99
	local elite = m.levelicon and m.levelicon:IsShown()
	if isTarget and AZS_UnitKind then
		local k = AZS_UnitKind("target")
		if k == "final" or k == "boss" or k == "guardian" or k == "elite" then
			elite = true
		end
	end
	if m.levelicon then
		m.levelicon:SetAlpha(0)       -- stock dragon icon replaced by the crown
	end
	if isTarget then
		bar:SetWidth(124)
		bar:SetHeight(13)
	else
		bar:SetWidth(112)
		bar:SetHeight(11)
	end
	local special = false
	if isTarget and AZS_UnitKind then
		local k2 = AZS_UnitKind("target")
		special = (k2 == "final" or k2 == "boss" or k2 == "guardian")
	end
	local ci
	for ci = 1, table.getn(m.crown) do
		if elite then
			m.crown[ci]:Show()
		else
			m.crown[ci]:Hide()
		end
	end
	if special then
		m.inner:Show()
	else
		m.inner:Hide()
	end
	m.name:ClearAllPoints()
	m.name:SetPoint("BOTTOM", bar, "TOP", 0, 2)
	m.level:ClearAllPoints()
	m.level:SetPoint("LEFT", bar, "RIGHT", 3, 0)
	if m.raidicon then
		m.raidicon:ClearAllPoints()
		m.raidicon:SetPoint("RIGHT", bar, "LEFT", -3, 0)
	end
	local mn, mx = bar:GetMinMaxValues()
	local v = bar:GetValue()
	if mx and mx > 0 and v then
		m.txt:SetText(math.floor(v / mx * 100 + 0.5) .. "%")
	end
	-- the targeted plate is fully opaque; give it the gold edge
	if isTarget then
		bar:SetBackdropBorderColor(1, 0.86, 0.45, 1)
	elseif elite then
		bar:SetBackdropBorderColor(0.55, 0.42, 0.18, 1)
	else
		bar:SetBackdropBorderColor(0.14, 0.16, 0.22, 1)
	end
end

local function scanPlates()
	local n = WorldFrame:GetNumChildren()
	if n == U.childCount then
		return
	end
	U.childCount = n
	local kids = { WorldFrame:GetChildren() }
	local i
	for i = 1, n do
		local f = kids[i]
		if f and U.known[f] == nil then
			if isNamePlate(f) then
				U.known[f] = true
				stylePlate(f)
				U.list[table.getn(U.list) + 1] = f
			else
				U.known[f] = false
			end
		end
	end
end

-- Stock player frame ---------------------------------------------------

local STOCK = { "PlayerFrame", "TargetFrame" }

local function setStock(hide)
	local i
	for i = 1, table.getn(STOCK) do
		local f = getglobal(STOCK[i])
		if f then
			if hide then
				if not U.stockPoint then
					U.stockPoint = {}
				end
				if not U.stockPoint[i] then
					local point, _, rel, x, y = f:GetPoint(1)
					U.stockPoint[i] = { point, rel, x, y }
				end
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -600, 600)
			elseif U.stockPoint and U.stockPoint[i] then
				local p = U.stockPoint[i]
				f:ClearAllPoints()
				f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
			end
		end
	end
end

-- Update loop ----------------------------------------------------------

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
	U.acc = U.acc + (arg1 or 0)
	if U.acc < 0.1 then
		return
	end
	U.acc = 0
	local ok, err = pcall(function()
		U.stockAcc = (U.stockAcc or 0) + 1
		if U.stockAcc >= 20 then
			U.stockAcc = 0
			-- the game may move the stock frame back; push it out again
			if U.stockHidden then
				local k
				for k = 1, table.getn(STOCK) do
					local sf = getglobal(STOCK[k])
					if sf and sf:GetLeft() and sf:GetLeft() > -300 then
						setStock(true)
						break
					end
				end
			end
		end
		if U.player then
			playerCard.update()
			if U.target and UnitExists("target") then
				tf:Show()
				targetCard.update()
				if U.fade then
					-- dim unless the target is a boss / guardian (alpha fade only, no scaling)
					local k = AZS_UnitKind and AZS_UnitKind("target")
					if k == "boss" or k == "final" or k == "guardian" then
						tf.aTarget = 1
					else
						tf.aTarget = 0.15
					end
				else
					tf.aTarget = 1
				end
			elseif U.target and AegisUI and not AegisUI.locked then
				tf.aTarget = 1
				tf:Show()          -- unlocked: show the card even without a target so it can be placed
			else
				tf:Hide()
			end
		end
		if U.plates then
			scanPlates()
			local i
			for i = 1, table.getn(U.list) do
				if U.list[i]:IsVisible() then
					refreshPlate(U.list[i])
				end
			end
		end
	end)
	if not ok and not U.told then
		U.told = true
		say(L("Error: ") .. tostring(err))
	end
end)

-- Saved state + commands ----------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function()
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		-- the client re-applies cached frame positions late; put the cards where we want them
		layoutCards()
		return
	end
	if arg1 ~= "AegisUnits" then
		return
	end
	AegisUnitsDB = AegisUnitsDB or {}
	local d = AegisUnitsDB
	layoutCards()
	if d.player == false then
		U.player = false
		pf:Hide()
	end
	if d.target == false then
		U.target = false
	end
	if d.fade then
		U.fade = true
	end
	if d.plates == false then
		U.plates = false
	end
	if d.stock == nil then
		d.stock = true       -- default: hide the game's own player frame
	end
	if d.stock then
		U.stockHidden = true
		setStock(true)
	end
end)

SLASH_AEGISUNITS1 = "/aegisunits"
SlashCmdList["AEGISUNITS"] = function(msg)
	msg = string.lower(msg or "")
	AegisUnitsDB = AegisUnitsDB or {}
	local _, _, what, state = string.find(msg, "^(%S*)%s*(%S*)")
	local on = state ~= "off"
	if what == "player" then
		U.player = on
		AegisUnitsDB.player = on
		if on then
			pf:Show()
		else
			pf:Hide()
		end
		say(L("Player frame ") .. (on and L("on") or L("off")))
	elseif what == "gap" then
		local n = tonumber(state)
		if n then
			AegisUnitsDB.gap = math.floor(n + 0.5)
			layoutCards()
			say(L("Distance from center ") .. n)
		else
			say(L("Usage: /aegisunits gap <pixels>  (current ") .. ((AegisUnitsDB and AegisUnitsDB.gap) or 110) .. L(", default 110)"))
		end
	elseif what == "target" then
		U.target = on
		AegisUnitsDB.target = on
		say(L("Target frame ") .. (on and L("on") or L("off")))
	elseif what == "plates" then
		U.plates = on
		AegisUnitsDB.plates = on
		say("Nameplates " .. (on and L("on (fully active after /reload or restart)") or L("off (back to default after restart)")))
	elseif what == "stock" then
		-- "stock off" hides the game's own player frame, "stock on" brings it back
		U.stockHidden = not on
		AegisUnitsDB.stock = not on
		setStock(not on)
		say(L("Default player and target frames ").. (on and L("visible") or L("hidden")))
	else
		say(L("/aegisunits player on|off   /aegisunits target on|off   /aegisunits gap <n>   /aegisunits plates on|off   /aegisunits stock on|off (default player frame)"))
	end
end

-- Hub integration ------------------------------------------------------

local function hubHook()
	if not AegisUI or AegisUI.hooked_units then
		return
	end
	AegisUI.hooked_units = true
	local function resetCards()
		AegisUnitsDB = AegisUnitsDB or {}
		AegisUnitsDB.gap = nil
		AegisUnitsDB.bottom = nil
		layoutCards()
	end
	AegisUI.register("player", "Player card", pf, resetCards)
	AegisUI.register("target", "Target card", tf, nil)
	AegisUI.api.units = {
		version = "5.9.0",
		getPlayer = function()
			return U.player
		end,
		setPlayer = function(on)
			AegisUnitsDB = AegisUnitsDB or {}
			U.player = on and true or false
			AegisUnitsDB.player = U.player
			if U.player then
				pf:Show()
			else
				pf:Hide()
				tf:Hide()
			end
		end,
		getTargetFade = function()
			return U.fade and true or false
		end,
		setTargetFade = function(on)
			AegisUnitsDB = AegisUnitsDB or {}
			U.fade = on and true or false
			AegisUnitsDB.fade = U.fade
			if not U.fade then
				tf.aTarget = 1
			end
		end,
		getTarget = function()
			return U.target
		end,
		setTarget = function(on)
			AegisUnitsDB = AegisUnitsDB or {}
			U.target = on and true or false
			AegisUnitsDB.target = U.target
		end,
		getPlates = function()
			return U.plates
		end,
		setPlates = function(on)
			AegisUnitsDB = AegisUnitsDB or {}
			U.plates = on and true or false
			AegisUnitsDB.plates = U.plates
		end,
		getStockHidden = function()
			return U.stockHidden
		end,
		setStockHidden = function(hide)
			AegisUnitsDB = AegisUnitsDB or {}
			U.stockHidden = hide and true or false
			AegisUnitsDB.stock = U.stockHidden
			setStock(U.stockHidden)
		end,
		getGap = function()
			return math.floor(((AegisUnitsDB and AegisUnitsDB.gap) or 110) + 0.5)
		end,
		setGap = function(n)
			AegisUnitsDB = AegisUnitsDB or {}
			AegisUnitsDB.gap = math.floor(n + 0.5)
			layoutCards()
		end,
	}
end

hubHook()
local hookEv = CreateFrame("Frame")
hookEv:RegisterEvent("PLAYER_LOGIN")
hookEv:SetScript("OnEvent", hubHook)
