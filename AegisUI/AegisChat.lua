-- AegisChat: restyles ChatFrame1 in the Aegis look (WoW 1.12 / Lua 5.0).
-- Dark panel behind the chat, transparent chat background, no scroll buttons, mouse-wheel
-- scrolling (Shift = page, Ctrl = top/bottom), square edit box below the chat with a gold border
-- while typing. Switch it on/off in the hub (module tab) or with /aegis chat; "off" needs /reload.

local L = AegisL.t

local SOLID = "Interface\\Buttons\\WHITE8X8"
local panel, built

local function enabled()
	return not (AegisDB and AegisDB.chat == false)
end

local function quiet(fn)
	pcall(fn)
end

local function build()
	if built or not enabled() then
		return
	end
	local cf = ChatFrame1
	if not cf or not AegisSkin then
		return
	end
	built = true

	panel = CreateFrame("Frame", "AegisChatPanel", UIParent)
	panel:EnableMouse(false)
	panel:SetPoint("TOPLEFT", cf, "TOPLEFT", -4, 4)
	panel:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 4, -4)
	AegisSkin.ApplySolid(panel, "chat")
	AegisSkin.OuterBlack(panel)
	AegisSkin.GoldLine(panel)

	-- transparent chat frame so the text sits on our panel
	quiet(function()
		cf:SetBackdropColor(0, 0, 0, 0)
		cf:SetBackdropBorderColor(0, 0, 0, 0)
	end)
	quiet(function()
		local bg = getglobal("ChatFrame1Background")
		if bg then
			bg:SetAlpha(0)
			bg:Hide()
		end
	end)

	-- stock scroll / menu buttons off (they would re-show themselves, so hide again on show)
	local names = { "ChatFrame1UpButton", "ChatFrame1DownButton", "ChatFrame1BottomButton", "ChatFrameMenuButton" }
	local i
	for i = 1, table.getn(names) do
		quiet(function()
			local b = getglobal(names[i])
			if b then
				b:SetScript("OnShow", function()
					this:Hide()
				end)
				b:Hide()
			end
		end)
	end

	-- mouse wheel
	quiet(function()
		cf:EnableMouseWheel(true)
		cf:SetScript("OnMouseWheel", function()
			local up = arg1 and arg1 > 0
			if IsControlKeyDown and IsControlKeyDown() then
				if up then
					this:ScrollToTop()
				else
					this:ScrollToBottom()
				end
			elseif IsShiftKeyDown and IsShiftKeyDown() then
				if up then
					this:PageUp()
				else
					this:PageDown()
				end
			else
				if up then
					this:ScrollUp()
					this:ScrollUp()
				else
					this:ScrollDown()
					this:ScrollDown()
				end
			end
		end)
	end)

	-- edit box right under the chat
	quiet(function()
		local eb = ChatFrameEditBox
		if not eb then
			return
		end
		eb:ClearAllPoints()
		eb:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", -4, -8)
		eb:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", 4, -8)
		eb:SetHeight(22)
		local parts = { "ChatFrameEditBoxLeft", "ChatFrameEditBoxMid", "ChatFrameEditBoxRight",
			"ChatFrameEditBoxFocusLeft", "ChatFrameEditBoxFocusMid", "ChatFrameEditBoxFocusRight" }
		local function stripArt()
			local k
			for k = 1, table.getn(parts) do
				quiet(function()
					local t = getglobal(parts[k])
					if t then
						t:SetAlpha(0)
						t:Hide()
					end
				end)
			end
		end
		stripArt()
		AegisSkin.ApplyRow(eb)
		local oldIn = eb:GetScript("OnEditFocusGained")
		local oldOut = eb:GetScript("OnEditFocusLost")
		eb:SetScript("OnEditFocusGained", function()
			if oldIn then
				oldIn()
			end
			stripArt()
			local g = AegisSkin.color.gold
			this:SetBackdropBorderColor(g[1], g[2], g[3], 1)
		end)
		eb:SetScript("OnEditFocusLost", function()
			if oldOut then
				oldOut()
			end
			local e = AegisSkin.color.rowEdge
			this:SetBackdropBorderColor(e[1], e[2], e[3], 1)
		end)
	end)
