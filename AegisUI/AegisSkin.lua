-- AegisSkin: modular skin engine for third-party addons (WoW 1.12 / Lua 5.0).
-- A skin is a function that restyles another addon's frames. Register it once, the engine runs
-- it as soon as that addon is loaded, guards it with pcall and lists it in the hub (tab "Skins").
--
--   AegisSkin.RegisterSkin("AddonFolderName", "Label in the hub", function() ... end, true)
--
-- Helpers for a uniform look: ApplyPanel, ApplyRow, SkinIcon, GoldLine, StyleText.

local L = AegisL.t

AegisSkin = AegisSkin or {}
AegisSkin.registry = {}   -- [addonName] = { label, skinFn, default }
AegisSkin.order = {}      -- registration order (stable list in the hub)
AegisSkin.applied = {}    -- [addonName] = true once the skin function ran

local SOLID = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_NUM = "Fonts\\ARIALN.TTF"

AegisSkin.color = {
	panel = { 0.04, 0.05, 0.08, 0.96 },
	edge = { 0.14, 0.16, 0.22, 1 },
	row = { 0.06, 0.07, 0.10, 1 },
	rowEdge = { 0.17, 0.19, 0.25, 1 },
	gold = { 0.78, 0.58, 0.22, 1 },
	dim = { 0.49, 0.51, 0.58, 1 },
}

-- Size of one physical screen pixel in UI units. In 1.12 the UI is 768 units high at scale 1,
-- so 1 px = 768 / screenHeight / UIParent scale. Needs gxResolution ("1920x1080").
function AegisSkin.px()
	if AegisDB and AegisDB.pixel == false then
		return 1
	end
	if AegisSkin.pxCache then
		return AegisSkin.pxCache
	end
	local h = 0
	if GetCVar then
		local res = GetCVar("gxResolution")
		if res then
			local _, _, _, hh = string.find(res, "(%d+)x(%d+)")
			h = tonumber(hh) or 0
		end
	end
	local es = 1
	if UIParent and UIParent.GetEffectiveScale then
		es = UIParent:GetEffectiveScale() or 1
	end
	if h < 480 or es <= 0 then
		return 1
	end
	local v = 768 / h / es
	if v < 0.4 then
		v = 0.4
	elseif v > 2 then
		v = 2
	end
	if AegisSkin.loggedIn then
		AegisSkin.pxCache = v
	end
	return v
end

function AegisSkin.RegisterSkin(addonName, label, skinFn, defaultState)
	if not AegisSkin.registry[addonName] then
		AegisSkin.order[table.getn(AegisSkin.order) + 1] = addonName
	end
	AegisSkin.registry[addonName] = {
		label = label or addonName,
		skinFn = skinFn,
		default = (defaultState == nil) or defaultState,
	}
end

-- dark panel with a 1 px border
function AegisSkin.ApplyPanel(frame)
	if not frame or not frame.SetBackdrop then
		return
	end
	local c, e = AegisSkin.color.panel, AegisSkin.color.edge
	frame:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, tileSize = 0, edgeSize = AegisSkin.px(),
		insets = { left = AegisSkin.px(), right = AegisSkin.px(), top = AegisSkin.px(), bottom = AegisSkin.px() } })
	frame:SetBackdropColor(c[1], c[2], c[3], c[4])
	frame:SetBackdropBorderColor(e[1], e[2], e[3], e[4])
end

-- neutral near-black, 96 % opaque: for panels that sit over bright zones (snow, desert)
AegisSkin.color.solid = { 0.04, 0.04, 0.04, 0.96 }

-- Look settings (global, in AegisDB.look): background opacity %, border opacity %, black outline.
-- Panels register with TrackPanel and follow the settings live.
AegisSkin.tracked = {}
local LOOK_DEFAULT = { bg = 96, edge = 100, outer = true }

function AegisSkin.GetLook()
	local d = AegisDB and AegisDB.look
	return (d and d.bg) or LOOK_DEFAULT.bg, (d and d.edge) or LOOK_DEFAULT.edge, not (d and d.outer == false)
end

-- frame, background rgb, border rgb, optional list of outline textures
function AegisSkin.TrackPanel(frame, bgc, edgec, outerTex)
	local i
	for i = 1, table.getn(AegisSkin.tracked) do
		if AegisSkin.tracked[i].f == frame then
			return
		end
	end
	AegisSkin.tracked[table.getn(AegisSkin.tracked) + 1] = { f = frame, bg = bgc, edge = edgec, outer = outerTex }
	AegisSkin.RefreshLook()
end

