-- AegisMap: square minimap with a black border (toggle in the hub). WoW 1.12 / Lua 5.0.

local L = AegisL.t

local SOLID = "Interface\\Buttons\\WHITE8X8"

-- Square minimap with a black border -----------------------------------------

local MAPSQ = { on = true, built = false }
AegisUISquare = function()
	return MAPSQ.on
end

local function buildBorder()
	if MAPSQ.built then
		return
	end
	MAPSQ.built = true
	local fr = CreateFrame("Frame", nil, Minimap)
	fr:SetFrameLevel(Minimap:GetFrameLevel() + 3)
	fr:EnableMouse(false)
	local function edge(p1, x1, y1, p2, x2, y2, w, h)
		local t = fr:CreateTexture(nil, "OVERLAY")
		t:SetTexture(SOLID)
		t:SetVertexColor(0, 0, 0, 1)
		t:SetPoint(p1, Minimap, p1, x1, y1)
		t:SetPoint(p2, Minimap, p2, x2, y2)
		if w then
			t:SetWidth(w)
		end
		if h then
			t:SetHeight(h)
		end
	end
	edge("TOPLEFT", -2, 2, "TOPRIGHT", 2, 2, nil, 2)
	edge("BOTTOMLEFT", -2, -2, "BOTTOMRIGHT", 2, -2, nil, 2)
	edge("TOPLEFT", -2, 2, "BOTTOMLEFT", -2, -2, 2, nil)
	edge("TOPRIGHT", 2, 2, "BOTTOMRIGHT", 2, -2, 2, nil)
	MAPSQ.frame = fr
end

local function applyMap()
	if not Minimap then
		return
	end
	if MAPSQ.on then
		buildBorder()
		Minimap:SetMaskTexture(SOLID)
		MAPSQ.frame:Show()
		GetMinimapShape = function()
			return "SQUARE"
		end
	else
		Minimap:SetMaskTexture("Textures\\MinimapMask")
		if MAPSQ.frame then
			MAPSQ.frame:Hide()
		end
		GetMinimapShape = nil
	end
	local names = { "MinimapBorder", "MinimapBorderTop" }
	local i
	for i = 1, table.getn(names) do
		local o = getglobal(names[i])
		if o and o.Hide then
			if MAPSQ.on then
				o:Hide()
			else
				o:Show()
			end
		end
	end
	if AegisUIPlaceButton then
		AegisUIPlaceButton()
	end
end

-- Clean minimap: no zoom buttons (the mouse wheel zooms), zone name in the Aegis font
local function applyClean()
	if not Minimap then
		return
	end
	local on = not (AegisDB and AegisDB.mapClean == false)
	local names = {}
	local i
	for i = 1, table.getn(names) do
		local b = getglobal(names[i])
		if b then
			if on then
				b:Hide()
			else
				b:Show()
			end
		end
	end
	if on then
		Minimap:EnableMouseWheel(true)
		Minimap:SetScript("OnMouseWheel", function()
			local z = Minimap:GetZoom()
			if arg1 > 0 and z < Minimap:GetZoomLevels() - 1 then
				Minimap:SetZoom(z + 1)
			elseif arg1 < 0 and z > 0 then
				Minimap:SetZoom(z - 1)
			end
		end)
		local zt = getglobal("MinimapZoneText")
		if zt and zt.SetFont then
			zt:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
		end
	end
end


-- Flat minimap buttons: strip the round gold rings, give every button a small square dark frame with a gold
-- edge and sit them on the edge of the square map (same angle as before). Hidden: close X, world map
-- button, calendar sun, zoom buttons (the wheel zooms).
local GOLD = { 0.78, 0.58, 0.22 }
local HIDE_NAMES = { "MinimapToggleButton", "MiniMapWorldMapButton", "GameTimeFrame" }
local STOCK = { "MiniMapTracking", "MiniMapBattlefieldFrame", "MiniMapMailFrame", "MiniMapMeetingStoneFrame", "MiniMapPing" }

