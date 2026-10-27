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
	local on = AegisDB and AegisDB.mapClean
	local names = { "MinimapZoomIn", "MinimapZoomOut" }
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

local mapEv = CreateFrame("Frame")
mapEv:RegisterEvent("PLAYER_LOGIN")
mapEv:SetScript("OnEvent", function()
	AegisDB = AegisDB or {}
	if AegisDB.square ~= nil then
		MAPSQ.on = AegisDB.square
	end
	pcall(applyMap)
	pcall(applyClean)
end)

if AegisUI then
	AegisUI.api.map = {
		getSquare = function()
			return MAPSQ.on
		end,
		getClean = function()
			return AegisDB and AegisDB.mapClean and true or false
		end,
		setClean = function(v)
			AegisDB = AegisDB or {}
			AegisDB.mapClean = v and true or false
			pcall(applyClean)
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