function AegisSkin.RefreshLook()
	local bg, edge, outer = AegisSkin.GetLook()
	local i, j
	for i = 1, table.getn(AegisSkin.tracked) do
		local t = AegisSkin.tracked[i]
		pcall(function()
			t.f:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], bg / 100)
			t.f:SetBackdropBorderColor(t.edge[1], t.edge[2], t.edge[3], edge / 100)
			local list = t.outer or t.f.aegisOuterTex
			if list then
				for j = 1, table.getn(list) do
					if outer then
						list[j]:Show()
					else
						list[j]:Hide()
					end
				end
			end
		end)
	end
end

function AegisSkin.SetLook(key, value)
	AegisDB = AegisDB or {}
	AegisDB.look = AegisDB.look or {}
	AegisDB.look[key] = value
	AegisSkin.RefreshLook()
end

function AegisSkin.ResetLook()
	if AegisDB then
		AegisDB.look = nil
	end
	AegisSkin.RefreshLook()
end

function AegisSkin.ApplySolid(frame)
	AegisSkin.ApplyPanel(frame)
	local c = AegisSkin.color.solid
	frame:SetBackdropColor(c[1], c[2], c[3], c[4])
	AegisSkin.TrackPanel(frame, c, AegisSkin.color.edge)
end

-- 1 px black outline OUTSIDE the panel edge (sharpens the dark-gold border on bright ground).
-- Four textures on the panel itself, so they follow its strata/level automatically.
function AegisSkin.OuterBlack(frame)
	if not frame or frame.aegisOuter then
		return
	end
	frame.aegisOuter = true
	frame.aegisOuterTex = {}
	local p = AegisSkin.px()
	local function bar(p1, x1, y1, p2, x2, y2)
		local t = frame:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(SOLID)
		t:SetVertexColor(0, 0, 0, 1)
		t:SetPoint(p1, frame, p1, x1, y1)
		t:SetPoint(p2, frame, p2, x2, y2)
		frame.aegisOuterTex[table.getn(frame.aegisOuterTex) + 1] = t
	end
	bar("TOPLEFT", -p, p, "TOPRIGHT", p, 0)
	bar("BOTTOMLEFT", -p, 0, "BOTTOMRIGHT", p, -p)
	bar("TOPLEFT", -p, 0, "BOTTOMLEFT", 0, 0)
	bar("TOPRIGHT", 0, 0, "BOTTOMRIGHT", p, 0)
end

-- darker bordered row / button
function AegisSkin.ApplyRow(frame)
	if not frame or not frame.SetBackdrop then
		return
	end
	local c, e = AegisSkin.color.row, AegisSkin.color.rowEdge
	frame:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, tileSize = 0, edgeSize = AegisSkin.px(),
		insets = { left = AegisSkin.px(), right = AegisSkin.px(), top = AegisSkin.px(), bottom = AegisSkin.px() } })
	frame:SetBackdropColor(c[1], c[2], c[3], c[4])
	frame:SetBackdropBorderColor(e[1], e[2], e[3], e[4])
end

-- crop the icon border the game bakes into icon textures
function AegisSkin.SkinIcon(texture)
	if not texture or not texture.SetTexCoord then
		return
	end
	texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

-- 1 px gold line along the top edge of a frame
function AegisSkin.GoldLine(frame)
	local g = AegisSkin.color.gold
	local t = frame:CreateTexture(nil, "OVERLAY")
	t:SetTexture(SOLID)
	t:SetVertexColor(g[1], g[2], g[3], 1)
	local p = AegisSkin.px()
	t:SetHeight(p)
	t:SetPoint("TOPLEFT", frame, "TOPLEFT", p, -p)
	t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -p, -p)
	return t
end

-- fontString: kind "text" (outlined) or "num" (numbers)
function AegisSkin.StyleText(fs, kind, size, r, g, b)
	if not fs or not fs.SetFont then
		return
	end
	if kind == "num" then
		fs:SetFont(FONT_NUM, size or 12, "")
	else
		fs:SetFont(FONT, size or 11, "OUTLINE")
	end
	if r then
		fs:SetTextColor(r, g, b)
	end
end

function AegisSkin.IsEnabled(addonName)
	AegisDB = AegisDB or {}
	local s = AegisDB.skins
	if s and s[addonName] ~= nil then
		return s[addonName]
	end
	local d = AegisSkin.registry[addonName]
	return d == nil or d.default
end

function AegisSkin.SetEnabled(addonName, on)
	AegisDB = AegisDB or {}
	AegisDB.skins = AegisDB.skins or {}
	AegisDB.skins[addonName] = on and true or false
	if on then
		AegisSkin.ApplySkin(addonName)
	end
end

-- run one skin, protected; errors go to the chat instead of an error dialog
function AegisSkin.ApplySkin(addonName)
	local skinData = AegisSkin.registry[addonName]
	if not skinData or not skinData.skinFn or AegisSkin.applied[addonName] then
		return
	end
	if not AegisSkin.IsEnabled(addonName) then
		return
	end
	if IsAddOnLoaded and not IsAddOnLoaded(addonName) then
		return
	end
	AegisSkin.applied[addonName] = true
	local ok, err = pcall(skinData.skinFn)
	if not ok and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[AegisSkin - " .. addonName .. "]:|r " .. tostring(err))
	end