local function isRing(tex)
	if not tex or type(tex) ~= "string" then
		return false
	end
	local t = string.lower(tex)
	return string.find(t, "border", 1, true) or string.find(t, "minimap-background", 1, true) or string.find(t, "ring", 1, true) or string.find(t, "trackingborder", 1, true)
end

local function flatten(b, half, needRing)
	if b.aegisFlat or b:GetName() == "AegisHubMinimapButton" or b == Minimap then
		return
	end
	local w, h = b:GetWidth(), b:GetHeight()
	if not w or not h or w < 8 or h < 8 or w > 50 or h > 50 then
		return
	end
	local icon
	local regs = { b:GetRegions() }
	local i
	if needRing then
		local has = false
		for i = 1, table.getn(regs) do
			local r = regs[i]
			if r.GetObjectType and r:GetObjectType() == "Texture" and isRing(r:GetTexture()) then
				has = true
			end
		end
		if not has then
			return
		end
	end
	b.aegisFlat = true
	-- the real icon is the texture from Interface\Icons (else the first one that is not a ring / highlight)
	for i = 1, table.getn(regs) do
		local r = regs[i]
		if r.GetObjectType and r:GetObjectType() == "Texture" then
			local tex = r:GetTexture()
			if tex and type(tex) == "string" and string.find(string.lower(tex), "\\icons\\", 1, true) then
				icon = r
			end
		end
	end
	for i = 1, table.getn(regs) do
		local r = regs[i]
		if r.GetObjectType and r:GetObjectType() == "Texture" then
			local tex = r:GetTexture()
			if r ~= icon then
				if isRing(tex) or (icon and tex) then
					if not (tex and string.find(string.lower(tex), "highlight", 1, true)) then
						r:SetTexture(nil)
						r:Hide()
					end
				elseif tex and not icon and not string.find(string.lower(tex), "highlight", 1, true) then
					icon = r
				end
			end
		end
	end
	local bg = CreateFrame("Frame", nil, b)
	local lv = b:GetFrameLevel() - 1
	if lv < 0 then
		lv = 0
	end
	bg:SetFrameLevel(lv)
	if icon then
		bg:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
		bg:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	else
		bg:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
		bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)
	end
	bg:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	bg:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
	bg:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
	-- move onto the square's edge, keeping the direction
	local bx, by = b:GetCenter()
	local mx, my = Minimap:GetCenter()
	if bx and mx and AegisUISquare and AegisUISquare() and b:GetName() ~= "AZSStatsMinimapButton" then
		local bs, ms = b:GetEffectiveScale(), Minimap:GetEffectiveScale()
		local dx, dy = (bx * bs - mx * ms) / ms, (by * bs - my * ms) / ms
		local m = math.max(math.abs(dx), math.abs(dy))
		if m > 1 then
			local k = (half + 8) / m
			b:ClearAllPoints()
			b:SetPoint("CENTER", Minimap, "CENTER", dx * k, dy * k)
		end
	end
end


-- zoom buttons: small flat squares with + / - in the map's bottom-right corner
local function flatZoom(name, text, y)
	local b = getglobal(name)
	if not b or b.aegisFlat then
		return
	end
	b.aegisFlat = true
	local regs = { b:GetRegions() }
	local i
	for i = 1, table.getn(regs) do
		if regs[i].Hide then
			regs[i]:Hide()
		end
	end
	if b.SetNormalTexture then
		b:SetNormalTexture(nil)
		b:SetPushedTexture(nil)
		b:SetDisabledTexture(nil)
		b:SetHighlightTexture(nil)
	end
	b:SetWidth(16)
	b:SetHeight(16)
	b:ClearAllPoints()
	b:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -4, y)
	b:SetFrameLevel(Minimap:GetFrameLevel() + 6)
	b:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	b:SetBackdropColor(0.04, 0.04, 0.04, 0.9)
	b:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
	local fs = b:CreateFontString(nil, "OVERLAY")
	fs:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE")
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	fs:SetText(text)
	fs:SetTextColor(1, 0.86, 0.45)
