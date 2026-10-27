-- AegisHub: minimap button + one settings window for all AegisMeter modules (WoW 1.12 client, Lua 5.0).
-- Left click on the minimap button: open the window. Right click: lock / unlock.
-- Slash: /aegis (window), lock, unlock, reset, bars, who, meter|nav|units [args], chat, profile

local L = AegisL.t

local SOLID = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_NUM = "Fonts\\ARIALN.TTF"
local ICON = "Interface\\AddOns\\AegisUI\\icon"
local VERSION = "5.9.2"

local C_PANEL = { 0.04, 0.05, 0.08, 0.96 }
local C_EDGE = { 0.14, 0.16, 0.22, 1 }
local C_GOLD = { 0.78, 0.58, 0.22, 1 }
local C_ROW = { 0.06, 0.07, 0.10, 1 }
local C_ROW_EDGE = { 0.17, 0.19, 0.25, 1 }

local UI = AegisUI
local W = 420
local PAD = 8
local ROW_W = W - PAD * 2
local SIDE = 112          -- width of the module list on the left

-- call a module function if that module is loaded
local function A(mod, fn, a, b)
	local m = UI and UI.api and UI.api[mod]
	if m and m[fn] then
		return m[fn](a, b)
	end
	return nil
end

local function skin(f, bg, edge)
	f:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
	f:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
end

-- Window ---------------------------------------------------------------

local win = CreateFrame("Frame", "AegisHubFrame", UIParent)
win:SetWidth(W + SIDE)
win:SetHeight(440)
win:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
win:SetFrameStrata("FULLSCREEN_DIALOG")
win:SetMovable(true)
win:EnableMouse(true)
win:SetClampedToScreen(true)
skin(win, C_PANEL, C_EDGE)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", function()
	this:StartMoving()
end)
win:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
	local point, _, rel, x, y = this:GetPoint(1)
	if point then
		AegisDB = AegisDB or {}
		AegisDB.hub = { point, rel, x, y }
	end
end)
win:Hide()
if UISpecialFrames then
	table.insert(UISpecialFrames, "AegisHubFrame")
end

local glow = win:CreateTexture(nil, "BACKGROUND")
glow:SetTexture(SOLID)
glow:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -1)
glow:SetPoint("TOPRIGHT", win, "TOPRIGHT", -1, -1)
glow:SetHeight(30)
if glow.SetGradientAlpha then
	glow:SetGradientAlpha("VERTICAL", 0.05, 0.06, 0.10, 0, 0.16, 0.20, 0.32, 0.55)
else
	glow:SetVertexColor(0.10, 0.12, 0.18, 0.4)
end

local gold = win:CreateTexture(nil, "OVERLAY")
gold:SetTexture(SOLID)
gold:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 1)
gold:SetHeight(1)
gold:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -1)
gold:SetPoint("TOPRIGHT", win, "TOPRIGHT", -1, -1)

local title = win:CreateFontString(nil, "OVERLAY")
title:SetFont(FONT, 12, "OUTLINE")
title:SetTextColor(1, 1, 1)
title:SetPoint("TOPLEFT", win, "TOPLEFT", PAD + 2, -9)
title:SetText("AEGIS")

local ver = win:CreateFontString(nil, "OVERLAY")
ver:SetFont(FONT_NUM, 10, "")
ver:SetTextColor(0.49, 0.51, 0.58)
ver:SetPoint("LEFT", title, "RIGHT", 8, -1)
ver:SetText("v" .. VERSION)

local headLine = win:CreateTexture(nil, "ARTWORK")
headLine:SetTexture(SOLID)
headLine:SetVertexColor(C_EDGE[1], C_EDGE[2], C_EDGE[3], 1)
headLine:SetHeight(1)
headLine:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -28)
headLine:SetPoint("TOPRIGHT", win, "TOPRIGHT", -1, -28)

local closeBtn = CreateFrame("Button", nil, win)
closeBtn:SetWidth(18)
closeBtn:SetHeight(18)
closeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -6, -6)
skin(closeBtn, C_ROW, C_ROW_EDGE)
local closeX = closeBtn:CreateFontString(nil, "OVERLAY")
closeX:SetFont(FONT_NUM, 11, "")
closeX:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
closeX:SetText("x")
closeX:SetTextColor(0.70, 0.74, 0.84)
closeBtn:SetScript("OnClick", function()
	win:Hide()
end)
closeBtn:SetScript("OnEnter", function()
	closeX:SetTextColor(1, 1, 1)
end)
closeBtn:SetScript("OnLeave", function()
	closeX:SetTextColor(0.70, 0.74, 0.84)
end)

-- Builders -------------------------------------------------------------

local updaters = {}
local cursor = 6
local host = win

local function section(text)
	local fs = host:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT, 10, "OUTLINE")
	fs:SetTextColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 1)
	fs:SetPoint("TOPLEFT", host, "TOPLEFT", PAD + 2, -cursor)
	fs:SetText(text)
	local ln = host:CreateTexture(nil, "ARTWORK")
	ln:SetTexture(SOLID)
	ln:SetVertexColor(C_EDGE[1], C_EDGE[2], C_EDGE[3], 1)
	ln:SetHeight(1)
	ln:SetPoint("TOPLEFT", host, "TOPLEFT", PAD + 2, -(cursor + 13))
	ln:SetPoint("TOPRIGHT", host, "TOPRIGHT", -(PAD + 2), -(cursor + 13))
	cursor = cursor + 19
end

local function newRow(h)
	local r = CreateFrame("Button", nil, host)
	r:SetWidth(ROW_W)
	r:SetHeight(h)
	r:SetPoint("TOPLEFT", host, "TOPLEFT", PAD, -cursor)
	skin(r, C_ROW, C_ROW_EDGE)
	cursor = cursor + h + 3
	return r
end

local function label(parent, text, x)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT_NUM, 12, "")
	fs:SetTextColor(0.90, 0.92, 0.96)
	fs:SetPoint("LEFT", parent, "LEFT", x or 28, 0)
	fs:SetText(text)
	return fs
end

-- switch row: box + label + AN/AUS
local function toggle(text, getter, setter)
	local r = newRow(22)
	local box = CreateFrame("Frame", nil, r)
	box:SetWidth(12)
	box:SetHeight(12)
	box:SetPoint("LEFT", r, "LEFT", 8, 0)
	skin(box, { 0.03, 0.035, 0.05, 1 }, C_ROW_EDGE)
	local tick = box:CreateTexture(nil, "ARTWORK")
	tick:SetTexture(SOLID)
	tick:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 1)
	tick:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
	tick:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
	label(r, text, 28)
	local state = r:CreateFontString(nil, "OVERLAY")
	state:SetFont(FONT_NUM, 10, "")
	state:SetPoint("RIGHT", r, "RIGHT", -8, 0)
	local function upd()
		local on = getter()
		if on then
			tick:Show()
			state:SetText(L("ON"))
			state:SetTextColor(0.10, 0.93, 0.50)
		else
			tick:Hide()
			state:SetText(L("OFF"))
			state:SetTextColor(0.49, 0.51, 0.58)
		end
	end
	r:SetScript("OnClick", function()
		setter(not getter())
		upd()
	end)
	r:SetScript("OnEnter", function()
		this:SetBackdropBorderColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 0.8)
	end)
	r:SetScript("OnLeave", function()
		this:SetBackdropBorderColor(C_ROW_EDGE[1], C_ROW_EDGE[2], C_ROW_EDGE[3], 1)
	end)
	updaters[table.getn(updaters) + 1] = upd
