-- AegisMap: square minimap with a black border (toggle in the hub). WoW 1.12 / Lua 5.0.

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

local mapEv = CreateFrame("Frame")
mapEv:RegisterEvent("PLAYER_LOGIN")
mapEv:SetScript("OnEvent", function()
	AegisDB = AegisDB or {}
	if AegisDB.square ~= nil then
		MAPSQ.on = AegisDB.square
	end
	pcall(applyMap)
end)

if AegisUI then
	AegisUI.api.map = {
		getSquare = function()
			return MAPSQ.on
		end,
		setSquare = function(v)
			MAPSQ.on = v and true or false
			AegisDB = AegisDB or {}
			AegisDB.square = MAPSQ.on
			pcall(applyMap)
		end,
	}
end