end

-- chat tabs (General, Combat Log, ...): flat dark tabs, gold text + gold underline when selected.
-- The game keeps re-showing its tab art, so a slow ticker hides it again and refreshes the state.
-- The panel must always sit BELOW the chat text: same strata as the chat frame, one level lower
-- (a panel above the chat would hide every message). Re-checked by the ticker because the game
-- raises chat frames when you click them.
local function syncPanel()
	if not panel or not ChatFrame1 then
		return
	end
	quiet(function()
		local cf = ChatFrame1
		panel:SetFrameStrata(cf:GetFrameStrata())
		local lvl = cf:GetFrameLevel() or 1
		if lvl < 1 then
			cf:SetFrameLevel(1)
			lvl = 1
		end
		panel:SetFrameLevel(lvl - 1)
	end)
end

-- Chat size: +50 x +60 px on first start, then freely resizable with the gold grip (top-right, unlocked only)
local grip
local CHAT_MIN_W, CHAT_MIN_H = 220, 90

local function applyChatSize()
	local cf = ChatFrame1
	if not cf or not (AegisDB and AegisDB.chatW and AegisDB.chatH) then
		return
	end
	cf:SetWidth(AegisDB.chatW)
	cf:SetHeight(AegisDB.chatH)
end

local function bootChatSize()
	local cf = ChatFrame1
	if not cf then
		return
	end
	AegisDB = AegisDB or {}
	if not AegisDB.chatH then
		AegisDB.chatW = math.floor((cf:GetWidth() or 320) + 50 + 0.5)
		AegisDB.chatH = math.floor((cf:GetHeight() or 120) + 60 + 0.5)
		AegisDB.chatDefW, AegisDB.chatDefH = AegisDB.chatW, AegisDB.chatH
	end
	applyChatSize()
end

-- first start: chat pinned bottom-left; the LuckyOdds window docks to the chat's right edge
-- (only while neither has a saved position of its own)
local function placeDefaults()
	local cf = ChatFrame1
	AegisDB = AegisDB or {}
	if cf and not AegisDB.chatPlaced then
		AegisDB.chatPlaced = true
		cf:ClearAllPoints()
		cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2, 32)
		if FCF_SavePositionAndDimensions then
			pcall(FCF_SavePositionAndDimensions, cf)
		end
	end
	local lf = getglobal("LuckyOddsFrame")
	if cf and lf and not (type(LuckyOddsDB) == "table" and LuckyOddsDB.point) then
		lf:ClearAllPoints()
		lf:SetPoint("BOTTOMLEFT", cf, "BOTTOMRIGHT", 14, 0)
	end
end

-- Reset defaults: chat back to the bottom-left corner and default size, LuckyOdds docked to its right edge again
local function resetChat()
	local cf = ChatFrame1
	AegisDB = AegisDB or {}
	if not cf then
		return
	end
	if AegisDB.chatDefW and AegisDB.chatDefH then
		AegisDB.chatW, AegisDB.chatH = AegisDB.chatDefW, AegisDB.chatDefH
		applyChatSize()
	end
	cf:ClearAllPoints()
	cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2, 32)
	if FCF_SavePositionAndDimensions then
		pcall(FCF_SavePositionAndDimensions, cf)
	end
	if type(LuckyOddsDB) == "table" then
		LuckyOddsDB.point, LuckyOddsDB.rel, LuckyOddsDB.x, LuckyOddsDB.y = nil, nil, nil, nil
	end
	local lf = getglobal("LuckyOddsFrame")
	if lf then
		lf:ClearAllPoints()
		lf:SetPoint("BOTTOMLEFT", cf, "BOTTOMRIGHT", 14, 0)
	end
