-- AegisMeter v0.2: per-spell meter for Azeroth Survivors, dark "overall damage" style.
-- WoW 1.12 client, Lua 5.0 (no # operator, no string.match, handlers use this/arg1/event).
-- Numbers come from the game's own meters, so they match the built-in ones:
--   AZS_GetMeter / AZS_GetHealing / AZS_GetBossMeter / AZS_TAKEN
-- Each meter line has: name, dmg, dps, proc, icon, class, top, topdps.

local ROW_H = 20
local ROW_GAP = 2
local PITCH = ROW_H + ROW_GAP
local ROWS = 10
local WIDTH = 360
local HEAD_H = 26
local FOOT_H = 20
local PAD = 6
local SOLID = "Interface\\Buttons\\WHITE8X8"
local FONT_TEXT = "Fonts\\FRIZQT__.TTF"
local FONT_NUM = "Fonts\\ARIALN.TTF"

-- Colors ---------------------------------------------------------------

local C_PANEL = { 0.04, 0.05, 0.08, 0.96 }
local C_EDGE = { 0.14, 0.16, 0.22, 1 }
local C_GOLD = { 0.78, 0.58, 0.22, 1 }
local C_ROW = { 0.06, 0.07, 0.10, 1 }
local C_ROW_EDGE = { 0.17, 0.19, 0.25, 1 }
local C_TOP_EDGE = { 0.40, 0.52, 0.92, 1 }

-- Bar colors by rank (like the class colors in the reference).
local BAR = {
	{ 0.53, 0.53, 0.94 },
	{ 0.93, 0.55, 0.70 },
	{ 0.10, 0.93, 0.50 },
	{ 0.74, 0.16, 0.26 },
	{ 0.98, 0.55, 0.10 },
	{ 0.30, 0.75, 0.95 },
	{ 0.85, 0.80, 0.30 },
	{ 0.65, 0.40, 0.90 },
	{ 0.40, 0.85, 0.75 },
	{ 0.70, 0.70, 0.74 },
}

-- Views ----------------------------------------------------------------

local MODES = { "damage", "healing", "boss", "taken" }
local MODE_TITLE = {
	damage = "OVERALL DAMAGE",
	healing = "OVERALL HEALING",
	boss = "BOSS DAMAGE",
	taken = "DAMAGE TAKEN",
}
local MODE_BTN = {
	damage = "DPS (Damage)",
	healing = "HPS (Healing)",
	boss = "DPS (Boss)",
	taken = "DPS (Taken)",
}
local TAKEN_LABEL = {
	["boss melee"] = "Boss melee",
	["boss spell"] = "Boss spells",
	["elite"] = "Elites",
	["mob melee"] = "Mob melee",
	["mob spell"] = "Mob spells",
	["area"] = "Ground",
}
local TAKEN_ICON = {
	["boss melee"] = "Interface\\Icons\\Ability_Warrior_SavageBlow",
	["boss spell"] = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
	["elite"] = "Interface\\Icons\\Ability_Creature_Cursed_01",
	["mob melee"] = "Interface\\Icons\\INV_Sword_04",
	["mob spell"] = "Interface\\Icons\\Spell_Nature_Lightning",
	["area"] = "Interface\\Icons\\Spell_Fire_Fire",
}

local mode = "damage"
-- Reset snapshots per view: the built-in meters can't be cleared,
-- so we remember their numbers and show only what was added since.
local bases = {}
-- Rolling DPS history per view: snapshots of damage so rates cover the last N seconds.
local histories = {}
-- Hits and crits per spell, counted from the combat log (English client text).
local hitStats = {}
local lastRunSeen = 0

local function say(text)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisMeter:|r " .. text)
	end
end

-- Number formats -------------------------------------------------------

local function fmtBig(n)
	n = n or 0
	if n >= 1000000000 then
		return string.format("%.2f B", n / 1000000000)
	elseif n >= 1000000 then
		return string.format("%.2f M", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.2f K", n / 1000)
	end
	return string.format("%d", math.floor(n + 0.5))
end

local function fmtRate(n)
	n = n or 0
	if n >= 1000000 then
		return string.format("%.1f M/s", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1f k/s", n / 1000)
	end
	return string.format("%.1f /s", n)
end

local function fmtAvg(n)
	n = n or 0
	if n >= 1000000 then
		return string.format("%.1f M", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1f K", n / 1000)
	end
	return string.format("%.1f", n)
end

local function fmtTime(sec)
	sec = math.floor(sec or 0)
	if sec < 0 then
		sec = 0
	end
	local m = math.floor(sec / 60)
	local s = sec - m * 60
	return string.format("[%02d:%02d]", m, s)
end

-- Icon lookup ----------------------------------------------------------
-- AZS_GetMeter often returns no icon, so we look it up by spell name:
-- 1) icon from the meter line  2) learned from spellbook/talents/gear
-- 3) AZSSpellMeterIcon (Icons.lua of AZSSpellMeter, if that addon is installed)
-- 4) "Item: Spell" names are split and each half tried  5) small manual list

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local icons = {}
local needScan = true
local lastScan = 0