end

local function smallBtn(parent, text, w)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(w)
	b:SetHeight(16)
	skin(b, { 0.03, 0.035, 0.05, 1 }, C_ROW_EDGE)
	local fs = b:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT_NUM, 12, "")
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	fs:SetText(text)
	fs:SetTextColor(0.80, 0.83, 0.90)
	b:SetScript("OnEnter", function()
		this:SetBackdropBorderColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 1)
	end)
	b:SetScript("OnLeave", function()
		this:SetBackdropBorderColor(C_ROW_EDGE[1], C_ROW_EDGE[2], C_ROW_EDGE[3], 1)
	end)
	return b
end

-- stepper row: label  [-] value [+]
local function stepper(text, getter, setter, step, lo, hi, fmt)
	local r = newRow(22)
	label(r, text, 8)
	local plus = smallBtn(r, "+", 20)
	plus:SetPoint("RIGHT", r, "RIGHT", -6, 0)
	local val = r:CreateFontString(nil, "OVERLAY")
	val:SetFont(FONT, 11, "OUTLINE")
	val:SetTextColor(1, 0.86, 0.45)
	val:SetWidth(64)
	val:SetJustifyH("CENTER")
	val:SetPoint("RIGHT", plus, "LEFT", -2, 0)
	local minus = smallBtn(r, "-", 20)
	minus:SetPoint("RIGHT", val, "LEFT", -2, 0)
	local function upd()
		local v = getter()
		if v == nil then
			val:SetText("-")
		elseif fmt then
			val:SetText(fmt(v))
		else
			val:SetText(tostring(v))
		end
	end
	local function change(dir)
		local v = getter() or lo
		local nv = v + dir * step
		if nv < lo then
			nv = lo
		elseif nv > hi then
			nv = hi
		end
		setter(nv)
		upd()
	end
	plus:SetScript("OnClick", function()
		change(1)
	end)
	minus:SetScript("OnClick", function()
		change(-1)
	end)
	updaters[table.getn(updaters) + 1] = upd
end

-- wide action button
local function action(textFn, onClick, accent)
	local b = CreateFrame("Button", nil, host)
	b:SetWidth(ROW_W)
	b:SetHeight(26)
	b:SetPoint("TOPLEFT", host, "TOPLEFT", PAD, -cursor)
	skin(b, C_ROW, C_GOLD)
	local fs = b:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT, 11, "OUTLINE")
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	cursor = cursor + 29
	local function upd()
		local t, r, g, bl = textFn()
		fs:SetText(t)
		fs:SetTextColor(r, g, bl)
		if accent then
			local ex = accent()
			if ex then
				b:SetBackdropColor(0.22, 0.17, 0.08, 1)
			else
				b:SetBackdropColor(C_ROW[1], C_ROW[2], C_ROW[3], 1)
			end
		end
	end
	b:SetScript("OnClick", function()
		onClick()
		upd()
	end)
	b:SetScript("OnEnter", function()
		this:SetBackdropBorderColor(1, 0.86, 0.45, 1)
	end)
	b:SetScript("OnLeave", function()
		this:SetBackdropBorderColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 1)
	end)
	updaters[table.getn(updaters) + 1] = upd
end

-- Profile export / import -------------------------------------------------------------

local profFrame

local function ser(v, depth)
	local t = type(v)
	if t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "string" then
		return string.format("%q", v)
	elseif t == "table" then
		if depth > 6 then
			return "nil"
		end
		local out = "{"
		local k, x
		for k, x in pairs(v) do
			local kk = nil
			if type(k) == "number" then
				kk = "[" .. k .. "]"
			elseif type(k) == "string" then
				kk = "[" .. string.format("%q", k) .. "]"
			end
			local tx = type(x)
			if kk and tx ~= "function" and tx ~= "userdata" and tx ~= "thread" then
				out = out .. kk .. "=" .. ser(x, depth + 1) .. ","
			end
		end
		return out .. "}"
	end
	return "nil"
end

local PROFILE_DBS = { ui = "AegisDB", meter = "AegisMeterDB", nav = "AegisNavDB", units = "AegisUnitsDB" }

local function exportProfile()
	local pack = {}
	local key, gname
	for key, gname in pairs(PROFILE_DBS) do
		local t = getglobal(gname)
		if type(t) == "table" then
			pack[key] = t
		end
	end
	if pack.meter then
		-- the copy window text is no setting
		local copy = {}
		local k, v
		for k, v in pairs(pack.meter) do
			if k ~= "dump" then
				copy[k] = v
			end
		end
		pack.meter = copy
	end
	return "AEGIS1:" .. ser(pack, 0)
end

local function importProfile(text)
	text = text or ""
	local _, _, body = string.find(text, "^%s*AEGIS1:(.*)$")
	if not body then
		return false, L("Not a valid profile (must start with AEGIS1:).")
	end
	local f, err = loadstring("return " .. body)
	if not f then
		return false, L("Profile unreadable: ") .. tostring(err)
	end
	-- empty environment: the text can only build tables, it cannot call anything
	setfenv(f, {})
	local ok, pack = pcall(f)
	if not ok or type(pack) ~= "table" then
		return false, L("Profile unreadable.")
	end
	local n = 0
	local key, gname
	for key, gname in pairs(PROFILE_DBS) do
		if type(pack[key]) == "table" then
			setglobal(gname, pack[key])
			n = n + 1
		end
	end
	if n == 0 then
		return false, L("Profile contained no settings.")
	end
	return true, n .. L(" sections imported. Apply with /reload.")
end