end

local function setChatSize(w, h)
	AegisDB = AegisDB or {}
	if w < CHAT_MIN_W then
		w = CHAT_MIN_W
	end
	if h < CHAT_MIN_H then
		h = CHAT_MIN_H
	end
	AegisDB.chatW, AegisDB.chatH = w, h
	applyChatSize()
end

local function buildGrip()
	if grip or not ChatFrame1 then
		return
	end
	grip = CreateFrame("Button", nil, UIParent)
	grip:SetWidth(14)
	grip:SetHeight(14)
	grip:SetFrameStrata("DIALOG")
	grip:SetPoint("TOPRIGHT", ChatFrame1, "TOPRIGHT", 6, 6)
	grip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	grip:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
	grip:SetBackdropBorderColor(0.78, 0.58, 0.22, 1)
	local t = grip:CreateFontString(nil, "OVERLAY")
	t:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
	t:SetPoint("CENTER", grip, "CENTER", 0, 0)
	t:SetText("+")
	t:SetTextColor(1, 0.86, 0.45)
	grip:Hide()
	grip:SetScript("OnMouseDown", function()
		local cf = ChatFrame1
		cf:SetResizable(true)
		cf:SetMinResize(CHAT_MIN_W, CHAT_MIN_H)
		cf:StartSizing("TOPRIGHT")
		grip.sizing = true
	end)
	grip:SetScript("OnMouseUp", function()
		local cf = ChatFrame1
		cf:StopMovingOrSizing()
		grip.sizing = false
		setChatSize(math.floor(cf:GetWidth() + 0.5), math.floor(cf:GetHeight() + 0.5))
		if FCF_SavePositionAndDimensions then
			pcall(FCF_SavePositionAndDimensions, cf)
		end
	end)
end

local function syncGrip()
	buildGrip()
	if not grip then
		return
	end
	if AegisUI and not AegisUI.locked then
		grip:Show()
	elseif not grip.sizing then
		grip:Hide()
	end
end

local tabsDone = {}
local tabAcc = 0

local function styleTab(i)
	local tab = getglobal("ChatFrame" .. i .. "Tab")
	if not tab then
		return
	end
	if not tabsDone[i] then
		tabsDone[i] = true
		quiet(function()
			AegisSkin.ApplyRow(tab)
			tab:SetBackdropColor(0.09, 0.10, 0.14, 1)
			local ln = tab:CreateTexture(nil, "OVERLAY")
			ln:SetTexture(SOLID)
			ln:SetHeight(2)
			ln:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 1, 1)
			ln:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
			tab.aegisLine = ln
		end)
		quiet(function()
			local fs = getglobal("ChatFrame" .. i .. "TabText")
			if fs then
				local _, size = fs:GetFont()
				fs:SetFont("Fonts\\FRIZQT__.TTF", size or 11, "OUTLINE")
			end
		end)
	end
	-- the stock tab is 32 px high with art padding and hit-rect insets; make it a flat, fully clickable strip
	quiet(function()
		tab:SetHeight(22)
		tab:SetHitRectInsets(0, 0, 0, 0)
		tab:EnableMouse(true)
		local fs = getglobal("ChatFrame" .. i .. "TabText")
		if fs then
			fs:ClearAllPoints()
			fs:SetPoint("CENTER", tab, "CENTER", 0, 0)
		end
	end)
	-- hide the stock tab textures (left/middle/right, selected, highlight, glow)
	quiet(function()
		local regs = { tab:GetRegions() }
		local k
		for k = 1, table.getn(regs) do
			local r = regs[k]
			quiet(function()
				if r:GetObjectType() == "Texture" and r ~= tab.aegisLine then
					r:SetAlpha(0)
				end
			end)
		end
	end)
	local selected = (SELECTED_CHAT_FRAME == getglobal("ChatFrame" .. i))
	local g, e = AegisSkin.color.gold, AegisSkin.color.rowEdge
	quiet(function()
		if tab.aegisLine then
			if selected then
				tab.aegisLine:SetVertexColor(g[1], g[2], g[3], 1)
				tab.aegisLine:Show()
			else
				tab.aegisLine:Hide()
			end
		end
		local fs = getglobal("ChatFrame" .. i .. "TabText")
		if fs then
			if selected then
				fs:SetTextColor(1, 0.86, 0.45)
			else
				fs:SetTextColor(0.55, 0.58, 0.66)
			end
		end
		tab:SetBackdropBorderColor(e[1], e[2], e[3], 1)
	end)