-- Add your own entries here for names that stay a question mark.
local MANUAL = {
	["Melee"] = "INV_Sword_04",
	["Damage Shield"] = "Spell_Nature_Thorns",
	["Piercing Shots"] = "Ability_PierceDamage",
	["Pets"] = "Ability_Hunter_BeastCall",
	["Pet"] = "Ability_Hunter_BeastCall",
	-- hunter traps (names as the game's spell database has them)
	["Frost Trap"] = "Spell_Frost_FreezingBreath",
	["Frost Trap Aura"] = "Spell_Frost_FrostNova",
	["Explosive Trap"] = "Spell_Fire_SelfDestruct",
	["Explosive Trap Effect"] = "Spell_Fire_SelfDestruct",
	["Freezing Trap"] = "Spell_Frost_ChainsOfIce",
	["Freezing Trap Effect"] = "Spell_Frost_ChainsOfIce",
	["Immolation Trap"] = "Spell_Fire_FlameShock",
	["Immolation Trap Effect"] = "Spell_Fire_FlameShock",
	["Rapid Fire"] = "Ability_Hunter_RunningShot",
}

local function fullPath(tex)
	if not tex or tex == "" then
		return nil
	end
	if string.find(string.lower(tex), "questionmark", 1, true) then
		return nil
	end
	if string.find(tex, "\\", 1, true) then
		return tex
	end
	return "Interface\\Icons\\" .. tex
end

local function remember(name, tex)
	local path = fullPath(tex)
	if name and name ~= "" and path then
		icons[name] = path
	end
end

local function scanIcons()
	lastScan = GetTime()
	local book, i, name

	if GetSpellName and GetSpellTexture then
		book = BOOKTYPE_SPELL or "spell"
		i = 1
		while true do
			name = GetSpellName(i, book)
			if not name then
				break
			end
			remember(name, GetSpellTexture(i, book))
			i = i + 1
		end
		book = BOOKTYPE_PET or "pet"
		i = 1
		while true do
			name = GetSpellName(i, book)
			if not name then
				break
			end
			if not icons[name] then
				remember(name, GetSpellTexture(i, book))
			end
			i = i + 1
		end
	end

	if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
		local tab
		for tab = 1, (GetNumTalentTabs() or 0) do
			local t
			for t = 1, (GetNumTalents(tab) or 0) do
				local tname, ticon = GetTalentInfo(tab, t)
				remember(tname, ticon)
			end
		end
	end

	if GetInventoryItemLink and GetInventoryItemTexture then
		local slot
		for slot = 1, 19 do
			local link = GetInventoryItemLink("player", slot)
			local tex = GetInventoryItemTexture("player", slot)
			if link and tex then
				local _, _, iname = string.find(link, "%[(.+)%]")
				remember(iname, tex)
			end
		end
	end
end

-- Built-in icon table (AegisIcons.lua): name without case, spaces or punctuation -> icon.
local function squash(name)
	return string.lower(string.gsub(name or "", "[^%w]", ""))
end

local function lookupExtra(name)
	if not name or type(AEGISMETER_ICONS) ~= "table" then
		return nil
	end
	local tex = AEGISMETER_ICONS[squash(name)]
	if not tex then
		-- "Immolation Trap Effect", "Frost Trap Aura": the spell's own icon
		local base = string.gsub(name, " Effect$", "")
		base = string.gsub(base, " Aura$", "")
		if base ~= name then
			return lookupExtra(base)
		end
	end
	return tex
end

local function iconFor(name, given)
	local path = fullPath(given)
	if path then
		return path
	end
	if icons[name] then
		return icons[name]
	end
	if AZSSpellMeterIcon and AZSSpellMeterIcon[name] then
		return fullPath(AZSSpellMeterIcon[name]) or QUESTION
	end
	if MANUAL[name] then
		return fullPath(MANUAL[name])
	end
	local other = lookupExtra(name)
	if other then
		local p = fullPath(other)
		if p then
			return p
		end
	end
	-- "Pendant of the Plague: Moonfire" = item's share of a spell
	local _, _, left, right = string.find(name or "", "^(.-): (.+)$")
	if left and right then
		local tex = iconFor(right)
		if tex ~= QUESTION then
			return tex
		end
		tex = iconFor(left)
		if tex ~= QUESTION then
			return tex
		end
	end
	if GetTime() - lastScan > 5 then
		needScan = true
	end
	return QUESTION
end

local function runTime()
	if AZS_GetRunTime then
		return AZS_GetRunTime() or 0
	end
	return 0
end

-- Data -----------------------------------------------------------------

-- Returns lines, total for the view, or nil when the game build lacks it.
local function pull(view)
	if view == "taken" then
		if not AZS_TAKEN then
			return nil
		end
		local lines = {}
		local total = 0
		local n
		for n = 1, table.getn(AZS_TAKEN) do
			local e = AZS_TAKEN[n]
			local src = e.source or ""
			local d = tonumber(e.dmg) or 0
			lines[n] = { name = TAKEN_LABEL[src] or src, dmg = d, icon = TAKEN_ICON[src] }
			total = total + d
		end
		return lines, total
	end
	local fn = AZS_GetMeter
	if view == "healing" then
		fn = AZS_GetHealing
	elseif view == "boss" then
		fn = AZS_GetBossMeter
	end
	if not fn then
		return nil
	end
	return fn()
end

-- Window ---------------------------------------------------------------

local refresh

-- Combat log: only counts hits and crits per spell for the tooltip.
-- The damage numbers themselves always come from the game's meter.
local function noteHit(msg)
	if not msg then
		return
	end
	msg = string.gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
	msg = string.gsub(msg, "|r", "")
	local _, _, spell = string.find(msg, "^Your (.+) crits .+ for %d+")
	local crit = false
	if spell then
		crit = true
	else
		_, _, spell = string.find(msg, "^Your (.+) hits .+ for %d+")
		if not spell then
			_, _, spell = string.find(msg, "^Your (.+) causes .+ %d+")
		end
	end
	if not spell then
		if string.find(msg, "^You crit .+ for %d+") then
			spell = "Melee"
			crit = true
		elseif string.find(msg, "^You hit .+ for %d+") then
			spell = "Melee"
		end
	end
	if not spell then
		local _, _, periodic = string.find(msg, "^.+ suffers %d+ .+ damage from your (.+)$")
		if periodic then
			spell = periodic
			if string.find(msg, "%(Critical%)") then
				crit = true
			end
		end
	end
	if not spell then
		return
	end
	spell = string.gsub(spell, " %(Critical%)$", "")
	spell = string.gsub(spell, "%.$", "")
	local h = hitStats[spell]
	if not h then
		h = { hits = 0, crits = 0 }
		hitStats[spell] = h
	end
	h.hits = h.hits + 1
	if crit then
		h.crits = h.crits + 1
	end
end

-- "Frost Trap" and "frost_trap" and "Frost-Trap" all match the same cooldown entry.
local function compactKey(name)
	local s = string.lower(name or "")
	s = string.gsub(s, "[%s_%-']", "")
	return s
end

-- Seconds of run time the DPS looks back. Default 10. 0 means average over the whole run.
local function dpsWindow()
	local w = nil
	if AegisMeterDB then
		w = AegisMeterDB.dpsWindow
	end
	if w == nil then
		return 10
	end
	w = tonumber(w) or 10
	if w <= 0 then
		return 0
	end
	if w < 5 then
		w = 5
	elseif w > 120 then
		w = 120
	end
	return math.floor(w)
end

-- Damage now minus the snapshot from one window ago, divided by the time between.
-- Sets item.dps for every line and returns the total rate, or nil when there is
-- too little history yet (the caller then keeps the game's own average).
local function windowRates(view, now, sum, list)
	local window = dpsWindow()
	if window <= 0 then
		return nil
	end
	local hist = histories[view]
	if not hist then
		hist = {}
		histories[view] = hist
	end
	local cnt = table.getn(hist)
	-- the run clock went backwards: a new run started
	if cnt > 0 and hist[cnt].t > now + 0.05 then
		hist = {}
		histories[view] = hist
		cnt = 0
	end
	if cnt == 0 or now - hist[cnt].t >= 0.25 then
		local snap = { t = now, total = sum, spells = {} }
		local n
		for n = 1, table.getn(list) do
			snap.spells[list[n].name] = list[n].dmg
		end
		table.insert(hist, snap)
	end
	while table.getn(hist) > 1 and now - hist[1].t > window do
		table.remove(hist, 1)
	end
	local base = hist[1]
	local span = now - base.t
	if span < 1 then
		return nil
	end
	local n
	for n = 1, table.getn(list) do
		local item = list[n]
		local dealt = item.dmg - (base.spells[item.name] or 0)
		if dealt < 0 then
			dealt = 0
		end
		item.dps = dealt / span
	end
	local head = sum - (base.total or 0)
	if head < 0 then
		head = 0
	end
	return head / span
end

-- Reset the current view: remember the game's numbers and show only what comes after.
local function doReset()
	local lines, total = pull(mode)
	if not lines then
		return
	end
	local map = {}
	local n
	for n = 1, table.getn(lines) do
		local l = lines[n]
		if l.name then
			map[l.name] = (map[l.name] or 0) + (tonumber(l.dmg) or 0)
		end
	end
	bases[mode] = { map = map, total = tonumber(total) or 0, time = runTime() }
	histories[mode] = nil
	if mode == "damage" then
		hitStats = {}
	end
	say("Reset (" .. (MODE_TITLE[mode] or mode) .. "). Der eingebaute Meter behaelt seine Zahlen.")
end

local frame = CreateFrame("Frame", "AegisMeterFrame", UIParent)
frame:SetWidth(WIDTH)
frame:SetHeight(HEAD_H + 4 + PITCH + FOOT_H + 2)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:SetBackdrop({
	bgFile = SOLID,
	edgeFile = SOLID,
	tile = false,
	edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
frame:SetBackdropColor(C_PANEL[1], C_PANEL[2], C_PANEL[3], C_PANEL[4])
frame:SetBackdropBorderColor(C_EDGE[1], C_EDGE[2], C_EDGE[3], C_EDGE[4])
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
		AegisMeterDB = AegisMeterDB or {}
		AegisMeterDB.point = point
		AegisMeterDB.rel = rel
		AegisMeterDB.x = x
		AegisMeterDB.y = y
	end
end)

-- thin gold line at the very top
local goldLine = frame:CreateTexture(nil, "OVERLAY")
goldLine:SetTexture(SOLID)
goldLine:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 0.9)
goldLine:SetHeight(1)
goldLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
goldLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

-- header
-- timer badge: bright bold text in its own box so it stands out from the header
local timeBadge = CreateFrame("Frame", nil, frame)
timeBadge:SetWidth(54)
timeBadge:SetHeight(18)
timeBadge:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -4)
timeBadge:SetBackdrop({
	bgFile = SOLID,
	edgeFile = SOLID,
	tile = false,
	edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
timeBadge:SetBackdropColor(0.10, 0.13, 0.20, 1)
timeBadge:SetBackdropBorderColor(0.30, 0.38, 0.52, 1)
local timeText = timeBadge:CreateFontString(nil, "OVERLAY")
timeText:SetFont(FONT_TEXT, 11, "OUTLINE")
timeText:SetPoint("CENTER", timeBadge, "CENTER", 0, 0)
timeText:SetTextColor(0.80, 0.94, 1)
timeText:SetText("[00:00]")

local titleText = frame:CreateFontString(nil, "OVERLAY")
titleText:SetFont(FONT_TEXT, 11, "OUTLINE")
titleText:SetPoint("LEFT", timeBadge, "RIGHT", 7, 0)
titleText:SetTextColor(1, 1, 1)
titleText:SetText(MODE_TITLE.damage)

local modeBtn = CreateFrame("Button", nil, frame)
modeBtn:SetWidth(108)
modeBtn:SetHeight(18)
modeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -4)
modeBtn:SetBackdrop({
	bgFile = SOLID,
	edgeFile = SOLID,
	tile = false,
	edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
modeBtn:SetBackdropColor(0.07, 0.08, 0.12, 1)
modeBtn:SetBackdropBorderColor(0.22, 0.25, 0.33, 1)
local modeLabel = modeBtn:CreateFontString(nil, "OVERLAY")
modeLabel:SetFont(FONT_NUM, 11, "")
modeLabel:SetPoint("LEFT", modeBtn, "LEFT", 7, 0)
modeLabel:SetTextColor(0.90, 0.92, 0.96)
local modeArrow = modeBtn:CreateFontString(nil, "OVERLAY")
modeArrow:SetFont(FONT_NUM, 10, "")
modeArrow:SetPoint("RIGHT", modeBtn, "RIGHT", -6, 0)
modeArrow:SetTextColor(0.60, 0.64, 0.74)
modeArrow:SetText("v")
modeBtn:SetScript("OnEnter", function()
	this:SetBackdropBorderColor(0.45, 0.55, 0.90, 1)
end)
modeBtn:SetScript("OnLeave", function()
	this:SetBackdropBorderColor(0.22, 0.25, 0.33, 1)
end)
-- Dropdown menu -------------------------------------------------------

local MODE_ACCENT = {
	damage = { 0.98, 0.55, 0.10 },
	healing = { 0.10, 0.93, 0.50 },
	boss = { 0.74, 0.16, 0.26 },
	taken = { 0.93, 0.55, 0.70 },
}
local MENU_ITEM_H = 20

local menu = CreateFrame("Frame", nil, frame)
menu:SetFrameStrata("DIALOG")
menu:SetWidth(128)
menu:SetHeight(table.getn(MODES) * MENU_ITEM_H + 4)
menu:SetPoint("TOPRIGHT", modeBtn, "BOTTOMRIGHT", 0, -2)
menu:SetBackdrop({
	bgFile = SOLID,
	edgeFile = SOLID,
	tile = false,
	edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
menu:SetBackdropColor(0.05, 0.06, 0.09, 1)
menu:SetBackdropBorderColor(0.30, 0.34, 0.45, 1)
menu:EnableMouse(true)
menu:Hide()

local menuItems = {}

local function pickMode(view)
	mode = view
	AegisMeterDB = AegisMeterDB or {}
	AegisMeterDB.mode = mode
	menu:Hide()
	refresh()
end

local k
for k = 1, table.getn(MODES) do
	local view = MODES[k]
	local item = CreateFrame("Button", nil, menu)
	item:SetWidth(124)
	item:SetHeight(MENU_ITEM_H)
	item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -(2 + (k - 1) * MENU_ITEM_H))
	item.view = view

	local hl = item:CreateTexture(nil, "BACKGROUND")
	hl:SetTexture(SOLID)
	hl:SetVertexColor(0.16, 0.19, 0.28, 1)
	hl:SetAllPoints(item)
	hl:Hide()
	item.hl = hl

	local ac = MODE_ACCENT[view] or BAR[10]
	local accent = item:CreateTexture(nil, "ARTWORK")
	accent:SetTexture(SOLID)
	accent:SetVertexColor(ac[1], ac[2], ac[3], 1)
	accent:SetWidth(3)
	accent:SetHeight(12)
	accent:SetPoint("LEFT", item, "LEFT", 4, 0)

	local label = item:CreateFontString(nil, "OVERLAY")
	label:SetFont(FONT_NUM, 11, "")
	label:SetPoint("LEFT", item, "LEFT", 14, 0)
	label:SetText(MODE_BTN[view])
	item.label = label

	local check = item:CreateFontString(nil, "OVERLAY")
	check:SetFont(FONT_TEXT, 11, "")
	check:SetPoint("RIGHT", item, "RIGHT", -6, 0)
	check:SetTextColor(1, 0.80, 0.20)
	item.check = check

	item:SetScript("OnEnter", function()
		this.hl:Show()
	end)
	item:SetScript("OnLeave", function()
		this.hl:Hide()
	end)
	item:SetScript("OnClick", function()
		pickMode(this.view)
	end)
	menuItems[k] = item
end

local function mouseOver(f)
	if MouseIsOver then
		return MouseIsOver(f)
	end
	return true
end

local away = 0
menu:SetScript("OnShow", function()
	away = 0
	modeArrow:SetText("^")
	local n
	for n = 1, table.getn(menuItems) do
		local it = menuItems[n]
		if it.view == mode then
			it.label:SetTextColor(1, 0.86, 0.45)
			it.check:SetText("*")
		else
			it.label:SetTextColor(0.80, 0.83, 0.90)
			it.check:SetText("")
		end
	end
end)
menu:SetScript("OnHide", function()
	modeArrow:SetText("v")
end)
-- close when the mouse has been away from menu and button for a moment
menu:SetScript("OnUpdate", function()
	if mouseOver(menu) or mouseOver(modeBtn) then
		away = 0
		return
	end
	away = away + (arg1 or 0)
	if away > 0.5 then
		menu:Hide()
	end
end)

modeBtn:SetScript("OnClick", function()
	if menu:IsShown() then
		menu:Hide()
	else
		menu:Show()
	end
end)

local headLine = frame:CreateTexture(nil, "ARTWORK")
headLine:SetTexture(SOLID)
headLine:SetVertexColor(C_EDGE[1], C_EDGE[2], C_EDGE[3], 1)
headLine:SetHeight(1)
headLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -HEAD_H)
headLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -HEAD_H)

-- footer
local footLine = frame:CreateTexture(nil, "ARTWORK")
footLine:SetTexture(SOLID)
footLine:SetVertexColor(C_EDGE[1], C_EDGE[2], C_EDGE[3], 1)
footLine:SetHeight(1)
footLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, FOOT_H)
footLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, FOOT_H)

local totalText = frame:CreateFontString(nil, "OVERLAY")
totalText:SetFont(FONT_NUM, 10, "")
totalText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 6)
totalText:SetJustifyH("LEFT")

