-- Skin_LuckyOdds: gives the original LuckyOdds addon the AegisUI look (no code of it is replaced).
-- LuckyOdds keeps running; this file only restyles its frames and hooks them into AegisUI
-- (lock / unlock / snap, hub toggle). Lua 5.0 / WoW 1.12.

local SOLID = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_NUM = "Fonts\\ARIALN.TTF"

local C_EDGE = { 0.14, 0.16, 0.22, 1 }
local C_GOLD = { 0.78, 0.58, 0.22, 1 }
local C_ROW = { 0.06, 0.07, 0.10, 1 }
local C_ROW_EDGE = { 0.17, 0.19, 0.25, 1 }

local RARITY = {
	{ r = 0.30, g = 0.62, b = 1.00 },
	{ r = 0.74, g = 0.40, b = 1.00 },
	{ r = 1.00, g = 0.55, b = 0.12 },
}
local HEAD = { RARE = 1, EPIC = 2, LEGEND = 3 }

-- layout constants of LuckyOdds (its own numbers)
local TOP, ROW_H, NROWS = 46, 20, 4

local done = false

local function skin()
	local f = getglobal("LuckyOddsFrame")
	if done or not f then
		return
	end
	done = true

	-- 1) hide the stock decoration textures (stripe bands, rule line)
	local regions = { f:GetRegions() }
	for i = 1, table.getn(regions) do
		local r = regions[i]
		pcall(function()
			if r:GetObjectType() == "Texture" and r:GetTexture() == SOLID then
				r:Hide()
			end
		end)
	end

	-- 2) panel look
	AegisSkin.ApplyPanel(f)

	local glow = f:CreateTexture(nil, "BACKGROUND")
	glow:SetTexture(SOLID)
	glow:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	glow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	glow:SetHeight(40)
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

	-- 3) bordered rows behind the text (textures, so the original text stays on top)
	for n = 1, NROWS do
		local y = -TOP - (n - 1) * ROW_H
		local edge = f:CreateTexture(nil, "BACKGROUND")
		edge:SetTexture(SOLID)
		edge:SetVertexColor(C_ROW_EDGE[1], C_ROW_EDGE[2], C_ROW_EDGE[3], 1)
		edge:SetPoint("TOPLEFT", f, "TOPLEFT", 6, y - 1)
		edge:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, y - 1)
		edge:SetHeight(ROW_H - 2)
		local inner = f:CreateTexture(nil, "BORDER")
		inner:SetTexture(SOLID)
		inner:SetVertexColor(C_ROW[1], C_ROW[2], C_ROW[3], 1)
		inner:SetPoint("TOPLEFT", f, "TOPLEFT", 7, y - 2)
		inner:SetPoint("TOPRIGHT", f, "TOPRIGHT", -7, y - 2)
		inner:SetHeight(ROW_H - 4)

		-- gold edge behind the row icon (15 px icon at x 12)
		local b = f:CreateTexture(nil, "BORDER")
		b:SetTexture(SOLID)
		b:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 0.7)
		b:SetWidth(17)
		b:SetHeight(17)
		b:SetPoint("LEFT", f, "TOPLEFT", 11, y - ROW_H / 2)
	end
	-- header icon (22 px at 10 / -9) gets the same edge
	local hb = f:CreateTexture(nil, "BORDER")
	hb:SetTexture(SOLID)
	hb:SetVertexColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 0.9)
	hb:SetWidth(24)
	hb:SetHeight(24)
	hb:SetPoint("TOPLEFT", f, "TOPLEFT", 9, -8)

	-- thin rule under the header
	local rule = f:CreateTexture(nil, "ARTWORK")
	rule:SetTexture(SOLID)
	rule:SetVertexColor(C_EDGE[1], C_EDGE[2], C_EDGE[3], 1)
	rule:SetHeight(1)
	rule:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(TOP - 3))
	rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -(TOP - 3))

	-- 4) fonts and colours of the original texts
	if f.luck then
		f.luck:SetFont(FONT, 12, "OUTLINE")
		f.luck:SetTextColor(1, 0.86, 0.45)
	end
	if f.level then
		f.level:SetFont(FONT_NUM, 10, "")
		f.level:SetTextColor(0.49, 0.51, 0.58)
	end
	regions = { f:GetRegions() }
	local function styleRegion(r)
		if r:GetObjectType() ~= "FontString" then
			return
		end
		local t = r:GetText()
		if t and HEAD[t] then
			local c = RARITY[HEAD[t]]
			r:SetFont(FONT, 10, "OUTLINE")
			r:SetTextColor(c.r, c.g, c.b)
		elseif t == "Spells" or t == "Rings" or t == "Trinkets" or t == "Amulets" then
			r:SetFont(FONT, 11, "OUTLINE")
			r:SetTextColor(1, 1, 1)
		end
	end
	for i = 1, table.getn(regions) do
		pcall(styleRegion, regions[i])
	end
	-- value cells: LuckyOdds recolours them on every refresh, so route that through our colours
	if f.rows then
		for r = 1, table.getn(f.rows) do
			for c = 1, 3 do
				local cell = f.rows[r].cells[c]
				local col = RARITY[c]
				local orig = cell.SetTextColor
				cell:SetFont(FONT_NUM, 12, "")
				cell.SetTextColor = function(self)
					orig(self, col.r * 0.75 + 0.25, col.g * 0.75 + 0.25, col.b * 0.75 + 0.25)
				end
			end
		end
	end

	-- 5) the two marker toggles in the corner: square, thin edge
	local kids = { f:GetChildren() }
	for i = 1, table.getn(kids) do
		local k = kids[i]
		if pcall(function() return k:GetObjectType() end) and k:GetObjectType() == "Button" then
			k:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
				insets = { left = 1, right = 1, top = 1, bottom = 1 } })
			k:SetBackdropColor(0.03, 0.035, 0.05, 1)
			k:SetBackdropBorderColor(C_GOLD[1], C_GOLD[2], C_GOLD[3], 0.7)
		end
	end

	-- 6) dragging respects AegisUI lock and snap; the position is stored the way LuckyOdds expects
	f:SetScript("OnDragStart", function()
		if AegisUI and AegisUI.locked then
			return
		end
		this:StartMoving()
	end)
	f:SetScript("OnDragStop", function()
		if AegisUI and AegisUI.locked then
			return
		end
		this:StopMovingOrSizing()
		if AegisUI and AegisUI.snapFrame then
			AegisUI.snapFrame(this)
		end
		local p, _, rp, x, y = this:GetPoint()
		if type(LuckyOddsDB) == "table" and p then
			LuckyOddsDB.point = { p, rp, x, y }
		end
	end)

	-- 8) hook into AegisUI: registered window (lock / snap) + hub toggle
	if AegisUI then
		AegisUI.register("luck", "Luck window (LuckyOdds)", f, function()
			if type(LuckyOddsDB) == "table" then
				LuckyOddsDB.point = nil
			end
			f:ClearAllPoints()
			f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -230, -260)
		end)
		AegisUI.api.luck = {
			isShown = function()
				return type(LuckyOddsDB) == "table" and LuckyOddsDB.shown and true or false
			end,
			setShown = function(v)
				if type(LuckyOddsDB) == "table" then
					LuckyOddsDB.shown = v and true or false
				end
			end,
		}
	end
end

AegisSkin.RegisterSkin("LuckyOdds", "LuckyOdds (odds panel)", skin, true)
