-- AegisBars: action bar reskin (icon crop, thin dark frame) and optional removal of the
-- main bar art (gryphons, bar background). WoW 1.12 / Lua 5.0. Everything is best effort and
-- pcall-guarded: buttons or textures that do not exist (custom bar addons) are skipped.

local L = AegisL.t

local SOLID = "Interface\\Buttons\\WHITE8X8"

local BAR_PREFIX = {
	{ "ActionButton", 12 },
	{ "BonusActionButton", 12 },
	{ "MultiBarBottomLeftButton", 12 },
	{ "MultiBarBottomRightButton", 12 },
	{ "MultiBarRightButton", 12 },
	{ "MultiBarLeftButton", 12 },
	{ "ShapeshiftButton", 10 },
	{ "PetActionButton", 10 },
}

-- bar art (gryphons, bar background, shapeshift bar background)
local ART = {
	"MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
	"MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
	"ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight",
	"MainMenuBarOverlayFrame", "MainMenuBarPerformanceBarFrame", "MainMenuBarPageNumber",
	"ActionBarUpButton", "ActionBarDownButton", "MainMenuBarTextureExtender",
}

local B = { skinned = {}, hooked = false }

local function db()
	AegisDB = AegisDB or {}
	AegisDB.bars = AegisDB.bars or {}
	return AegisDB.bars
end

local function skinOn()
	local d = db()
	return d.skin == nil or d.skin
end

local function styleButton(btn)
	if not btn or not btn.GetName then
		return
	end
	local name = btn:GetName()
	if not name then
		return
	end
	pcall(function()
		local normal = btn.GetNormalTexture and btn:GetNormalTexture() or getglobal(name .. "NormalTexture")
		if normal then
			normal:SetAlpha(0)           -- the stock frame / empty-slot art
		end
	end)
	pcall(function()
		local border = getglobal(name .. "Border")
		if border then
			border:SetTexture(SOLID)       -- equip highlight: a flat tint instead of the glow
			border:SetAlpha(0.5)
		end
	end)
	if B.skinned[name] then
		return
	end
	B.skinned[name] = true
	btn:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	btn:SetBackdropColor(0.04, 0.05, 0.08, 0.9)
	btn:SetBackdropBorderColor(0.14, 0.16, 0.22, 1)
	pcall(function()
		local icon = getglobal(name .. "Icon")
		if icon then
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
			icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
		end
	end)
end

function AegisUI_SkinActionBars()
	local i, n
	for i = 1, table.getn(BAR_PREFIX) do
		for n = 1, BAR_PREFIX[i][2] do
			local btn = getglobal(BAR_PREFIX[i][1] .. n)
			if btn then
				local ok, err = pcall(styleButton, btn)
				if not ok and not B.told and DEFAULT_CHAT_FRAME then
					B.told = true
					DEFAULT_CHAT_FRAME:AddMessage("|cffff4444AegisBars (" .. BAR_PREFIX[i][1] .. n .. "):|r " .. tostring(err))
				end
			end
		end
	end
	-- the stock update resets the empty-slot art; style the button again afterwards
	if not B.hooked and ActionButton_Update then
		B.hooked = true
		local orig = ActionButton_Update
		ActionButton_Update = function()
			orig()
			if skinOn() and this then
				pcall(styleButton, this)
			end
		end
	end
end

local function customOn()
	local d = db()
	return d.custom == nil or d.custom
end

-- every texture the stock bar frames draw themselves (their named parts are in ART)
local function hideStockRegions()
	local frames = { "MainMenuBar", "MainMenuBarArtFrame" }
	local i, j
	for i = 1, table.getn(frames) do
		local f = getglobal(frames[i])
		if f and f.GetRegions then
			local regs = { f:GetRegions() }
			for j = 1, table.getn(regs) do
				pcall(function()
					if regs[j]:GetObjectType() == "Texture" then
						regs[j]:Hide()
					end
				end)
			end
		end
	end
end

local function applyArt()
	local hide = db().hideArt or customOn()
	if hide then
		hideStockRegions()
	end
	local i
	for i = 1, table.getn(ART) do
		local t = getglobal(ART[i])
		if t then
			if hide then
				t:Hide()
			else
				t:Show()
			end
		end
	end
end

-- Own action bar + XP bar ------------------------------------------------------------------