local avgText = frame:CreateFontString(nil, "OVERLAY")
avgText:SetFont(FONT_NUM, 10, "")
avgText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 6)
avgText:SetJustifyH("RIGHT")

-- DPS window presets: click the rate in the footer to cycle Standard (whole run) -> 10 -> 60 -> 120 s
local PRESETS = { 0, 10, 60, 120 }
local function cycleDps(to)
	local cur = dpsWindow()
	local nxt = to
	if nxt == nil then
		local i, idx = 1, 0
		for i = 1, table.getn(PRESETS) do
			if PRESETS[i] == cur then
				idx = i
			end
		end
		nxt = PRESETS[math.mod(idx, table.getn(PRESETS)) + 1]
	end
	AegisMeterDB = AegisMeterDB or {}
	AegisMeterDB.dpsWindow = nxt
	histories = {}
	if nxt == 0 then
		say("DPS: Standard (Schnitt ueber den ganzen Lauf).")
	else
		say("DPS: letzte " .. nxt .. " Sekunden.")
	end
	refresh()
end

local rateBtn = CreateFrame("Button", nil, frame)
rateBtn:SetWidth(120)
rateBtn:SetHeight(FOOT_H - 2)
rateBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 1)
rateBtn:SetScript("OnClick", function()
	cycleDps()
end)
rateBtn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("DPS-Zeitfenster", 1, 0.86, 0.45)
	GameTooltip:AddLine("Klick: Standard / 10 s / 60 s / 120 s", 0.8, 0.8, 0.8)
	GameTooltip:Show()