end

-- AZSStats' own button only knows a circle. Take over its dragging: it slides along the square's edge
-- (angle saved in AegisDB.azsAngle); Shift + drag places it freely (AegisDB.azsFree).
local function azsPlace(b)
	b:ClearAllPoints()
	if AegisDB and AegisDB.azsFree then
		b:SetPoint("CENTER", UIParent, "BOTTOMLEFT", AegisDB.azsFree[1], AegisDB.azsFree[2])
		return
	end
	local a = math.rad((AegisDB and AegisDB.azsAngle) or 268)
	local x, y = math.cos(a), math.sin(a)
	local r = 80
	if AegisUISquare and AegisUISquare() then
		local m = math.max(math.abs(x), math.abs(y))
		x, y = x / m, y / m
		r = (Minimap:GetWidth() or 140) / 2 + 8
	end
	b:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

local function azsTake()
	local b = getglobal("AZSStatsMinimapButton")
	if not b or b.aegisTaken then
		return
	end
	b.aegisTaken = true
	azsPlace(b)
	b:SetScript("OnUpdate", function()
		if not this.down then
			return
		end
		local cx, cy = GetCursorPosition()
		local us = UIParent:GetEffectiveScale()
		if not this.dragging then
			if math.abs(cx / us - (this.downX or 0)) + math.abs(cy / us - (this.downY or 0)) < 6 then
				return
			end
			this.dragging = true
			GameTooltip:Hide()
		end
		AegisDB = AegisDB or {}
		if IsShiftKeyDown() then
			AegisDB.azsFree = { cx / us, cy / us }
		else
			local ms = Minimap:GetEffectiveScale()
			local mx, my = Minimap:GetCenter()
			if mx then
				AegisDB.azsFree = nil
				AegisDB.azsAngle = math.deg(math.atan2(cy / ms - my, cx / ms - mx))
			end
		end
		azsPlace(this)
	end)
end

local function flattenAll()
	if not Minimap or not (AegisDB and AegisDB.mapClean ~= false) then
		return
	end
	local half = (Minimap:GetWidth() or 140) / 2
	local i
	for i = 1, table.getn(HIDE_NAMES) do
		local o = getglobal(HIDE_NAMES[i])
		if o and o.Hide then
			o:Hide()
			if o.Show and not o.aegisNoShow then
				o.aegisNoShow = true
				o.Show = function() end
			end
		end
	end
	local lists = { { Minimap:GetChildren() } }
	local par = Minimap:GetParent()
	if par and par ~= UIParent then
		lists[2] = { par:GetChildren() }
	end
	local j
	for j = 1, table.getn(lists) do
		for i = 1, table.getn(lists[j]) do
			pcall(flatten, lists[j][i], half)
		end
	end
	pcall(azsTake)
	pcall(flatZoom, "MinimapZoomIn", "+", 22)
	pcall(flatZoom, "MinimapZoomOut", "-", 4)
	-- round buttons that other addons parent to UIParent but park around the map
	local mL, mB, mR, mT = Minimap:GetLeft(), Minimap:GetBottom(), Minimap:GetRight(), Minimap:GetTop()
	if mL and mB and mR and mT then
		local ui = { UIParent:GetChildren() }
		for i = 1, table.getn(ui) do
			local o = ui[i]
			local cx, cy = o:GetCenter()
			if cx and cy and o ~= Minimap and not o.aegisFlat and cx > mL - 50 and cx < mR + 50 and cy > mB - 50 and cy < mT + 50 then
				pcall(flatten, o, half, true)
			end
		end
	end
	for i = 1, table.getn(STOCK) do
		local o = getglobal(STOCK[i])
		if o and o.GetRegions then
			pcall(flatten, o, half)
		end
	end