local SIZE, GAP, PAD = 34, 4, 4
-- the game only uses these action slots (12 is the = key)
local SLOTS = { 1, 2, 3, 4, 5, 6, 12 }
local bf, xp, xpFill, xpRest, xpText

local function xpUpdate()
	if not xp then
		return
	end
	local cur, mx = UnitXP("player"), UnitXPMax("player")
	if not mx or mx <= 0 then
		xp:Hide()
		return
	end
	xp:Show()
	local inner = xp:GetWidth() - 2
	if inner < 10 then
		inner = 460
	end
	local f = cur / mx
	if f > 1 then
		f = 1
	end
	xpFill:SetWidth(math.max(1, inner * f))
	local rest = GetXPExhaustion and GetXPExhaustion()
	if rest and rest > 0 then
		local rf = (cur + rest) / mx
		if rf > 1 then
			rf = 1
		end
		xpRest:SetWidth(math.max(1, inner * rf))
		xpRest:Show()
	else
		xpRest:Hide()
	end
	xpText:SetText(cur .. " / " .. mx .. "  |cff6f7588" .. math.floor(f * 100 + 0.5) .. "%|r")
end

local function buildBar()
	if bf then
		return
	end
	local w = table.getn(SLOTS) * SIZE + (table.getn(SLOTS) - 1) * GAP + PAD * 2
	bf = CreateFrame("Frame", "AegisBarFrame", UIParent)
	bf:SetWidth(w)
	bf:SetHeight(SIZE + PAD * 2)
	bf:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 16)
	bf:SetFrameStrata("MEDIUM")
	bf:SetFrameLevel(1)
	bf:SetMovable(true)
	bf:EnableMouse(true)
	bf:SetClampedToScreen(true)
	if AegisSkin and AegisSkin.ApplyPanel then
		AegisSkin.ApplyPanel(bf)
		AegisSkin.GoldLine(bf)
	end
	bf:RegisterForDrag("LeftButton")
	bf:SetScript("OnDragStart", function()
		if AegisUI and AegisUI.locked then
			return
		end
		this:StartMoving()
	end)
	bf:SetScript("OnDragStop", function()
		if AegisUI and AegisUI.locked then
			return
		end
		this:StopMovingOrSizing()
		if AegisUI and AegisUI.snapFrame then
			AegisUI.snapFrame(this)
		end
		local p, _, rp, x, y = this:GetPoint(1)
		if p then
			db().point = { p, rp, x, y }
		end
	end)

	-- XP bar right above the action bar
	xp = CreateFrame("Frame", "AegisXPBar", bf)
	xp:SetHeight(12)
	xp:SetPoint("BOTTOMLEFT", bf, "TOPLEFT", 0, 1)
	xp:SetPoint("BOTTOMRIGHT", bf, "TOPRIGHT", 0, 1)
	xp:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	xp:SetBackdropColor(0.04, 0.05, 0.08, 0.96)
	xp:SetBackdropBorderColor(0.14, 0.16, 0.22, 1)
	xpRest = xp:CreateTexture(nil, "ARTWORK")
	xpRest:SetTexture(SOLID)
	xpRest:SetVertexColor(0.20, 0.30, 0.62, 1)
	xpRest:SetPoint("TOPLEFT", xp, "TOPLEFT", 1, -1)
	xpRest:SetHeight(10)
	xpFill = xp:CreateTexture(nil, "OVERLAY")
	xpFill:SetTexture(SOLID)
	xpFill:SetVertexColor(0.55, 0.30, 0.95, 1)
	xpFill:SetPoint("TOPLEFT", xp, "TOPLEFT", 1, -1)
	xpFill:SetHeight(10)
	xpText = xp:CreateFontString(nil, "OVERLAY")
	xpText:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
	xpText:SetPoint("CENTER", xp, "CENTER", 0, 0)

	if AegisUI and AegisUI.register then
		AegisUI.register("bar", "Action bar", bf, function()
			db().point = nil
			bf:ClearAllPoints()
			bf:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 16)
		end)
	end
end

-- The game's menu buttons (character, talents, ...) sit in a small matching panel right of the bar
local MICRO = { "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton",
	"SocialsMicroButton", "WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton" }
local sep