end)
rateBtn:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- reset button, centered in the footer
local resetBtn = CreateFrame("Button", nil, frame)
resetBtn:SetWidth(54)
resetBtn:SetHeight(14)
resetBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 3)
resetBtn:SetBackdrop({
	bgFile = SOLID,
	edgeFile = SOLID,
	tile = false,
	edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
resetBtn:SetBackdropColor(0.07, 0.08, 0.12, 1)
resetBtn:SetBackdropBorderColor(0.22, 0.25, 0.33, 1)
local resetLabel = resetBtn:CreateFontString(nil, "OVERLAY")
resetLabel:SetFont(FONT_NUM, 10, "")
resetLabel:SetPoint("CENTER", resetBtn, "CENTER", 0, 0)
resetLabel:SetTextColor(0.70, 0.74, 0.84)
resetLabel:SetText("RESET")
resetBtn:SetScript("OnEnter", function()
	this:SetBackdropBorderColor(0.45, 0.55, 0.90, 1)
	resetLabel:SetTextColor(1, 1, 1)
	if GameTooltip then
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText("Reset", 1, 1, 1)
		GameTooltip:AddLine("Setzt diese Ansicht zurueck.", 0.8, 0.8, 0.8, 1)
		GameTooltip:AddLine("Der eingebaute Meter behaelt seine Zahlen.", 0.6, 0.6, 0.6, 1)
		GameTooltip:Show()
	end
end)
resetBtn:SetScript("OnLeave", function()
	this:SetBackdropBorderColor(0.22, 0.25, 0.33, 1)
	resetLabel:SetTextColor(0.70, 0.74, 0.84)
	if GameTooltip then
		GameTooltip:Hide()
	end
end)
resetBtn:SetScript("OnClick", function()
	doReset()
	refresh()
end)

local emptyText = frame:CreateFontString(nil, "OVERLAY")
emptyText:SetFont(FONT_TEXT, 10, "")
emptyText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -(HEAD_H + 12))
emptyText:SetTextColor(0.55, 0.58, 0.66)
emptyText:Hide()

-- rows
local rows = {}
local i
for i = 1, ROWS do
	local row = CreateFrame("Frame", nil, frame)
	row:SetWidth(WIDTH - PAD * 2)
	row:SetHeight(ROW_H)
	row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(HEAD_H + 4 + (i - 1) * PITCH))
	row:SetBackdrop({
		bgFile = SOLID,
		edgeFile = SOLID,
		tile = false,
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	row:SetBackdropColor(C_ROW[1], C_ROW[2], C_ROW[3], C_ROW[4])
	row:SetBackdropBorderColor(C_ROW_EDGE[1], C_ROW_EDGE[2], C_ROW_EDGE[3], C_ROW_EDGE[4])

	local bar = row:CreateTexture(nil, "BORDER")
	bar:SetTexture(SOLID)
	bar:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
	bar:SetHeight(ROW_H - 2)
	bar:SetWidth(1)
	row.bar = bar

	local rank = row:CreateFontString(nil, "OVERLAY")
	rank:SetFont(FONT_NUM, 11, "")
	rank:SetPoint("LEFT", row, "LEFT", 6, 0)
	rank:SetWidth(14)
	rank:SetJustifyH("LEFT")
	rank:SetTextColor(0.20, 0.22, 0.30)
	row.rank = rank

	local badge = row:CreateTexture(nil, "ARTWORK")
	badge:SetTexture(SOLID)
	badge:SetVertexColor(0, 0, 0, 0.45)
	badge:SetWidth(16)
	badge:SetHeight(16)
	badge:SetPoint("LEFT", row, "LEFT", 22, 0)
	row.badge = badge

	local icon = row:CreateTexture(nil, "OVERLAY")
	icon:SetWidth(14)
	icon:SetHeight(14)
	icon:SetPoint("CENTER", badge, "CENTER", 0, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.icon = icon

	local rate = row:CreateFontString(nil, "OVERLAY")
	rate:SetFont(FONT_NUM, 10, "")
	rate:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	rate:SetWidth(76)
	rate:SetJustifyH("RIGHT")
	rate:SetTextColor(0.78, 0.80, 0.86)
	row.rate = rate

	local value = row:CreateFontString(nil, "OVERLAY")
	value:SetFont(FONT_TEXT, 11, "OUTLINE")
	value:SetPoint("RIGHT", rate, "LEFT", -2, 0)
	value:SetWidth(70)
	value:SetJustifyH("RIGHT")
	value:SetTextColor(1, 1, 1)
	row.value = value

	local name = row:CreateFontString(nil, "OVERLAY")
	name:SetFont(FONT_TEXT, 11, "OUTLINE")
	name:SetPoint("LEFT", badge, "RIGHT", 6, 0)
	name:SetPoint("RIGHT", value, "LEFT", -6, 0)
	name:SetJustifyH("LEFT")
	name:SetTextColor(1, 1, 1)
	row.name = name

	-- thin cooldown bar under the icon: amber while on cooldown, green when ready
	local cd = row:CreateTexture(nil, "OVERLAY")
	cd:SetTexture(SOLID)
	cd:SetHeight(2)
	cd:SetWidth(2)
	cd:SetPoint("BOTTOMLEFT", badge, "BOTTOMLEFT", 1, 1)
	cd:Hide()
	row.cd = cd

	-- hover: damage, share, DPS, hits and crits. Dragging a row still moves the window.
	row:EnableMouse(true)
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnDragStart", function()
		if AegisUI and AegisUI.locked then
			return
		end
		frame:StartMoving()
	end)
	row:SetScript("OnDragStop", function()
		if AegisUI and AegisUI.locked then
			return
		end
		frame:StopMovingOrSizing()
		if AegisUI and AegisUI.snapFrame then
			AegisUI.snapFrame(frame)
		end
		local point, _, rel, x, y = frame:GetPoint(1)
		if point then
			AegisMeterDB = AegisMeterDB or {}
			AegisMeterDB.point = point
			AegisMeterDB.rel = rel
			AegisMeterDB.x = x
			AegisMeterDB.y = y
		end
	end)
	row:SetScript("OnEnter", function()
		local d = this.info
		if not d or not GameTooltip then
			return
		end
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(d.name, 1, 0.9, 0.55)
		GameTooltip:AddLine(fmtBig(d.dmg) .. "  (" .. string.format("%.1f%%", (this.share or 0) * 100) .. ")", 1, 1, 1)
		GameTooltip:AddLine("DPS " .. fmtRate(d.dps), 0.7, 0.92, 0.68)
		local h = hitStats[d.name]
		if h and h.hits > 0 then
			local crits = h.crits
			if crits > h.hits then
				crits = h.hits
			end
			GameTooltip:AddLine(string.format("%d hits, %d crits, %.0f%% crit", h.hits, crits, crits / h.hits * 100), 1, 0.82, 0.55)
		end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)

	row:Hide()
	rows[i] = row
end

-- Refresh --------------------------------------------------------------

-- fills the bars (own function: Lua 5.0 allows only 32 upvalues per function)
local function fillRows(list, sum, count)
	-- cooldowns, matched to rows by spell name
	local cdMap = {}
	if AZS_SPELLS then
		local cn
		for cn = 1, table.getn(AZS_SPELLS) do
			local sp = AZS_SPELLS[cn]
			if sp.key and sp.key ~= "" then
				cdMap[compactKey(sp.key)] = sp
			end
		end
	end

	local top = 1
	if list[1] then
		top = list[1].dmg
	end
	local innerW = WIDTH - PAD * 2 - 2
	local r
	for r = 1, ROWS do
		local row = rows[r]
		local data = list[r]
		if data and r <= count then
			local c = BAR[r] or BAR[10]
			row.bar:SetVertexColor(c[1], c[2], c[3], 1)
			row.bar:SetWidth(math.max(1, innerW * data.dmg / top))
			if r == 1 then
				row:SetBackdropBorderColor(C_TOP_EDGE[1], C_TOP_EDGE[2], C_TOP_EDGE[3], C_TOP_EDGE[4])
			else
				row:SetBackdropBorderColor(C_ROW_EDGE[1], C_ROW_EDGE[2], C_ROW_EDGE[3], C_ROW_EDGE[4])
			end
			row.rank:SetText(tostring(r))
			row.icon:SetTexture(iconFor(data.name, data.icon))
			row.name:SetText(data.name)
			row.value:SetText(fmtBig(data.dmg))
			row.rate:SetText("|cff6f7588·|r " .. fmtRate(data.dps))
			row.info = data
			if sum > 0 then
				row.share = data.dmg / sum
			else
				row.share = 0
			end
			local cdInfo = cdMap[compactKey(data.name)]
			local cmax = 0
			if cdInfo then
				cmax = tonumber(cdInfo.cdmax) or 0
			end
			if cmax > 0 then
				local left = tonumber(cdInfo.cd) or 0
				if left < 0 then
					left = 0
				end
				local frac = 1 - left / math.max(cmax, 0.1)
				if frac < 0 then
					frac = 0
				elseif frac > 1 then
					frac = 1
				end
				row.cd:SetWidth(math.max(2, 14 * frac))
				if left <= 0 then
					row.cd:SetVertexColor(0.35, 0.95, 0.45, 1)
				else
					row.cd:SetVertexColor(0.95, 0.72, 0.25, 1)
				end
				row.cd:Show()
			else
				row.cd:Hide()
			end
			row:Show()
		else
			row:Hide()
		end
	end
end

local shownRows = -1

refresh = function()
	titleText:SetText(MODE_TITLE[mode] or "OVERALL DAMAGE")
	modeLabel:SetText(MODE_BTN[mode] or "DPS")
	timeText:SetText(fmtTime(runTime()))
	-- a new run rewinds the game's clock: forget the old hit counts
	local nowRun = runTime()
	if nowRun + 1 < lastRunSeen then
		hitStats = {}
	end
	lastRunSeen = nowRun
	local tw = timeText:GetStringWidth() or 40
	timeBadge:SetWidth(tw + 14)

	local lines, total = pull(mode)
	local supported = true
	if lines == nil then
		supported = false
		lines = {}
		total = 0
	end

	-- A new run clears the game's meter; drop our snapshot when numbers go backwards.
	local b = bases[mode]
	if b and (tonumber(total) or 0) + 1 < b.total then
		bases[mode] = nil
		b = nil
	end

	local t = runTime()
	if b then
		t = t - b.time
	end
	if t < 1 then
		t = 1
	end

	local list = {}
	local sum = 0
	local n
	for n = 1, table.getn(lines) do
		local l = lines[n]
		if l.name and l.name ~= "" then
			local d = tonumber(l.dmg) or 0
			local r
			if b then
				d = d - (b.map[l.name] or 0)
				if d < 0 then
					d = 0
				end
				r = d / t
			else
				r = tonumber(l.dps) or 0
				if r <= 0 then
					r = d / t
				end
			end
			if d > 0 then
				list[table.getn(list) + 1] = { name = l.name, dmg = d, dps = r, icon = l.icon }
				sum = sum + d
			end
		end
	end
	table.sort(list, function(a, c)
		return a.dmg > c.dmg
	end)

	-- rolling DPS over the last N seconds (rows and footer); falls back to the average
	local headRate = windowRates(mode, runTime(), sum, list)
	local winSec = dpsWindow()
	local rateLabel = "AVG DPS:"
	if winSec > 0 then
		rateLabel = "DPS (" .. winSec .. "s):"
	end
	local shownRate = sum / t
	if headRate then
		shownRate = headRate
	end

	totalText:SetText("|cff7d8294TOTAL:|r |cffffffff" .. fmtBig(sum) .. "|r")
	avgText:SetText("|cff7d8294" .. rateLabel .. "|r |cffffc533" .. fmtAvg(shownRate) .. "|r")

	local count = table.getn(list)
	if count > ROWS then
		count = ROWS
	end

	if count == 0 then
		if supported then
			emptyText:SetText("No data yet.")
		else
			emptyText:SetText("Not available in this game build.")
		end
		emptyText:Show()
	else
		emptyText:Hide()
	end

	local slots = count
	if slots < 1 then
		slots = 1
	end
	if slots ~= shownRows then
		shownRows = slots
		frame:SetHeight(HEAD_H + 4 + slots * PITCH + 2 + FOOT_H)
	end

	fillRows(list, sum, count)
end

local acc = 0
local toldErr = false
frame:SetScript("OnUpdate", function()
	acc = acc + (arg1 or 0)
	if acc < 0.25 then
		return
	end
	acc = 0
	if needScan then
		needScan = false
		local okScan, errScan = pcall(scanIcons)
		if not okScan and not toldErr then
			toldErr = true
			say("Fehler beim Icon-Scan: " .. tostring(errScan))
		end
	end
	local ok, err = pcall(refresh)
	if not ok and not toldErr then
		toldErr = true
		say("Fehler: " .. tostring(err))
	end
end)

-- Saved position + slash commands -------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("SPELLS_CHANGED")
loader:RegisterEvent("CHARACTER_POINTS_CHANGED")
loader:RegisterEvent("UNIT_INVENTORY_CHANGED")
loader:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
loader:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
loader:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF")
loader:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
loader:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
loader:SetScript("OnEvent", function()
	if string.find(event, "^CHAT_MSG") then
		noteHit(arg1)
		return
	end
	if event ~= "ADDON_LOADED" then
		needScan = true
		return
	end
	if arg1 ~= "AegisMeter" then
		return
	end
	AegisMeterDB = AegisMeterDB or {}
	say("v4.9 geladen. /aegismeter fuer Befehle; Einstellungen ueber /aegis, falls AegisUI installiert ist.")
	if AegisMeterDB.point then
		frame:ClearAllPoints()
		frame:SetPoint(AegisMeterDB.point, UIParent, AegisMeterDB.rel or AegisMeterDB.point, AegisMeterDB.x or 0, AegisMeterDB.y or 0)
	end
	if AegisMeterDB.mode and MODE_TITLE[AegisMeterDB.mode] then
		mode = AegisMeterDB.mode
	end
	if AegisMeterDB.hidden then
		frame:Hide()
	end
end)

-- Text window with a selectable box (the 1.12 client has no clipboard API: Ctrl+C copies the selection)
local dumpFrame
local function showDump(text)
	AegisMeterDB = AegisMeterDB or {}
	AegisMeterDB.dump = text
	if not dumpFrame then
		local f = CreateFrame("Frame", "AegisMeterDumpFrame", UIParent)
		f:SetWidth(480)
		f:SetHeight(320)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:SetClampedToScreen(true)
		f:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
			insets = { left = 1, right = 1, top = 1, bottom = 1 } })
		f:SetBackdropColor(C_PANEL[1], C_PANEL[2], C_PANEL[3], C_PANEL[4])
		f:SetBackdropBorderColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 1)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", function() this:StartMoving() end)
		f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

		local t = f:CreateFontString(nil, "OVERLAY")
		t:SetFont(FONT_TEXT, 12, "OUTLINE")
		t:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
		t:SetText("AegisMeter - Text kopieren")
		t:SetTextColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 1)

		local hint = f:CreateFontString(nil, "OVERLAY")
		hint:SetFont(FONT_TEXT, 10)
		hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -34, -11)
		hint:SetText("Alles markieren, dann Strg+C")
		hint:SetTextColor(0.5, 0.54, 0.62, 1)

		local sf = CreateFrame("ScrollFrame", "AegisMeterDumpScroll", f, "UIPanelScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
		sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 40)

		local eb = CreateFrame("EditBox", "AegisMeterDumpEdit", sf)
		eb:SetMultiLine(true)
		eb:SetAutoFocus(false)
		eb:SetFontObject(ChatFontNormal)
		eb:SetWidth(430)
		eb:SetHeight(400)
		eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
		sf:SetScrollChild(eb)
		f.edit = eb

		local function mkBtn(label, x, w, fn)
			local b = CreateFrame("Button", nil, f)
			b:SetWidth(w)
			b:SetHeight(22)
			b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 10)
			b:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
				insets = { left = 1, right = 1, top = 1, bottom = 1 } })
			b:SetBackdropColor(C_ROW[1], C_ROW[2], C_ROW[3], 1)
			b:SetBackdropBorderColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 1)
			local l = b:CreateFontString(nil, "OVERLAY")
			l:SetFont(FONT_TEXT, 11, "OUTLINE")
			l:SetPoint("CENTER", b, "CENTER", 0, 0)
			l:SetText(label)
			l:SetTextColor(1, 0.85, 0.4, 1)
			b:SetScript("OnClick", fn)
			return b
		end
		mkBtn("Alles markieren", 10, 120, function()
			dumpFrame.edit:SetFocus()
			dumpFrame.edit:HighlightText()
		end)
		mkBtn("Schliessen", 140, 90, function()
			dumpFrame:Hide()
		end)
		dumpFrame = f
	end
	dumpFrame.edit:SetText(text)
	dumpFrame:Show()
	dumpFrame.edit:SetFocus()
	dumpFrame.edit:HighlightText()
