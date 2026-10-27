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
	AegisSkin.ApplyPanel(panel)
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
ev:SetScript("OnEvent", function()
	build()
	syncPanel()
end)

local function hubHook()
	if not AegisUI or AegisUI.hooked_chat then
		return
	end
	AegisUI.hooked_chat = true
	AegisUI.api.chat = {
		debugTabs = debugTabs,
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