-- the menu buttons become part of the bar itself: behind a thin divider, inside the same panel
local LABEL = { CharacterMicroButton = "C", SpellbookMicroButton = "B", TalentMicroButton = "T",
	QuestLogMicroButton = "Q", SocialsMicroButton = "F", WorldMapMicroButton = "M",
	MainMenuMicroButton = "ESC", HelpMicroButton = "?" }
local own = {}

-- one square, bar-styled button per stock menu button; the stock button is hidden visually
-- and still receives the click, so every menu keeps working
local function ownButton(name)
	if own[name] then
		return own[name]
	end
	local o = CreateFrame("Button", "Aegis" .. name, bf)
	o:SetWidth(SIZE)
	o:SetHeight(SIZE)
	o:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	o:SetBackdropColor(0.06, 0.07, 0.10, 1)
	o:SetBackdropBorderColor(0.17, 0.19, 0.25, 1)
	local t = o:CreateFontString(nil, "OVERLAY")
	t:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
	t:SetTextColor(0.78, 0.58, 0.22)
	t:SetPoint("CENTER", o, "CENTER", 0, 0)
	t:SetText(LABEL[name] or "?")
	o.name = name
	o:SetScript("OnEnter", function()
		this:SetBackdropBorderColor(0.78, 0.58, 0.22, 1)
	end)
	o:SetScript("OnLeave", function()
		this:SetBackdropBorderColor(0.17, 0.19, 0.25, 1)
	end)
	o:EnableMouse(true)
	o:RegisterForClicks("LeftButtonUp")
	o:SetFrameLevel(bf:GetFrameLevel() + 5)
	o:SetScript("OnClick", function()
		local nm = this.name
		local sb = getglobal(nm)
		local fn
		if nm == "CharacterMicroButton" and ToggleCharacter then
			fn = function() ToggleCharacter("PaperDollFrame") end
		elseif nm == "SpellbookMicroButton" and ToggleSpellBook then
			fn = function() ToggleSpellBook(BOOKTYPE_SPELL) end
		elseif nm == "TalentMicroButton" and ToggleTalentFrame then
			fn = ToggleTalentFrame
		elseif nm == "QuestLogMicroButton" and ToggleQuestLog then
			fn = ToggleQuestLog
		elseif nm == "SocialsMicroButton" and ToggleFriendsFrame then
			fn = function() ToggleFriendsFrame() end
		elseif nm == "WorldMapMicroButton" and ToggleWorldMap then
			fn = ToggleWorldMap
		elseif nm == "MainMenuMicroButton" and ToggleGameMenu then
			fn = ToggleGameMenu
		elseif nm == "HelpMicroButton" and ToggleHelpFrame then
			fn = ToggleHelpFrame
		end
		if fn and pcall(fn) then
			return
		end
		if sb then
			local oc = sb:GetScript("OnClick")
			if oc then
				local saved = this
				this = sb
				pcall(oc)
				this = saved
			elseif sb.Click then
				sb:Click()
			end
		end
	end)
	own[name] = o
	return o
end

local function layoutMicro()
	if not bf then
		return
	end
	local n = table.getn(SLOTS)
	local x = PAD + n * (SIZE + GAP) - GAP + 6
	local startX = x
	local count = 0
	local i
	for i = 1, table.getn(MICRO) do
		local b = getglobal(MICRO[i])
		if b and b:IsShown() then
			-- hide the stock art; keep the object alive so Click() works
			if b.SetAlpha then
				b:SetAlpha(0)
			end
			if b.EnableMouse then
				b:EnableMouse(false)
			end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -200, 200)
			local o = ownButton(MICRO[i])
			o:ClearAllPoints()
			o:SetPoint("BOTTOMLEFT", bf, "BOTTOMLEFT", x, PAD)
			o:Show()
			x = x + SIZE + GAP
			count = count + 1
		end
	end
	if not sep then
		sep = bf:CreateTexture(nil, "OVERLAY")
		sep:SetTexture(SOLID)
		sep:SetVertexColor(0.17, 0.19, 0.25, 1)
		sep:SetWidth(1)
		sep:SetHeight(SIZE)
	end
	if count == 0 then
		sep:Hide()
		bf:SetWidth(n * SIZE + (n - 1) * GAP + PAD * 2)
	else
		sep:ClearAllPoints()
		sep:SetPoint("LEFT", bf, "LEFT", startX - 4, 0)
		sep:Show()
		bf:SetWidth(x - GAP + PAD)
	end