end

-- Dumps any value as text (depth/size limited) so unknown game data can be inspected
local function serialize(v, depth, budget)
	local tv = type(v)
	if tv == "string" then
		return string.format("%q", v)
	elseif tv ~= "table" then
		return tostring(v)
	end
	if depth <= 0 then
		return "{...}"
	end
	local parts = {}
	local k, x
	local n = 0
	for k, x in pairs(v) do
		n = n + 1
		if n > budget then
			parts[table.getn(parts) + 1] = "..."
			break
		end
		parts[table.getn(parts) + 1] = tostring(k) .. "=" .. serialize(x, depth - 1, budget)
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function inspectGame()
	local out = ""
	local names = { "AZS_GetGuardians", "AZS_GetLairs", "AZS_GetFlaggedLair", "AZS_GetBosses", "AZS_GetUpcomingBosses", "AZS_GetPhase" }
	local i
	for i = 1, table.getn(names) do
		local fn = getglobal(names[i])
		if type(fn) == "function" then
			local ok, a, b, c = pcall(fn)
			out = out .. names[i] .. "() ok=" .. tostring(ok) .. "\n  1: " .. serialize(a, 3, 24) .. "\n  2: " .. serialize(b, 2, 6) .. "\n  3: " .. serialize(c, 2, 6) .. "\n"
		end
	end
	local tabs = { "AZS_HUD_CVARS", "AZS_LAIRS", "AZS_CHESTS", "AZS_UNITS", "AZS_ZONE", "AZS_SCHEDULE", "AZS_RUN" }
	for i = 1, table.getn(tabs) do
		out = out .. tabs[i] .. " = " .. serialize(getglobal(tabs[i]), 3, 40) .. "\n"
	end
	if GetPlayerMapPosition then
		local px, py = GetPlayerMapPosition("player")
		out = out .. "player map pos: " .. tostring(px) .. ", " .. tostring(py) .. "  zone: " .. tostring(GetZoneText and GetZoneText()) .. "  continent: " .. tostring(GetCurrentMapContinent and GetCurrentMapContinent()) .. "\n"
	end
	return out
