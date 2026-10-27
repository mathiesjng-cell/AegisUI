-- AegisSurvivor: lets AegisUI take over parts of the game's own SurvivorUI (action bar, player /
-- target frames, buffs). SurvivorUI keeps everything else (run tracker, history, guardians, ...).
-- It has its own per-part switches (SurvivorUI_Feature / SurvivorUI_SetFeature, "/sui opt");
-- they take hold at the next /reload. Lua 5.0 / WoW 1.12.

local L = AegisL.t

local PARTS = {
	{ key = "actionBar", label = "SurvivorUI action bar" },
	{ key = "unitFrames", label = "SurvivorUI player/target frames" },
	{ key = "buffs", label = "SurvivorUI buffs" },
}

local function present()
	return SurvivorUI_Feature ~= nil and SurvivorUI_SetFeature ~= nil
end

local function say(t)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUI:|r " .. t)
	end
end

-- once, on the first start with SurvivorUI present: switch off the parts AegisUI replaces
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
	if not present() then
		return
	end
	AegisDB = AegisDB or {}
	if AegisDB.svDone then
		return
	end
	AegisDB.svDone = true
	for i = 1, table.getn(PARTS) do
		SurvivorUI_SetFeature(PARTS[i].key, false)
	end
	say(L("SurvivorUI action bar, player/target frames and buffs were switched off (AegisUI replaces them). Please type /reload once. Undo in the hub, SKINS tab."))
end)

if AegisUI and AegisUI.api then
	AegisUI.api.survivor = {
		parts = PARTS,
		-- true = the SurvivorUI part is switched off (replaced by AegisUI)
		getOff = function(key)
			return present() and not SurvivorUI_Feature(key)
		end,
		setOff = function(key, off)
			if present() then
				SurvivorUI_SetFeature(key, not off)
				say(L("Takes effect after /reload."))
			end
		end,
	}
end