end

function AegisSkin.IsLoaded(addonName)
	return IsAddOnLoaded and IsAddOnLoaded(addonName) and true or false
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
	local i
	for i = 1, table.getn(AegisSkin.order) do
		AegisSkin.ApplySkin(AegisSkin.order[i])
	end
end)


-- Generic skin (experimental, opt-in per addon) --------------------------------------------
-- Finds loaded third-party addons and can restyle their main frame: dark panel, gold line,
-- cropped spell icons, Aegis fonts. It only guesses the main frame by name, so it is OFF by default.

local SKIP = { AegisUI = true, AegisMeter = true, AegisNav = true, AegisUnits = true }
AegisSkin.discovered = nil

function AegisSkin.Discover()
	if AegisSkin.discovered then
		return AegisSkin.discovered
	end
	local list = {}
	local n = 0
	if GetNumAddOns then
		n = GetNumAddOns()
	end
	local i
	for i = 1, n do
		local name, title = GetAddOnInfo(i)
		if name and not SKIP[name] and not string.find(name, "^Blizzard_") and not AegisSkin.registry[name]
			and IsAddOnLoaded and IsAddOnLoaded(name) then
			list[table.getn(list) + 1] = { name = name, title = title or name }
		end
	end
	AegisSkin.discovered = list
	return list
end

local function findMainFrame(addon)
	local tries = { addon, addon .. "Frame", addon .. "_Frame", addon .. "MainFrame", addon .. "_MainFrame", addon .. "Main", addon .. "_Main" }
	local i
	for i = 1, table.getn(tries) do
		local f = getglobal(tries[i])
		if type(f) == "table" and f.GetObjectType and f.SetBackdrop then
			return f
		end
	end
	return nil
end

local function restyleRegions(frame)
	-- re-fetch after SetBackdrop (older handles go stale) and guard every call
	local regs = { frame:GetRegions() }
	local i
	for i = 1, table.getn(regs) do
		local r = regs[i]
		pcall(function()
			local ot = r:GetObjectType()
			if ot == "FontString" then
				local _, size = r:GetFont()
				local txt = r:GetText() or ""
				if string.find(txt, "^[%d%.,%s%%/:%-+]+$") and txt ~= "" then
					r:SetFont(FONT_NUM, size or 11, "")
				else
					r:SetFont(FONT, size or 11, "OUTLINE")
				end
			elseif ot == "Texture" then
				local path = r:GetTexture()
				if type(path) == "string" then
					if string.find(path, "Interface\\Icons", 1, true) then
						AegisSkin.SkinIcon(r)
					elseif string.find(path, "TrackingBorder", 1, true) then
						r:Hide()
					end
				end
			end
		end)
	end
end

local function walk(frame, depth)
	pcall(restyleRegions, frame)
	if depth <= 0 then
		return
	end
	local kids = { frame:GetChildren() }
	local i
	for i = 1, table.getn(kids) do
		pcall(walk, kids[i], depth - 1)
	end
end

function AegisSkin.SkinGenericFrame(frame)
	if not frame or frame.aegisGeneric then
		return false
	end
	frame.aegisGeneric = true
	AegisSkin.ApplyPanel(frame)
	local ok = pcall(AegisSkin.GoldLine, frame)
	walk(frame, 3)
	return true
end

function AegisSkin.GenericEnabled(addon)
	return AegisDB and AegisDB.generic and AegisDB.generic[addon] and true or false
end

function AegisSkin.SetGeneric(addon, on)
	AegisDB = AegisDB or {}
	AegisDB.generic = AegisDB.generic or {}
	AegisDB.generic[addon] = on and true or nil
	if on then
		local f = findMainFrame(addon)
		if f then
			pcall(AegisSkin.SkinGenericFrame, f)
		elseif DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L("|cffd2a24aAegisSkin:|r No main window found for '") .. addon .. L("' (tried: ") .. addon .. ", " .. addon .. "Frame ...).")
		end
	end
end

-- one scan at login, then restyle the addons the user switched on
local gen = CreateFrame("Frame")
gen:RegisterEvent("PLAYER_LOGIN")
gen:SetScript("OnEvent", function()
	AegisSkin.loggedIn = true
	AegisSkin.pxCache = nil
	AegisSkin.RefreshLook()
	AegisSkin.Discover()
	if AegisDB and AegisDB.generic then
		local name, on
		for name, on in pairs(AegisDB.generic) do
			if on then
				local f = findMainFrame(name)
				if f then
					pcall(AegisSkin.SkinGenericFrame, f)
				end
			end
		end
	end
end)