end

local function layoutBar()
	buildBar()
	local d = db()
	if d.point then
		bf:ClearAllPoints()
		bf:SetPoint(d.point[1], UIParent, d.point[2] or d.point[1], d.point[3] or 0, d.point[4] or 0)
	end
	bf:Show()
	-- move the stock buttons onto our bar (they keep their own parents and paging)
	local names = { "ActionButton", "BonusActionButton" }
	local k, i
	for k = 1, 2 do
		for i = 1, table.getn(SLOTS) do
			local btn = getglobal(names[k] .. SLOTS[i])
			if btn then
				btn:ClearAllPoints()
				btn:SetPoint("LEFT", bf, "LEFT", PAD + (i - 1) * (SIZE + GAP), 0)
				btn:SetWidth(SIZE)
				btn:SetHeight(SIZE)
			end
		end
	end
	-- the stock XP bar goes away
	local old = getglobal("MainMenuExpBar")
	if old then
		old:SetScript("OnShow", function()
			this:Hide()
		end)
		old:Hide()
	end
	local tick = getglobal("ExhaustionTick")
	if tick then
		tick:Hide()
	end
	-- the invisible stock bar frame sits on top and swallows clicks
	pcall(function()
		MainMenuBar:EnableMouse(false)
		if MainMenuBarArtFrame then
			MainMenuBarArtFrame:EnableMouse(false)
		end
	end)
	pcall(layoutMicro)
	xpUpdate()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_XP_UPDATE")
ev:RegisterEvent("UPDATE_EXHAUSTION")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function()
	if event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" or event == "PLAYER_LEVEL_UP" then
		pcall(xpUpdate)
		return
	end
	local custom = customOn()
	if skinOn() or custom then
		local ok, err = pcall(AegisUI_SkinActionBars)
		if not ok and DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L("|cffff4444AegisBars error:|r ") .. tostring(err))
		end
	end
	if custom then
		local ok, err = pcall(layoutBar)
		if not ok and DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(L("|cffff4444AegisBar error:|r ") .. tostring(err))
		end
	end
	if db().hideArt or custom then
		pcall(applyArt)
	end
end)

-- The game's spells cast themselves with cooldowns of a fraction of a second, so the stock
-- cooldown sweep re-triggers all the time and the icon looks black. Skip sweeps shorter than
-- SHORT_CD seconds on the action buttons (switchable).
local SHORT_CD = 2
local function shortCdOn()
	return db().shortCd == nil or db().shortCd
end
if CooldownFrame_SetTimer and not B.cdHooked then
	B.cdHooked = true
	local origCd = CooldownFrame_SetTimer
	CooldownFrame_SetTimer = function(frame, start, duration, enable)
		if duration and duration > 0 and duration < SHORT_CD and frame and frame.GetName and shortCdOn() then
			local n = frame:GetName()
			if n and string.find(n, "ActionButton%d+Cooldown$") then
				start, duration, enable = 0, 0, 0
			end
		end
		return origCd(frame, start, duration, enable)
	end
end

-- The game's spells cast themselves, so "not usable" (cooldown, no target) flickers constantly and
-- the stock bar keeps dimming the icon. Keep the icons at full brightness (switchable).
local function noDimOn()
	return db().noDim == nil or db().noDim
end
if ActionButton_UpdateUsable and not B.usHooked then
	B.usHooked = true
	local origUs = ActionButton_UpdateUsable
	ActionButton_UpdateUsable = function()
		origUs()
		if this and this.GetName and skinOn() and noDimOn() then
			local n = this:GetName()
			if n and string.find(n, "ActionButton%d+$") then
				local icon = getglobal(n .. "Icon")
				if icon then
					icon:SetVertexColor(1, 1, 1)
				end
			end
		end
	end
end