end

local tabFrame = CreateFrame("Frame")
tabFrame:SetScript("OnUpdate", function()
	if not built then
		return
	end
	tabAcc = tabAcc + (arg1 or 0)
	if tabAcc < 0.3 then
		return
	end
	tabAcc = 0
	syncPanel()
	syncGrip()
	local i
	for i = 1, 7 do
		styleTab(i)
	end
end)

-- /aegis chat tabs: print what the client reports for every chat tab (for debugging)
local function debugTabs()
	local i
	for i = 1, 7 do
		local tab = getglobal("ChatFrame" .. i .. "Tab")
		if tab and DEFAULT_CHAT_FRAME then
			local sel = (SELECTED_CHAT_FRAME == getglobal("ChatFrame" .. i))
			DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aTab " .. i .. ":|r shown=" .. tostring(tab:IsShown()) .. " w=" .. tostring(tab:GetWidth()) .. " h=" .. tostring(tab:GetHeight())
				.. " mouse=" .. tostring(tab:IsMouseEnabled()) .. " strata=" .. tostring(tab:GetFrameStrata()) .. " level=" .. tostring(tab:GetFrameLevel())
				.. " selected=" .. tostring(sel) .. " styled=" .. tostring(tabsDone[i]))
		end
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
local sizeT = nil
ev:SetScript("OnEvent", function()
	build()
	syncPanel()
	bootChatSize()
	-- the game restores its own chat layout a moment after login: apply ours again
	sizeT = 0
end)
local sizeF = CreateFrame("Frame")
sizeF:SetScript("OnUpdate", function()
	if sizeT then
		sizeT = sizeT + (arg1 or 0)
		if sizeT > 2.5 then
			sizeT = nil
			applyChatSize()
			pcall(placeDefaults)
		end
	end
end)

local function hubHook()
	if not AegisUI or AegisUI.hooked_chat then
		return
	end
	AegisUI.hooked_chat = true
	AegisUI.resetHooks = AegisUI.resetHooks or {}
	AegisUI.resetHooks[table.getn(AegisUI.resetHooks) + 1] = resetChat
	AegisUI.api.chat = {
		debugTabs = debugTabs,
		getW = function()
			return (AegisDB and AegisDB.chatW) or (ChatFrame1 and ChatFrame1:GetWidth()) or 320
		end,
		getH = function()
			return (AegisDB and AegisDB.chatH) or (ChatFrame1 and ChatFrame1:GetHeight()) or 120
		end,
		setW = function(v)
			setChatSize(v, (AegisDB and AegisDB.chatH) or 120)
		end,
		setH = function(v)
			setChatSize((AegisDB and AegisDB.chatW) or 320, v)
		end,
		isOn = function()
			return enabled()
		end,
		setOn = function(on)
			AegisDB = AegisDB or {}
			AegisDB.chat = on and true or false
			if on then
				build()
				syncPanel()
				if DEFAULT_CHAT_FRAME then
					DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUI:|r " .. L("Chat reskin is on."))
				end
			elseif DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage(L("|cffd2a24aAegisUI:|r Chat reskin will be disabled after /reload."))
			end
		end,
	}
end
hubHook()
local hk = CreateFrame("Frame")
hk:RegisterEvent("PLAYER_LOGIN")
hk:SetScript("OnEvent", hubHook)