end

-- Run log: damage totals once per second plus per-spell snapshots every 5 s, kept in memory
-- for the current run only (a new run clears it). /aegismeter log shows it.
local runLog = { s = {}, snaps = {}, lastT = 0, step = 10 }
local LOG_MAX = 7200
local logAcc = 0
local logFrame = CreateFrame("Frame")
logFrame:SetScript("OnUpdate", function()
	logAcc = logAcc + (arg1 or 0)
	if logAcc < 1 then
		return
	end
	logAcc = 0
	local lines, total = pull("damage")
	if not lines then
		return
	end
	local t = runTime()
	total = tonumber(total) or 0
	if t + 2 < runLog.lastT then
		runLog.s = {}
		runLog.snaps = {}
	end
	if t <= 0 or (total <= 0 and table.getn(runLog.s) == 0) then
		return
	end
	if t == runLog.lastT then
		return
	end
	runLog.lastT = t
	table.insert(runLog.s, { t = t, total = total })
	if table.getn(runLog.s) > LOG_MAX then
		local k
		for k = 1, 600 do
			table.remove(runLog.s, 1)
		end
	end
	local key = math.floor(t / 5)
	if not runLog.snaps[key] then
		local map = {}
		local n
		for n = 1, table.getn(lines) do
			if lines[n].name then
				map[lines[n].name] = tonumber(lines[n].dmg) or 0
			end
		end
		runLog.snaps[key] = { t = t, spells = map }
	end
end)