local function showProfile()
	if not profFrame then
		local f = CreateFrame("Frame", "AegisProfileFrame", UIParent)
		f:SetWidth(480)
		f:SetHeight(300)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:SetClampedToScreen(true)
		skin(f, C_PANEL, C_GOLD)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", function() this:StartMoving() end)
		f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

		local t = f:CreateFontString(nil, "OVERLAY")
		t:SetFont(FONT, 12, "OUTLINE")
		t:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
		t:SetTextColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 1)
		t:SetText(L("AegisUI Profile"))
		local hint = f:CreateFontString(nil, "OVERLAY")
		hint:SetFont(FONT, 10)
		hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -11)
		hint:SetTextColor(0.5, 0.54, 0.62, 1)
		hint:SetText(L("Export: select + Ctrl+C   Import: paste text (Ctrl+V)"))

		local sf = CreateFrame("ScrollFrame", "AegisProfileScroll", f, "UIPanelScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
		sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 66)
		local eb = CreateFrame("EditBox", "AegisProfileEdit", sf)
		eb:SetMultiLine(true)
		eb:SetAutoFocus(false)
		eb:SetFontObject(ChatFontNormal)
		eb:SetWidth(430)
		eb:SetHeight(400)
		eb:SetMaxLetters(60000)
		eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
		sf:SetScrollChild(eb)
		f.edit = eb

		local status = f:CreateFontString(nil, "OVERLAY")
		status:SetFont(FONT_NUM, 11, "")
		status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 40)
		status:SetTextColor(0.8, 0.83, 0.9)
		f.status = status

		local function mkBtn(label, x, w, fn)
			local b = CreateFrame("Button", nil, f)
			b:SetWidth(w)
			b:SetHeight(22)
			b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 10)
			skin(b, C_ROW, C_GOLD)
			local l = b:CreateFontString(nil, "OVERLAY")
			l:SetFont(FONT, 11, "OUTLINE")
			l:SetPoint("CENTER", b, "CENTER", 0, 0)
			l:SetText(label)
			l:SetTextColor(1, 0.85, 0.4, 1)
			b:SetScript("OnClick", fn)
		end
		mkBtn(L("Export"), 10, 100, function()
			profFrame.edit:SetText(exportProfile())
			profFrame.edit:SetFocus()
			profFrame.edit:HighlightText()
			profFrame.status:SetText(L("Profile created. Everything is selected: Ctrl+C to copy."))
		end)
		mkBtn(L("Import"), 120, 100, function()
			local ok, msg = importProfile(profFrame.edit:GetText())
			if ok then
				profFrame.status:SetText("|cff55ee88" .. msg .. "|r")
			else
				profFrame.status:SetText("|cffff6666" .. msg .. "|r")
			end
		end)
		mkBtn(L("Close"), 230, 90, function()
			profFrame:Hide()
		end)
		profFrame = f
	end
	profFrame.status:SetText("")
	profFrame:Show()
	profFrame.edit:SetText(exportProfile())
end

-- Content --------------------------------------------------------------

local TABS = { "CORE", "METER", "UNITS", "FONTS", "CHAT", "MINIMAP", "SKINS" }
local tabFrames = {}
local tabButtons = {}
local TOP_TABS = 36
local TAB_H = 24

local function selectTab(n)
	local i
	for i = 1, table.getn(tabFrames) do
		if i == n then
			tabFrames[i].scroll:SetVerticalScroll(0)
			tabFrames[i]:Show()
			tabFrames[i].placeThumb()
			tabButtons[i].text:SetTextColor(1, 0.86, 0.45)
			tabButtons[i].line:Show()
		else
			tabFrames[i]:Hide()
			tabButtons[i].text:SetTextColor(0.62, 0.64, 0.70)
			tabButtons[i].line:Hide()
		end
	end
	AegisDB = AegisDB or {}
	AegisDB.tab2 = n
end

local function startTab(n)
	if host and host ~= win and host.SetHeight then
		host:SetHeight(cursor + 12)      -- the page built before this one is now complete
	end
	host = tabFrames[n].content
	cursor = 6
end

local function buildTabs()
	-- 1 px gold separator between the module list and the control panel
	local sep = win:CreateTexture(nil, "ARTWORK")
	sep:SetTexture(SOLID)
	sep:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 0.8)
	sep:SetWidth(1)
	sep:SetPoint("TOPLEFT", win, "TOPLEFT", SIDE, -29)
	sep:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", SIDE, 1)
	local i
	for i = 1, table.getn(TABS) do
		local f = CreateFrame("Frame", nil, win)
		f:SetPoint("TOPLEFT", win, "TOPLEFT", SIDE + 1, -30)
		f:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -1, 1)
		f:Hide()
		-- content scrolls with the mouse wheel when it is longer than the window
		local sf = CreateFrame("ScrollFrame", nil, f)
		sf:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 20)
		local c = CreateFrame("Frame", nil, sf)
		c:SetWidth(W - 1)
		c:SetHeight(400)
		sf:SetScrollChild(c)
		sf:EnableMouseWheel(true)
		local thumb = f:CreateTexture(nil, "OVERLAY")
		thumb:SetTexture(SOLID)
		thumb:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 0.8)
		thumb:SetWidth(2)
		thumb:SetHeight(36)
		thumb:Hide()
		f.thumb = thumb
		local function place(frame)
			local range = tonumber(frame:GetVerticalScrollRange()) or 0
			if range <= 0 then
				thumb:Hide()
				return
			end
			local h = tonumber(frame:GetHeight()) or 300
			local frac = (tonumber(frame:GetVerticalScroll()) or 0) / range
			thumb:ClearAllPoints()
			thumb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -(frac * (h - 36)))
			thumb:Show()
		end
		sf:SetScript("OnMouseWheel", function()
			local range = tonumber(this:GetVerticalScrollRange()) or 0
			local v = (tonumber(this:GetVerticalScroll()) or 0) - (arg1 or 0) * 30
			if v < 0 then
				v = 0
			elseif v > range then
				v = range
			end
			this:SetVerticalScroll(v)
			place(this)
		end)
		f.content = c
		f.scroll = sf
		f.placeThumb = function()
			place(sf)
		end
		tabFrames[i] = f
		-- flat module entry on the left; the selected one gets a gold bar
		local b = CreateFrame("Button", nil, win)
		b:SetWidth(SIDE - 14)
		b:SetHeight(TAB_H)
		b:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -(TOP_TABS + (i - 1) * (TAB_H + 3)))
		skin(b, C_ROW, C_ROW_EDGE)
		b.text = b:CreateFontString(nil, "OVERLAY")
		b.text:SetFont(FONT_NUM, 12, "OUTLINE")
		b.text:SetPoint("LEFT", b, "LEFT", 10, 0)
		b.text:SetText(L(TABS[i]))
		b.line = b:CreateTexture(nil, "OVERLAY")
		b.line:SetTexture(SOLID)
		b.line:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 1)
		b.line:SetWidth(2)
		b.line:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
		b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
		b.idx = i
		b:SetScript("OnClick", function()
			selectTab(this.idx)
		end)
		tabButtons[i] = b
	end
end

local refreshAllHook = function() end