end

-- list the minimap's children (for /aegis mapdiag)
local function mapDiag()
	local out = {}
	local function dump(f, tag)
		local kids = { f:GetChildren() }
		local i
		for i = 1, table.getn(kids) do
			local k = kids[i]
			out[table.getn(out) + 1] = tag .. " " .. tostring(k:GetName()) .. " " .. k:GetObjectType() .. " " .. math.floor((k:GetWidth() or 0) + 0.5) .. "x" .. math.floor((k:GetHeight() or 0) + 0.5) .. " shown=" .. tostring(k:IsShown()) .. " flat=" .. tostring(k.aegisFlat)
		end
	end
	if Minimap then
		dump(Minimap, "Minimap>")
		local par = Minimap:GetParent()
		if par then
			out[table.getn(out) + 1] = "parent=" .. tostring(par:GetName())
			dump(par, "parent>")
		end
	end
	local names = { "LuckyOddsMinimapButton", "AZSStatsMinimapButton" }
	local n
	for n = 1, table.getn(names) do
		local b = getglobal(names[n])
		if b then
			local regs = { b:GetRegions() }
			local i
			for i = 1, table.getn(regs) do
				local r = regs[i]
				out[table.getn(out) + 1] = names[n] .. " region " .. i .. " " .. r:GetObjectType() .. " tex=" .. tostring(r.GetTexture and r:GetTexture()) .. " shown=" .. tostring(r:IsShown())
			end
			local kids = { b:GetChildren() }
			for i = 1, table.getn(kids) do
				out[table.getn(out) + 1] = names[n] .. " child " .. i .. " " .. tostring(kids[i]:GetName()) .. " " .. kids[i]:GetObjectType()
			end
		end
	end
	return table.concat(out, "\n")
end

local mapEv = CreateFrame("Frame")
mapEv:RegisterEvent("PLAYER_LOGIN")
mapEv:SetScript("OnEvent", function()
	AegisDB = AegisDB or {}
	if AegisDB.square ~= nil then
		MAPSQ.on = AegisDB.square
	end
	pcall(applyMap)
	pcall(applyClean)
	if AegisDB.mapScale and MinimapCluster then
		MinimapCluster:SetScale(AegisDB.mapScale)
	end
	-- other addons add their minimap buttons a little later
	local t = 0
	local done = 0
	local f = CreateFrame("Frame")
	f:SetScript("OnUpdate", function()
		t = t + (arg1 or 0)
		if t > 2 and done == 0 then
			done = 1
			pcall(flattenAll)
		elseif t > 6 and done == 1 then
			done = 2
			pcall(flattenAll)
			this:SetScript("OnUpdate", nil)
		end
	end)
end)

if AegisUI then
	AegisUI.api.map = {
		diag = mapDiag,
		getScale = function()
			return (AegisDB and AegisDB.mapScale) or 1
		end,
		setScale = function(v)
			AegisDB = AegisDB or {}
			AegisDB.mapScale = v
			if MinimapCluster then
				MinimapCluster:SetScale(v)
			end
			if AegisUIPlaceButton then
				AegisUIPlaceButton()
			end
		end,
		getSquare = function()
			return MAPSQ.on
		end,
		getClean = function()
			return not (AegisDB and AegisDB.mapClean == false)
		end,
		setClean = function(v)
			AegisDB = AegisDB or {}
			AegisDB.mapClean = v and true or false
			pcall(applyClean)
			pcall(flattenAll)
			if not v and DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage(L("|cffd2a24aAegisUI:|r The zone name font returns after /reload."))
			end
		end,
		setSquare = function(v)
			MAPSQ.on = v and true or false
			AegisDB = AegisDB or {}
			AegisDB.square = MAPSQ.on
			pcall(applyMap)
		end,
	}
end
