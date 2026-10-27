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


-- copyable text window (diagnostics, frame lists, fstack)
local diagWin

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

local function hubHook()
	if not AegisUI or AegisUI.hooked_fonts then
		return
	end
	AegisUI.hooked_fonts = true
	AegisUI.api.fonts = {
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