-- appearance block of one module: opacity, colours, outline, "Reset Defaults"
local function lookBlock(mod, opts, onReset)
	if not (AegisSkin and AegisSkin.GetLook) then
		return
	end
	cursor = cursor + 4
	section(L("OPACITY"))
	local function pct(v)
		return math.floor(v + 0.5) .. " %"
	end
	stepper(L("Background opacity"), function() local bg = AegisSkin.GetLook(mod) return bg end, function(v) AegisSkin.SetLook("bg", v, mod) end, 2, 0, 100, pct)
	if opts.edge then
		stepper(L("Border opacity"), function() local _, e = AegisSkin.GetLook(mod) return e end, function(v) AegisSkin.SetLook("edge", v, mod) end, 10, 0, 100, pct)
	end
	toggle(L("Force solid dark background"), function() local _, _, _, so = AegisSkin.GetLook(mod) return so end, function(v) AegisSkin.SetLook("solid", v, mod) end)
	cursor = cursor + 4
	section(L("COLORS"))
	local function cycle(key, list, idx, name)
		action(function()
			local i = idx()
			return L(name) .. L(list[i][1]), 1, 0.86, 0.45
		end, function()
			local n = idx() + 1
			if n > table.getn(list) then
				n = 1
			end
			AegisSkin.SetLook(key, n, mod)
		end)
	end
	if opts.edge then
		cycle("edgep", AegisSkin.EDGE_PRESETS, function() local _, _, _, _, _, e = AegisSkin.GetLook(mod) return e end, "Border colour: ")
	end
	cycle("bgp", AegisSkin.BG_PRESETS, function() local _, _, _, _, b = AegisSkin.GetLook(mod) return b end, "Background colour: ")
	if opts.fonts then
		cursor = cursor + 4
		section(L("FONT"))
		stepper(L("Font size (12 = original)"), function() local sz = AegisSkin.GetFont(mod) return sz end, function(v) AegisSkin.SetLook("fsize", v, mod) end, 1, 8, 24, function(v)
			return math.floor(v + 0.5) .. " px"
		end)
		action(function()
			local _, p = AegisSkin.GetFont(mod)
			return L("Font: ") .. L(AegisSkin.FONT_PRESETS[p][1]), 1, 0.86, 0.45
		end, function()
			local _, p = AegisSkin.GetFont(mod)
			p = p + 1
			if p > table.getn(AegisSkin.FONT_PRESETS) then
				p = 1
			end
			AegisSkin.SetLook("fontp", p, mod)
		end)
	end
	cursor = cursor + 4
	section(L("CONTRAST"))
	toggle(L("Black outline around panels"), function() local _, _, o = AegisSkin.GetLook(mod) return o end, function(v) AegisSkin.SetLook("outer", v, mod) end)
	cursor = cursor + 4
	action(function()
		return L("RESET DEFAULTS"), 0.80, 0.83, 0.90
	end, function()
		AegisSkin.ResetLook(mod)
		if onReset then
			onReset()
		end
		refreshAllHook()
	end)
end

local function noteText(t)
	local fs = host:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT_NUM, 11, "")
	fs:SetTextColor(0.49, 0.51, 0.58)
	fs:SetPoint("TOPLEFT", host, "TOPLEFT", PAD + 2, -cursor)
	fs:SetText(t)
	cursor = cursor + 16
end