local function mmss(sec)
	sec = math.floor(sec or 0)
	local m = math.floor(sec / 60)
	return string.format("%02d:%02d", m, sec - m * 60)
end

local function logReport(step)
	local sm = runLog.s
	local n = table.getn(sm)
	if n < 3 then
		return "Noch kein Log. Der Log laeuft automatisch im Run mit (Schaden pro Sekunde)."
	end
	step = step or runLog.step or 10
	local out = "AEGISMETER RUN-LOG  (Intervall " .. step .. " s)\n"
	out = out .. "Zeit    DPS im Intervall   Aenderung   Top-Zauber (DPS)\n"
	local prevT, prevTot = sm[1].t, sm[1].total
	local mark = prevT + step
	local prevDps = nil
	local peak, peakT, low, lowT = 0, 0, nil, 0
	local i
	for i = 1, n do
		local e = sm[i]
		if e.t >= mark then
			local dt = e.t - prevT
			local dps = (e.total - prevTot) / dt
			local chg = "      -"
			if prevDps and prevDps > 0 then
				chg = string.format("%+6.0f%%", (dps / prevDps - 1) * 100)
			end
			local top = ""
			local a = runLog.snaps[math.floor(prevT / 5)]
			local b = runLog.snaps[math.floor(e.t / 5)]
			if a and b and b.t > a.t then
				local arr = {}
				local name, dmg
				for name, dmg in pairs(b.spells) do
					local d = dmg - (a.spells[name] or 0)
					if d > 0 then
						arr[table.getn(arr) + 1] = { name = name, d = d }
					end
				end
				table.sort(arr, function(x, y)
					return x.d > y.d
				end)
				local k
				for k = 1, 3 do
					if arr[k] then
						top = top .. arr[k].name .. " " .. fmtAvg(arr[k].d / (b.t - a.t)) .. "  "
					end
				end
			end
			out = out .. string.format("%s   %12s   %s   %s\n", mmss(e.t), fmtAvg(dps), chg, top)
			if dps > peak then
				peak, peakT = dps, e.t
			end
			if not low or dps < low then
				low, lowT = dps, e.t
			end
			prevDps = dps
			prevT, prevTot = e.t, e.total
			mark = (math.floor(e.t / step) + 1) * step
		end
	end
	local last = sm[n]
	out = out .. "\nGesamt: " .. fmtBig(last.total) .. " in " .. mmss(last.t) .. "  (Schnitt " .. fmtAvg(last.total / last.t) .. " DPS)\n"
	if low then
		out = out .. "Spitze: " .. fmtAvg(peak) .. " DPS bei " .. mmss(peakT) .. "   Tief: " .. fmtAvg(low) .. " DPS bei " .. mmss(lowT) .. "\n"
	end
	return out
