-- AegisFonts: the numbers that fly up from enemies are drawn by the game client itself
-- (CVar "CombatDamage"; font = global DAMAGE_TEXT_FONT, which the client reads at startup).
-- So from Lua we can: switch the numbers on/off and pick their font. Size, colour and
-- crit-only filtering are not exposed by the client.

local L = AegisL.t

local FONT_AEGIS = "Fonts\\ARIALN.TTF"
local FONT_STOCK = "Fonts\\FRIZQT__.TTF"

-- runs at addon load, before the world is entered: this is when the client picks the font up
if not (AegisDB and AegisDB.dmgFont == false) then
	DAMAGE_TEXT_FONT = FONT_AEGIS
end

local function cvarOn(name)
	local ok, v = pcall(GetCVar, name)
	return ok and v == "1"
end


-- /aegis debug ct2: 15 s capture. Do we get damage events with numbers, and can we find the
-- nameplate frames (needed to put own numbers above enemies)?
local diagFrame, diagWin
local lines, counts, samples
local EVENTS = {
	"UNIT_COMBAT", "COMBAT_TEXT_UPDATE",
	"CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
	"CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
	"CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS",
}

local function showText(txt)
	if not diagWin then
		diagWin = CreateFrame("Frame", "AegisDiagWin", UIParent)
		diagWin:SetWidth(520)
		diagWin:SetHeight(320)
		diagWin:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		diagWin:SetFrameStrata("DIALOG")
		diagWin:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		diagWin:SetBackdropColor(0.04, 0.05, 0.08, 0.97)
		diagWin:EnableMouse(true)
		diagWin:SetMovable(true)
		diagWin:RegisterForDrag("LeftButton")
		diagWin:SetScript("OnDragStart", function() this:StartMoving() end)
		diagWin:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
		local eb = CreateFrame("EditBox", "AegisDiagEdit", diagWin)
		eb:SetMultiLine(true)
		eb:SetAutoFocus(false)
		eb:SetFontObject(GameFontHighlightSmall)
		eb:SetWidth(496)
		eb:SetHeight(290)
		eb:SetPoint("TOPLEFT", diagWin, "TOPLEFT", 12, -12)
		eb:SetScript("OnEscapePressed", function() diagWin:Hide() end)
		diagWin.eb = eb
	end
	diagWin.eb:SetText(txt)
	diagWin:Show()
end

local function showResult()
	showText(table.concat(lines, "\n"))
end

local function scanPlates()
	local n, found = 0, 0
	local kids = { WorldFrame:GetChildren() }
	for i = 1, table.getn(kids) do
		local f = kids[i]
		n = n + 1
		if f and f:IsShown() and f:GetName() == nil and f.GetCenter then
			local x, y = f:GetCenter()
			local w = f:GetWidth()
			if x and y and w and w > 60 and w < 200 and found < 5 then
				found = found + 1
				table.insert(lines, "plate? #" .. i .. " x=" .. math.floor(x) .. " y=" .. math.floor(y) .. " w=" .. math.floor(w) .. " kids=" .. f:GetNumChildren() .. " regions=" .. f:GetNumRegions())
			end
		end
	end
	table.insert(lines, "WorldFrame children: " .. n .. ", plate candidates: " .. found)
end

local function runDiag()
	lines, counts, samples = {}, {}, {}
	if not diagFrame then
		diagFrame = CreateFrame("Frame")
		diagFrame:SetScript("OnEvent", function()
			counts[event] = (counts[event] or 0) + 1
			if (samples[event] or 0) < 3 then
				samples[event] = (samples[event] or 0) + 1
				local t = ""
				if event == "UNIT_COMBAT" then
					t = "unit=" .. tostring(arg1) .. " action=" .. tostring(arg2) .. " crit=" .. tostring(arg3) .. " dmg=" .. tostring(arg4) .. " school=" .. tostring(arg5)
				else
					t = tostring(arg1)
				end
				table.insert(lines, event .. ": " .. t)
			end
		end)
	end
	for i = 1, table.getn(EVENTS) do
		diagFrame:RegisterEvent(EVENTS[i])
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUI:|r ct2 - 15 s capture, please fight now ...")
	local t0 = GetTime()
	diagFrame:SetScript("OnUpdate", function()
		if GetTime() - t0 < 15 then
			return
		end
		diagFrame:SetScript("OnUpdate", nil)
		diagFrame:UnregisterAllEvents()
		table.insert(lines, "--- counts ---")
		for i = 1, table.getn(EVENTS) do
			table.insert(lines, EVENTS[i] .. " = " .. (counts[EVENTS[i]] or 0))
		end
		table.insert(lines, "--- nameplates ---")
		scanPlates()
		showResult()
	end)
end

local function hubHook()
	if not AegisUI or AegisUI.hooked_fonts then
		return
	end
	AegisUI.hooked_fonts = true
	AegisUI.api.fonts = {
		diag = runDiag,
		showText = showText,
		getDamage = function()
			return cvarOn("CombatDamage")
		end,
		setDamage = function(on)
			pcall(SetCVar, "CombatDamage", on and "1" or "0")
		end,
		getHealing = function()
			return cvarOn("CombatHealing")
		end,
		setHealing = function(on)
			pcall(SetCVar, "CombatHealing", on and "1" or "0")
		end,
		hasHealing = function()
			local ok, v = pcall(GetCVar, "CombatHealing")
			return ok and v ~= nil
		end,
		getFont = function()
			return not (AegisDB and AegisDB.dmgFont == false)
		end,
		setFont = function(on)
			AegisDB = AegisDB or {}
			AegisDB.dmgFont = on and true or false
			if on then
				DAMAGE_TEXT_FONT = FONT_AEGIS
			else
				DAMAGE_TEXT_FONT = FONT_STOCK
			end
			if DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUI:|r " .. L("The number font changes after a game restart."))
			end
		end,
	}
end
hubHook()
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
	hubHook()
	-- the saved choice is only known now: undo the early default when it was switched off
	if AegisDB and AegisDB.dmgFont == false then
		DAMAGE_TEXT_FONT = FONT_STOCK
	end
end)