local function buildContent()
	local api = UI.api
	buildTabs()

	-- Page 1: CORE -------------------------------------------------
	startTab(1)
	action(function()
		if UI.locked then
			return L("UNLOCK  -  move windows"), 1, 0.86, 0.45
		end
		return L("LOCK  -  fix positions"), 0.10, 0.93, 0.50
	end, function()
		UI.setLocked(not UI.locked)
	end, function()
		return not UI.locked
	end)
	toggle(L("Snap to grid"), function() return UI.snap end, function(v) UI.setSnap(v) end)
	stepper(L("Grid"), function() return UI.grid end, function(v) UI.setGrid(v) end, 4, 0, 32, function(v)
		if v == 0 then
			return L("off")
		end
		return v .. " px"
	end)
	if api.nav then
		toggle(L("Waypoint arrow + boss HP"), function() return A("nav", "isShown") end, function(v) A("nav", "setShown", v) end)
	end
	if api.units or api.nav then
		cursor = cursor + 4
		section(L("HIDE ORIGINAL"))
		if api.units then
			toggle(L("Default player and target frames"), function() return A("units", "getStockHidden") end, function(v) A("units", "setStockHidden", v) end)
		end
		if api.nav then
			toggle(L("Original boss bar"), function() return A("nav", "getHudHidden", "bosses") end, function(v) A("nav", "setHudHidden", "bosses", v) end)
		end
	end
	if api.bars then
		if not (api.units or api.nav) then
			cursor = cursor + 4
			section(L("HIDE ORIGINAL"))
		end
		toggle(L("Never dim action icons"), function() return A("bars", "getNoDim") end, function(v) A("bars", "setNoDim", v) end)
		toggle(L("Gryphons + bar background"), function() return A("bars", "getArt") end, function(v) A("bars", "setArt", v) end)
	end
	if api.bars then
		toggle(L("Custom action bar + XP bar"), function() return A("bars", "getCustom") end, function(v) A("bars", "setCustom", v) end)
	end
	if UI.getScale then
		cursor = cursor + 4
		section(L("WINDOW SIZE"))
		local keys = { { "meter", "DPS-Meter" }, { "player", "Player card" }, { "target", "Target card" }, { "nav", "Arrow / boss HP" }, { "bar", "Action bar" }, { "luck", "Luck window (LuckyOdds)" } }
		local ki
		for ki = 1, table.getn(keys) do
			local key = keys[ki][1]
			stepper(L(keys[ki][2]), function()
				local s = UI.getScale(key)
				if s then
					return s * 100
				end
				return nil
			end, function(v) UI.setScaleSaved(key, v / 100) end, 10, 50, 250, function(v)
				return math.floor(v + 0.5) .. " %"
			end)
		end
		noteText(L("Or drag the gold + in a window's corner while unlocked."))
	end
	lookBlock("core", { edge = true }, function()
		AegisDB.pixel = nil
		UI.resetScales()
	end)
	cursor = cursor + 4
	section(L("GENERAL"))
	toggle(L("Pixel-perfect borders (after /reload)"), function() return not (AegisDB and AegisDB.pixel == false) end, function(v)
		AegisDB = AegisDB or {}
		AegisDB.pixel = v and true or false
	end)
	cursor = cursor + 4
	action(function()
		local l = AegisDB and AegisDB.lang
		local nm = "Auto"
		if l == "de" then
			nm = "Deutsch"
		elseif l == "en" then
			nm = "English"
		end
		return L("Language: ") .. nm .. L("  (click, then /reload)"), 1, 0.86, 0.45
	end, function()
		AegisDB = AegisDB or {}
		local l = AegisDB.lang
		if l == nil then
			AegisDB.lang = "en"
		elseif l == "en" then
			AegisDB.lang = "de"
		else
			AegisDB.lang = nil
		end
	end)
	action(function()
		return L("PROFILE EXPORT / IMPORT"), 1, 0.86, 0.45
	end, function()
		showProfile()
	end)
	action(function()
		return L("RESET POSITIONS"), 0.80, 0.83, 0.90
	end, function()
		UI.resetAll()
	end, nil)

	-- Page 2: METER -------------------------------------------------
	startTab(2)
	if api.meter then
		section(L("DPS-METER"))
		toggle("DPS-Meter", function() return A("meter", "isShown") end, function(v) A("meter", "setShown", v) end)
		stepper(L("Meter rows"), function() return A("meter", "getRows") end, function(v) A("meter", "setRows", v) end, 1, 3, 10, function(v)
			return math.floor(v + 0.5)
		end)
		stepper(L("Meter width"), function() return A("meter", "getWidth") end, function(v) A("meter", "setWidth", v) end, 20, 260, 520, function(v)
			return math.floor(v + 0.5) .. " px"
		end)
		toggle(L("Meter title"), function() return A("meter", "getTitle") end, function(v) A("meter", "setTitle", v) end)
		toggle(L("Run timer"), function() return A("meter", "getTimer") end, function(v) A("meter", "setTimer", v) end)
		toggle(L("Kill counter"), function() return A("meter", "getKills") end, function(v) A("meter", "setKills", v) end)
		stepper(L("DPS time window"), function() return A("meter", "getDps") end, function(v)
			-- 0 = average over the whole run; the smallest real window is 5 s
			local cur = A("meter", "getDps") or 10
			if v > 0 and v < 5 then
				if cur == 0 then
				v = 5
				else
				v = 0
				end
			end
			A("meter", "setDps", v)
		end, 5, 0, 120, function(v)
			if v == 0 then
				return L("Average")
			end
			return v .. " s"
		end)
		action(function()
			local w = A("meter", "getDps") or 10
			if w == 0 then
				return L("DPS window: default (click = next)"), 1, 0.86, 0.45
			end
			return L("DPS window: ") .. w .. L(" s (click = next)"), 1, 0.86, 0.45
		end, function()
			A("meter", "cycleDps")
		end)
		action(function()
			return L("SHOW RUN LOG"), 1, 0.86, 0.45
		end, function()
			A("meter", "showLog")
		end)
		lookBlock("meter", { edge = true, fonts = true }, function()
			A("meter", "setRows", 7)
			A("meter", "setWidth", 360)
			A("meter", "setTitle", false)
			A("meter", "setTimer", false)
			A("meter", "setKills", true)
		end)
	else
		section(L("DPS-METER"))
		noteText(L("AegisMeter is not loaded."))
	end

	-- Page 3: UNITS -------------------------------------------------
	startTab(3)
	if api.units then
		section(L("UNIT FRAMES"))
		toggle(L("Player card"), function() return A("units", "getPlayer") end, function(v) A("units", "setPlayer", v) end)
		toggle(L("Target card"), function() return A("units", "getTarget") end, function(v) A("units", "setTarget", v) end)
		toggle(L("Dim target card unless boss / guardian"), function() return A("units", "getTargetFade") end, function(v) A("units", "setTargetFade", v) end)
		toggle(L("Mob nameplates"), function() return A("units", "getPlates") end, function(v) A("units", "setPlates", v) end)
		stepper(L("Card spacing"), function() return A("units", "getGap") end, function(v) A("units", "setGap", v) end, 10, 20, 400, function(v)
			return math.floor(v + 0.5) .. " px"
		end)
		lookBlock("units", { edge = false, fonts = true }, function()
			A("units", "setPlayer", true)
			A("units", "setTarget", true)
			A("units", "setTargetFade", true)
			A("units", "setPlates", true)
			A("units", "setGap", 110)
		end)
	else
		section(L("UNIT FRAMES"))
		noteText(L("AegisUnits is not loaded."))
	end

	-- Page 4: FONTS ---------------------------------------------------
	startTab(4)
	section(L("COMBAT NUMBERS"))
	if api.ct then
		action(function()
			local m = A("ct", "getMode")
			local nm = L("Off")
			if m == "crit" then
				nm = L("Crits only")
			elseif m == "all" then
				nm = L("All hits")
			end
			return L("Combat numbers: ") .. nm, 1, 0.86, 0.45
		end, function()
			A("ct", "cycleMode")
		end)
		action(function()
			local s = A("ct", "getSize")
			local nm = L("Medium")
			if s == "small" then
				nm = L("Small")
			elseif s == "large" then
				nm = L("Large")
			end
			return L("Number size: ") .. nm, 1, 0.86, 0.45
		end, function()
			A("ct", "cycleSize")
		end)
		action(function()
			return L("Show test numbers"), 1, 0.86, 0.45
		end, function()
			A("ct", "test")
		end)
	end
	if api.fonts then
		if not api.ct then
			toggle(L("Damage numbers over enemies"), function() return A("fonts", "getDamage") end, function(v) A("fonts", "setDamage", v) end)
		end
		if A("fonts", "hasHealing") then
			toggle(L("Healing numbers"), function() return A("fonts", "getHealing") end, function(v) A("fonts", "setHealing", v) end)
		end
		toggle(L("Aegis font for numbers (after restart)"), function() return A("fonts", "getFont") end, function(v) A("fonts", "setFont", v) end)
	end
	if api.fonts then
		if not api.ct then
			toggle(L("Damage numbers over enemies"), function() return A("fonts", "getDamage") end, function(v) A("fonts", "setDamage", v) end)
		end
		if A("fonts", "hasHealing") then
			toggle(L("Healing numbers"), function() return A("fonts", "getHealing") end, function(v) A("fonts", "setHealing", v) end)
		end
		toggle(L("Aegis font for numbers (after restart)"), function() return A("fonts", "getFont") end, function(v) A("fonts", "setFont", v) end)
	end
	cursor = cursor + 4
	action(function()
		return L("RESET DEFAULTS"), 0.80, 0.83, 0.90
	end, function()
		if api.fonts then
			A("fonts", "setDamage", true)
			if A("fonts", "hasHealing") then
				A("fonts", "setHealing", true)
			end
			A("fonts", "setFont", true)
		end
		refreshAllHook()
	end)

	-- Page 5: CHAT ----------------------------------------------------
	startTab(5)
	section(L("CHAT"))
	if api.chat then
		toggle(L("Chat reskin (off after /reload)"), function() return A("chat", "isOn") end, function(v) A("chat", "setOn", v) end)
	end
	if api.chat then
		stepper(L("Chat width"), function() return A("chat", "getW") end, function(v) A("chat", "setW", v) end, 10, 220, 900, function(v)
			return math.floor(v + 0.5) .. " px"
		end)
		stepper(L("Chat height"), function() return A("chat", "getH") end, function(v) A("chat", "setH", v) end, 10, 90, 600, function(v)
			return math.floor(v + 0.5) .. " px"
		end)
		noteText(L("Unlocked: drag the gold + at the chat's top-right corner."))
	end
	lookBlock("chat", { edge = true }, function()
		if AegisDB then
			AegisDB.chatW, AegisDB.chatH = nil, nil
			AegisDB.chatPlaced = nil
		end
	end)

	-- Page 6: MINIMAP -------------------------------------------------
	startTab(6)
	section(L("MINIMAP"))
	if api.map then
		toggle(L("Square minimap"), function() return A("map", "getSquare") end, function(v) A("map", "setSquare", v) end)
		toggle(L("Clean minimap (flat buttons, wheel zooms)"), function() return A("map", "getClean") end, function(v) A("map", "setClean", v) end)
		stepper(L("Minimap size"), function() return A("map", "getScale") end, function(v) A("map", "setScale", v) end, 0.1, 0.6, 2, function(v)
			return math.floor(v * 100 + 0.5) .. " %"
		end)
		cursor = cursor + 4
		action(function()
			return L("RESET DEFAULTS"), 0.80, 0.83, 0.90
		end, function()
			A("map", "setScale", 1)
			A("map", "setClean", true)
			refreshAllHook()
		end)
	else
		noteText(L("Minimap module is not loaded."))
	end

	-- Page 7: SKINS (every registered third-party skin shows up here) -----------
	startTab(7)
	section(L("THIRD-PARTY ADDONS"))
	local sk = AegisSkin
	local n = 0
	if sk and sk.order then
		local i
		for i = 1, table.getn(sk.order) do
			local name = sk.order[i]
			local d = sk.registry[name]
			local text = L(d.label)
			if not sk.IsLoaded(name) then
				text = text .. L("  (not installed)")
			end
			n = n + 1
			toggle(text, function() return sk.IsEnabled(name) end, function(v)
				sk.SetEnabled(name, v)
				if not v and DEFAULT_CHAT_FRAME then
					DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUI:|r Skin '" .. L(d.label) .. L("' will be disabled after /reload."))
				end
			end)
		end
	end
	if n == 0 then
		local fs = host:CreateFontString(nil, "OVERLAY")
		fs:SetFont(FONT_NUM, 11, "")
		fs:SetTextColor(0.49, 0.51, 0.58)
		fs:SetPoint("TOPLEFT", host, "TOPLEFT", PAD + 2, -cursor)
		fs:SetText(L("No skins registered."))
	else
		cursor = cursor + 4
		local fs = host:CreateFontString(nil, "OVERLAY")
		fs:SetFont(FONT_NUM, 10, "")
		fs:SetTextColor(0.49, 0.51, 0.58)
		fs:SetPoint("TOPLEFT", host, "TOPLEFT", PAD + 2, -cursor)
		fs:SetWidth(ROW_W - 4)
		fs:SetJustifyH("LEFT")
		fs:SetText(L("Enabling works immediately, disabling after /reload. New skins register themselves (AegisSkin.RegisterSkin)."))
	end

	-- other loaded addons found at login: experimental generic restyle, off by default
	if sk and sk.Discover then
		local found = sk.Discover()
		if table.getn(found) > 0 then
			cursor = cursor + 4
			section(L("MORE ADDONS (EXPERIMENTAL)"))
			local shown = 0
			local j
			for j = 1, table.getn(found) do
				if shown < 6 then
					local nm = found[j].name
					shown = shown + 1
					toggle(nm, function() return sk.GenericEnabled(nm) end, function(v)
						sk.SetGeneric(nm, v)
						if not v and DEFAULT_CHAT_FRAME then
							DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUI:|r '" .. nm .. L("' returns to original after /reload."))
						end
					end)
				end
			end
			if table.getn(found) > shown then
				local fs = host:CreateFontString(nil, "OVERLAY")
				fs:SetFont(FONT_NUM, 10, "")
				fs:SetTextColor(0.49, 0.51, 0.58)
				fs:SetPoint("TOPLEFT", host, "TOPLEFT", PAD + 2, -cursor)
				fs:SetText("+ " .. (table.getn(found) - shown) .. L(" more not listed"))
				cursor = cursor + 14
			end
		end
	end

	-- parts of the game's SurvivorUI that AegisUI replaces (needs /reload)
	if api.survivor and SurvivorUI_Feature then
		cursor = cursor + 4
		section(L("REPLACE SURVIVORUI"))
		local sv = api.survivor
		local i
		for i = 1, table.getn(sv.parts) do
			local part = sv.parts[i]
			toggle(L(part.label) .. L(" off"), function() return sv.getOff(part.key) end, function(v) sv.setOff(part.key, v) end)
		end
	end

	-- installed AegisUI parts and their versions, as a footer line
	local foot = win:CreateFontString(nil, "OVERLAY")
	foot:SetFont(FONT_NUM, 9, "")
	foot:SetTextColor(0.49, 0.51, 0.58)
	foot:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD + 2, 5)
	local line = "UI " .. VERSION
	local names = { { "meter", "Meter" }, { "nav", "Nav" }, { "units", "Units" } }
	local k
	for k = 1, table.getn(names) do
		local m = api[names[k][1]]
		if m then
			line = line .. "   " .. names[k][2] .. " " .. tostring(m.version or "?")
		end
	end
	foot:SetText(line)

	local start = 1
	if AegisDB and AegisDB.tab2 and tabFrames[AegisDB.tab2] then
		start = AegisDB.tab2
	end
	if host and host ~= win and host.SetHeight then
		host:SetHeight(cursor + 12)
	end
	selectTab(start)