end

SLASH_AEGISMETER1 = "/aegismeter"
SlashCmdList["AEGISMETER"] = function(msg)
	msg = string.lower(msg or "")
	if msg == "reset" then
		doReset()
		refresh()
	elseif msg == "debug" then
		-- what does the game actually hand us? run it twice during a fight, a few seconds apart
		local dl, dtotal, dgame
		if AZS_GetMeter then
			dl, dtotal, dgame = AZS_GetMeter()
		end
		local dcount = 0
		if dl then
			dcount = table.getn(dl)
		end
		say("runtime " .. tostring(AZS_GetRunTime and AZS_GetRunTime()) .. "  total " .. tostring(dtotal) .. "  gameDps " .. tostring(dgame) .. "  lines " .. dcount)
		if dl and dl[1] then
			say("zeile1: " .. tostring(dl[1].name) .. "  dmg=" .. tostring(dl[1].dmg) .. "  dps=" .. tostring(dl[1].dps))
		end
		if AZS_METER then
			local rc = table.getn(AZS_METER)
			local rd = nil
			if AZS_METER[1] then
				rd = AZS_METER[1].dmg
			end
			say("AZS_METER lines " .. rc .. "  erste dmg=" .. tostring(rd))
		else
			say("AZS_METER: nil")
		end
		if AZS_IsHudShown then
			say("eingebauter Meter sichtbar: " .. tostring(AZS_IsHudShown("meter")))
		end
		say("fenster " .. dpsWindow() .. "s  anzeige total " .. tostring(bases[mode] and "reset aktiv" or "ohne reset"))
	elseif msg == "inspect" then
		showDump(inspectGame())
	elseif string.find(msg, "^globals") then
		-- lists the game's own API: every AZS_* global plus anything that looks like map/guardian/waypoint
		local _, _, filter = string.find(msg, "^globals%s+(%S+)")
		local names = {}
		local k, v
		for k, v in pairs(getfenv(0)) do
			if type(k) == "string" then
				local lk = string.lower(k)
				local hit = false
				if filter then
					hit = string.find(lk, filter, 1, true) ~= nil
				else
					hit = string.find(k, "^AZS") ~= nil or string.find(lk, "guardian", 1, true) ~= nil or string.find(lk, "waypoint", 1, true) ~= nil
				end
				if hit then
					names[table.getn(names) + 1] = k .. "(" .. string.sub(type(v), 1, 1) .. ")"
				end
			end
		end
		table.sort(names)
		local out = table.getn(names) .. " Treffer (f=Funktion, t=Tabelle)" .. "\n"
		local line = ""
		local n
		for n = 1, table.getn(names) do
			line = line .. names[n] .. " "
			if string.len(line) > 70 then
				out = out .. line .. "\n"
				line = ""
			end
		end
		out = out .. line
		showDump(out)
	elseif string.find(msg, "^log") then
		local _, _, v = string.find(msg, "^log%s*(%d+)")
		if v then
			local st = tonumber(v)
			if st < 5 then
				st = 5
			end
			runLog.step = st
		end
		showDump(logReport(runLog.step))
	elseif string.find(msg, "^dps") then
		local _, _, val = string.find(msg, "^dps%s*(%S*)")
		AegisMeterDB = AegisMeterDB or {}
		if val == "avg" or val == "0" then
			AegisMeterDB.dpsWindow = 0
			histories = {}
			say("DPS: Durchschnitt ueber den ganzen Lauf.")
		elseif tonumber(val) then
			local nsec = math.floor(tonumber(val))
			if nsec < 5 then
				nsec = 5
			elseif nsec > 120 then
				nsec = 120
			end
			AegisMeterDB.dpsWindow = nsec
			histories = {}
			say("DPS: ueber die letzten " .. nsec .. " Sekunden.")
		else
			say("DPS-Fenster: " .. dpsWindow() .. " s. Aendern: /aegismeter dps avg|10|60|120 (oder Klick auf die DPS-Zahl). Run-Log: /aegismeter log [Sekunden]")
		end
		refresh()
	else
		AegisMeterDB = AegisMeterDB or {}
		if frame:IsShown() then
			frame:Hide()
			AegisMeterDB.hidden = true
		else
			frame:Show()
			AegisMeterDB.hidden = false
		end
	end
end

-- Hub integration ------------------------------------------------------

local function hubHook()
	if not AegisUI or AegisUI.hooked_meter then
		return
	end
	AegisUI.hooked_meter = true
	AegisUI.register("meter", "DPS-Meter", frame, function()
		AegisMeterDB = AegisMeterDB or {}
		AegisMeterDB.point, AegisMeterDB.rel, AegisMeterDB.x, AegisMeterDB.y = nil, nil, nil, nil
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end)
	AegisUI.api.meter = {
		version = "4.9",
		isShown = function()
			return frame:IsShown()
		end,
		setShown = function(on)
			AegisMeterDB = AegisMeterDB or {}
			if on then
				frame:Show()
			else
				frame:Hide()
			end
			AegisMeterDB.hidden = not on
		end,
		cycleDps = cycleDps,
		showLog = function()
			showDump(logReport(runLog.step))
		end,
		getDps = function()
			return dpsWindow()
		end,
		setDps = function(n)
			AegisMeterDB = AegisMeterDB or {}
			AegisMeterDB.dpsWindow = n
			histories = {}
			refresh()
		end,
	}
end

hubHook()
local hookEv = CreateFrame("Frame")
hookEv:RegisterEvent("PLAYER_LOGIN")
hookEv:SetScript("OnEvent", hubHook)