if AegisUI then
	if AegisUI.api then
		AegisUI.api.bars = {
			getNoDim = function()
				return noDimOn()
			end,
			setNoDim = function(v)
				db().noDim = v and true or false
			end,
			getShortCd = function()
				return shortCdOn()
			end,
			setShortCd = function(v)
				db().shortCd = v and true or false
				if DEFAULT_CHAT_FRAME then
					DEFAULT_CHAT_FRAME:AddMessage(L("|cffd2a24aAegisUI:|r Cooldown sweeps update with the next cooldown."))
				end
			end,
			getSkin = function()
				return skinOn()
			end,
			setSkin = function(v)
				db().skin = v and true or false
				if v then
					pcall(AegisUI_SkinActionBars)
				elseif DEFAULT_CHAT_FRAME then
					DEFAULT_CHAT_FRAME:AddMessage(L("|cffd2a24aAegisUI:|r Action bar look will be disabled after /reload."))
				end
			end,
			getCustom = function()
				return customOn()
			end,
			setCustom = function(v)
				db().custom = v and true or false
				if v then
					pcall(AegisUI_SkinActionBars)
					pcall(layoutBar)
					pcall(applyArt)
				elseif DEFAULT_CHAT_FRAME then
					DEFAULT_CHAT_FRAME:AddMessage(L("|cffd2a24aAegisUI:|r The original bar returns after /reload."))
				end
			end,
			getArt = function()
				return db().hideArt and true or false
			end,
			setArt = function(v)
				db().hideArt = v and true or false
				pcall(applyArt)
			end,
		}
	end
	AegisUI.SkinActionBars = AegisUI_SkinActionBars
end

-- /mui bars: what does the client's action bar look like (for debugging custom bars)
function AegisUI_BarsDebug()
	local say = function(t)
		DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aBars:|r " .. t)
	end
	local found, total = 0, 0
	local i, n
	for i = 1, table.getn(BAR_PREFIX) do
		for n = 1, BAR_PREFIX[i][2] do
			total = total + 1
			if getglobal(BAR_PREFIX[i][1] .. n) then
				found = found + 1
			end
		end
	end
	say(L("Buttons found: ") .. found .. L(" of ") .. total .. L(", look on: ") .. tostring(skinOn()) .. L(", styled: ") .. tostring(B.skinned.ActionButton1) .. L(", update hook: ") .. tostring(B.hooked))
	local b = getglobal("ActionButton1")
	if b then
		say(L("ActionButton1 type ") .. tostring(b:GetObjectType()) .. L(", size ") .. tostring(b:GetWidth()) .. "x" .. tostring(b:GetHeight()) .. L(", parent ") .. tostring(b:GetParent() and b:GetParent():GetName()))
		local regs = { b:GetRegions() }
		for i = 1, table.getn(regs) do
			local r = regs[i]
			local tx = ""
			if r.GetTexture then
				tx = tostring(r:GetTexture())
			end
			say("  Region " .. i .. " " .. tostring(r:GetName()) .. " " .. tostring(r:GetObjectType()) .. " " .. tx)
		end
	end
	local art = {}
	for i = 1, table.getn(ART) do
		if getglobal(ART[i]) then
			art[table.getn(art) + 1] = ART[i]
		end
	end
	say(L("Bar art present: ") .. table.concat(art, ", "))
end

-- /aegis who: prints the name chain of the frame under the mouse whenever it changes
-- (hover the unknown buttons, then type /aegis who again to stop)
local whoFrame = nil
local whoLast = nil
function AegisUI_Who()
	if whoFrame and whoFrame.on then
		whoFrame.on = false
		whoFrame:SetScript("OnUpdate", nil)
		DEFAULT_CHAT_FRAME:AddMessage(L("|cffd2a24aWho:|r off"))
		return
	end
	if not whoFrame then
		whoFrame = CreateFrame("Frame")
	end
	whoFrame.on = true
	whoLast = nil
	DEFAULT_CHAT_FRAME:AddMessage(L("|cffd2a24aWho:|r on - move the mouse over the icons, /aegis who stops."))
	whoFrame:SetScript("OnUpdate", function()
		local f = GetMouseFocus and GetMouseFocus()
		if f == whoLast then
			return
		end
		whoLast = f
		if not f then
			return
		end
		local chain = ""
		local p = f
		local depth = 0
		while p and depth < 6 do
			local nm = p.GetName and p:GetName() or nil
			chain = chain .. (nm or "?") .. " < "
			p = p.GetParent and p:GetParent() or nil
			depth = depth + 1
		end
		local w = f.GetWidth and f:GetWidth() or 0
		local h = f.GetHeight and f:GetHeight() or 0
		DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aWho:|r " .. chain .. " (" .. math.floor(w + 0.5) .. "x" .. math.floor(h + 0.5) .. ")")
	end)
end