end

-- the modules (separate addons) register themselves while loading; build the rows once all are in
local built = false
local buildEv = CreateFrame("Frame")
buildEv:RegisterEvent("PLAYER_LOGIN")
buildEv:SetScript("OnEvent", function()
	if not built then
		built = true
		buildContent()
	end
end)


local function refreshAll()
	local i
	for i = 1, table.getn(updaters) do
		updaters[i]()
	end
end

refreshAllHook = refreshAll

local acc = 0
win:SetScript("OnUpdate", function()
	acc = acc + (arg1 or 0)
	if acc < 0.4 then
		return
	end
	acc = 0
	refreshAll()
end)
win:SetScript("OnShow", function()
	refreshAll()
end)

local function toggleHub()
	if win:IsShown() then
		win:Hide()
	else
		win:Show()
	end
end

-- Minimap button -----------------------------------------------------

local parent = Minimap or UIParent
local mb = CreateFrame("Button", "AegisHubMinimapButton", parent)
mb:SetWidth(31)
mb:SetHeight(31)
mb:SetFrameStrata("MEDIUM")
mb:SetFrameLevel((parent:GetFrameLevel() or 1) + 8)

local mbIcon = mb:CreateTexture(nil, "BACKGROUND")
mbIcon:SetTexture(ICON)
mbIcon:SetWidth(20)
mbIcon:SetHeight(20)
mbIcon:SetPoint("TOPLEFT", mb, "TOPLEFT", 7, -5)
local mbBorder = mb:CreateTexture(nil, "OVERLAY")
mbBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mbBorder:SetWidth(53)
mbBorder:SetHeight(53)
mbBorder:SetPoint("TOPLEFT", mb, "TOPLEFT", 0, 0)
mb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mb:RegisterForClicks("LeftButtonUp", "RightButtonUp")

local function placeButton()
	mb:ClearAllPoints()
	if AegisDB and AegisDB.free then
		-- free position (Shift + drag): measured from the bottom-left of the screen
		mb:SetPoint("CENTER", UIParent, "BOTTOMLEFT", AegisDB.free[1], AegisDB.free[2])
		return
	end
	local a = (AegisDB and AegisDB.angle) or 140
	local rad = math.rad(a)
	local x, y = math.cos(rad), math.sin(rad)
	local r = 82
	if AegisUISquare and AegisUISquare() and Minimap then
		local m = math.max(math.abs(x), math.abs(y))
		x, y = x / m, y / m
		r = (Minimap:GetWidth() or 140) / 2 + 6
	end
	mb:SetPoint("CENTER", parent, "CENTER", x * r, y * r)
end
AegisUIPlaceButton = placeButton
placeButton()

-- Drag with the standard drag events (the same way LuckyOdds' button works).
-- Plain drag: slides around the minimap edge. Shift + drag: free placement anywhere.
local drag = { moved = false }

local function dragStep()
	drag.moved = true
	AegisDB = AegisDB or {}
	local cx, cy = GetCursorPosition()
	local mx, my
	if parent.GetCenter then
		mx, my = parent:GetCenter()
	end
	if IsShiftKeyDown() or not mx then
		local us = UIParent:GetEffectiveScale()
		AegisDB.free = { cx / us, cy / us }
	else
		local sc = parent:GetEffectiveScale()
		AegisDB.free = nil
		AegisDB.angle = math.deg(math.atan2(cy / sc - my, cx / sc - mx))
	end
	placeButton()
end

mb:RegisterForDrag("LeftButton")
mb:SetScript("OnMouseDown", function()
	drag.moved = false
end)
mb:SetScript("OnDragStart", function()
	this:SetScript("OnUpdate", dragStep)
end)
mb:SetScript("OnDragStop", function()
	this:SetScript("OnUpdate", nil)
end)
mb:SetScript("OnClick", function()
	if drag.moved then
		drag.moved = false     -- the click that ends a drag is not a click
		return
	end
	if arg1 == "RightButton" then
		UI.setLocked(not UI.locked)
	else
		toggleHub()
	end
end)
mb:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:AddLine("AegisUI", 1, 0.86, 0.45)
	GameTooltip:AddLine(L("Left-click: settings"), 0.8, 0.83, 0.9)
	if UI.locked then
		GameTooltip:AddLine(L("Right-click: unlock"), 0.8, 0.83, 0.9)
	else
		GameTooltip:AddLine(L("Right-click: lock"), 0.8, 0.83, 0.9)
	end
	GameTooltip:AddLine(L("Drag: along the edge, free with Shift"), 0.5, 0.54, 0.62)
	GameTooltip:Show()
end)
mb:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- Loading + commands -------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
	if arg1 ~= "AegisUI" then
		return
	end
	AegisDB = AegisDB or {}
	if AegisDB.hub then
		win:ClearAllPoints()
		win:SetPoint(AegisDB.hub[1], UIParent, AegisDB.hub[2] or AegisDB.hub[1], AegisDB.hub[3] or 0, AegisDB.hub[4] or 0)
	end
	placeButton()
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUI|r v" .. VERSION .. L(" loaded. /aegis opens the settings."))
	end
end)

-- /aegis ct: what does this client use for the numbers that fly up from enemies? (diagnostic)
local function combatTextDiag()
	local function say(t)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aCT:|r " .. t)
		end
	end
	local names = { "floatingCombatText", "floatingCombatTextCombatDamage", "floatingCombatTextCombatHealing",
		"floatingCombatTextCombatState", "floatingCombatTextDamageReduction", "fctDamage", "CombatDamage", "CombatHealing" }
	local i
	for i = 1, table.getn(names) do
		local ok, v = pcall(GetCVar, names[i])
		if ok and v ~= nil then
			say("CVar " .. names[i] .. " = " .. tostring(v))
		end
	end
	say("DAMAGE_TEXT_FONT = " .. tostring(DAMAGE_TEXT_FONT))
	say("SHOW_COMBAT_TEXT = " .. tostring(SHOW_COMBAT_TEXT) .. "  Blizzard_CombatText geladen: " .. tostring(IsAddOnLoaded and IsAddOnLoaded("Blizzard_CombatText")) .. "  CombatText_AddMessage: " .. tostring(CombatText_AddMessage ~= nil))
	if type(AZS_HUD_CVARS) == "table" then
		local k, v
		local line = ""
		for k, v in pairs(AZS_HUD_CVARS) do
			line = line .. tostring(k) .. "=" .. tostring(v) .. "  "
		end
		say("AZS_HUD_CVARS: " .. line)
	end
	local found = {}
	local k, v
	for k, v in pairs(getfenv(0)) do
		if type(k) == "string" then
			local lk = string.lower(k)
			if (string.find(lk, "damage", 1, true) or string.find(lk, "floating", 1, true) or string.find(lk, "combattext", 1, true)
				or string.find(lk, "crit", 1, true) or string.find(lk, "hitnumber", 1, true)) and string.find(k, "^AZS") then
				found[table.getn(found) + 1] = k .. "(" .. string.sub(type(v), 1, 1) .. ")"
			end
		end
	end
	table.sort(found)
	say("AZS-Globals mit damage/floating/crit: " .. (table.getn(found) > 0 and table.concat(found, " ") or "keine"))
end

SLASH_AEGIS1 = "/aegis"
SLASH_AEGIS2 = "/aegisui"
SlashCmdList["AEGIS"] = function(msg)
	msg = string.lower(msg or "")
	local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.*)$")
	cmd = cmd or ""
	rest = rest or ""
	-- /aegis debug <tool>: all internal diagnostics in one place (the old direct names keep working)
	if cmd == "debug" then
		local _, _, c2, r2 = string.find(rest, "^(%S*)%s*(.*)$")
		if not c2 or c2 == "" then
			if DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUI debug:|r fstack, who, bars, ct, ct2, cttest, slot [n], slotparts [n], mapdiag, targetcard, fix")
			end
			return
		end
		cmd, rest = c2, r2 or ""
	end
	if cmd == "fstack" then
		UI.fstack()
	elseif cmd == "lock" then
		UI.setLocked(true)
	elseif cmd == "unlock" then
		UI.setLocked(false)
	elseif cmd == "reset" then
		UI.resetAll()
	elseif cmd == "who" then
		if AegisUI_Who then
			AegisUI_Who()
		end
	elseif cmd == "bars" then
		if AegisUI_BarsDebug then
			AegisUI_BarsDebug()
		end
	elseif cmd == "meter" or cmd == "nav" or cmd == "units" then
		-- forwarded to the module: /aegis meter log, /aegis nav next, /aegis units ...
		local handlers = { meter = "AEGISMETER", nav = "AEGISNAV", units = "AEGISUNITS" }
		local h = SlashCmdList[handlers[cmd]]
		if h then
			h(rest)
		elseif DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L("|cffd2a24aAegisUI:|r Module '") .. cmd .. L("' is not installed."))
		end
	elseif cmd == "ct" then
		combatTextDiag()
	elseif cmd == "slot" then
		-- why is an action button dark? print what the game says about each slot
		local list = { 1, 2, 3, 4, 5, 6, 12 }
		local i
		for i = 1, table.getn(list) do
			local id = list[i]
			local btn = getglobal("ActionButton" .. id)
			local icon = getglobal("ActionButton" .. id .. "Icon")
			local realId = id
			if ActionButton_GetPagedID and btn then
				realId = ActionButton_GetPagedID(btn) or id
			end
			local r, g, b = 0, 0, 0
			if icon and icon.GetVertexColor then
				r, g, b = icon:GetVertexColor()
			end
			local usable, mana = IsUsableAction(realId)
			local cs, cd = GetActionCooldown(realId)
			local tex = GetActionTexture(realId)
			local txt = "[" .. tostring(AZS_GetPhase and AZS_GetPhase()) .. "] slot " .. id .. "(" .. realId .. ") "
			txt = txt .. "tex=" .. tostring(tex and string.gsub(tex, "Interface\\Icons\\", "")) .. " usable=" .. tostring(usable) .. " nomana=" .. tostring(mana)
			txt = txt .. " cd=" .. tostring(cs) .. "/" .. tostring(cd)
			txt = txt .. " attack=" .. tostring(IsAttackAction and IsAttackAction(realId)) .. " cur=" .. tostring(IsCurrentAction and IsCurrentAction(realId))
			txt = txt .. " rgb=" .. string.format("%.2f %.2f %.2f", r or 0, g or 0, b or 0)
			if icon then
				txt = txt .. " a=" .. string.format("%.2f", icon:GetAlpha() or 0)
			end
			local cdf = getglobal("ActionButton" .. id .. "Cooldown")
			if cdf then
				txt = txt .. " cdframe=" .. tostring(cdf:IsShown())
			end
			if btn then
				txt = txt .. " btnA=" .. string.format("%.2f", btn:GetAlpha() or 0)
			end
			DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24a" .. txt .. "|r")
		end
	elseif cmd == "mapdiag" then
		local f = UI.api.fonts
		if f and f.showText and UI.api.map then
			f.showText(UI.api.map.diag())
		end
	elseif cmd == "slotparts" then
		-- every texture and child of an action button: find what darkens it
		local n = tonumber(rest) or 1
		local btn = getglobal("ActionButton" .. n)
		local out = {}
		if not btn then
			out[1] = "no ActionButton" .. n
		else
			out[table.getn(out) + 1] = "ActionButton" .. n .. " shown=" .. tostring(btn:IsShown()) .. " alpha=" .. string.format("%.2f", btn:GetAlpha()) .. " strata=" .. btn:GetFrameStrata() .. " level=" .. btn:GetFrameLevel()
			local regs = { btn:GetRegions() }
			local i
			for i = 1, table.getn(regs) do
				local r = regs[i]
				local line = "region " .. i .. " " .. r:GetObjectType() .. " " .. tostring(r:GetName())
				if r.GetTexture then
					line = line .. " tex=" .. tostring(r:GetTexture())
				end
				line = line .. " shown=" .. tostring(r:IsShown()) .. " a=" .. string.format("%.2f", r:GetAlpha())
				if r.GetVertexColor then
					local cr, cg, cb, ca = r:GetVertexColor()
					line = line .. " rgba=" .. string.format("%.2f %.2f %.2f %.2f", cr or 0, cg or 0, cb or 0, ca or 0)
				end
				out[table.getn(out) + 1] = line
			end
			local kids = { btn:GetChildren() }
			for i = 1, table.getn(kids) do
				local k = kids[i]
				out[table.getn(out) + 1] = "child " .. i .. " " .. k:GetObjectType() .. " " .. tostring(k:GetName()) .. " shown=" .. tostring(k:IsShown()) .. " a=" .. string.format("%.2f", k:GetAlpha()) .. " level=" .. k:GetFrameLevel()
			end
			out[table.getn(out) + 1] = "autorepeat=" .. tostring(IsAutoRepeatAction and IsAutoRepeatAction(ActionButton_GetPagedID and ActionButton_GetPagedID(btn) or n))
			out[table.getn(out) + 1] = "equipped=" .. tostring(IsEquippedAction and IsEquippedAction(ActionButton_GetPagedID and ActionButton_GetPagedID(btn) or n))
			out[table.getn(out) + 1] = "checked=" .. tostring(btn.GetChecked and btn:GetChecked())
		end
		A("fonts", "showText", table.concat(out, "\n"))
	elseif cmd == "targetcard" then
		if rest == "toggle" or rest == "" then
			local on = not A("units", "getTargetFade")
			A("units", "setTargetFade", on)
			DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUI:|r " .. L("Target card dimming: ") .. (on and L("on") or L("off")))
		end
	elseif cmd == "fix" then
		UI.sanitizeAll()
	elseif cmd == "cttest" then
		A("ct", "test")
	elseif cmd == "ct2" then
		if AegisUI.api.fonts and AegisUI.api.fonts.diag then
			AegisUI.api.fonts.diag()
		end
	elseif cmd == "lang" then
		AegisDB = AegisDB or {}
		if rest == "de" or rest == "en" then
			AegisDB.lang = rest
		else
			AegisDB.lang = nil
		end
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUI:|r " .. L("Language saved. Type /reload to apply."))
		end
	elseif cmd == "chat" then
		if UI.api.chat then
			if rest == "tabs" then
				UI.api.chat.debugTabs()
			elseif rest == "on" then
				UI.api.chat.setOn(true)
			elseif rest == "off" then
				UI.api.chat.setOn(false)
			else
				UI.api.chat.setOn(not UI.api.chat.isOn())
			end
		end
	elseif cmd == "profile" then
		showProfile()
	else
		toggleHub()
	end
end
