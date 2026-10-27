-- AegisCore: shared layer for all AegisMeter modules (WoW 1.12 client, Lua 5.0).
--   * registry of movable frames
--   * lock / unlock: unlocked shows a gold overlay on every frame, drag to move
--   * snap: on release a frame snaps to screen edges/centre, to the edges of the other frames, or to a grid
-- Modules call AegisUI.register(...), check AegisUI.locked in their drag handlers and call AegisUI.snapFrame(f).

local L = AegisL.t

local SOLID = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_NUM = "Fonts\\ARIALN.TTF"

AegisUI = {
	locked = true,
	snap = true,
	grid = 8,
	thresh = 10,
	list = {},
	api = {},
}
local UI = AegisUI

local function say(text)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffd2a24aAegisUI:|r " .. text)
	end
end

function UI.register(key, label, frame, reset, onScale)
	UI.list[table.getn(UI.list) + 1] = { key = key, label = label, frame = frame, reset = reset, onScale = onScale }
end

-- Window size: every registered frame can be scaled (50 - 250 %). Saved in AegisDB.scales[key].
local SCALE_MIN, SCALE_MAX = 0.5, 2.5

local function findEntry(key)
	for i = 1, table.getn(UI.list) do
		if UI.list[i].key == key then
			return UI.list[i]
		end
	end
	return nil
end

function UI.getScale(key)
	local e = findEntry(key)
	if not e then
		return nil
	end
	return (AegisDB and AegisDB.scales and AegisDB.scales[key]) or 1
end

-- keepCorner: keep the frame's bottom-left corner where it is on screen while it grows
function UI.setScale(key, s, keepCorner, nosave)
	local e = findEntry(key)
	if not e then
		return
	end
	if s < SCALE_MIN then
		s = SCALE_MIN
	elseif s > SCALE_MAX then
		s = SCALE_MAX
	end
	local f = e.frame
	local l, b
	if keepCorner and f:GetLeft() then
		local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
		l, b = f:GetLeft() * k, f:GetBottom() * k
	end
	f:SetScale(s)
	if e.onScale then
		pcall(e.onScale, s)
	end
	if l then
		f:ClearAllPoints()
		f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l / s, b / s)
	end
	if not nosave then
		AegisDB = AegisDB or {}
		AegisDB.scales = AegisDB.scales or {}
		AegisDB.scales[key] = s
	end
end

function UI.applyScales()
	for i = 1, table.getn(UI.list) do
		local e = UI.list[i]
		local s = AegisDB and AegisDB.scales and AegisDB.scales[e.key]
		if s then
			UI.setScale(e.key, s, false, true)
		end
	end
end

-- after a scale change the module stores the new position through its own drag-stop handler
local function saveEntry(e)
	local f = e.frame
	local fn = f:GetScript("OnDragStop")
	if fn then
		local me = this
		this = f
		pcall(fn)
		this = me
	end
end

function UI.resetScales()
	for i = 1, table.getn(UI.list) do
		local e = UI.list[i]
		if AegisDB and AegisDB.scales and AegisDB.scales[e.key] then
			UI.setScale(e.key, 1, true, true)
			saveEntry(e)
		end
	end
	if AegisDB then
		AegisDB.scales = nil
	end
end

function UI.setScaleSaved(key, s)
	local e = findEntry(key)
	if not e then
		return
	end
	UI.setScale(key, s, true)
	saveEntry(e)
end

-- Snapping -------------------------------------------------------------

local function guideLines(skip)
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local xs = { 0, sw / 2, sw }
	local ys = { 0, sh / 2, sh }
	for i = 1, table.getn(UI.list) do
		local f = UI.list[i].frame
		if f ~= skip and f:IsShown() and f:GetLeft() then
			local l, r, b, t = f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop()
			xs[table.getn(xs) + 1] = l
			xs[table.getn(xs) + 1] = r
			xs[table.getn(xs) + 1] = (l + r) / 2
			ys[table.getn(ys) + 1] = b
			ys[table.getn(ys) + 1] = t
			ys[table.getn(ys) + 1] = (b + t) / 2
		end
	end
	return xs, ys
end

-- smallest move that brings one of my edges onto one of the guide lines (nil if none is close)
local function pullTo(mine, lines, limit)
	local best = nil
	local bd = limit + 0.001
	for i = 1, table.getn(mine) do
		for j = 1, table.getn(lines) do
			local d = lines[j] - mine[i]
			local ad = d
			if ad < 0 then
				ad = -ad
			end
			if ad < bd then
				best, bd = d, ad
			end
		end
	end
	return best
end

-- Bounds: keep a frame's centre on the screen (after a resolution/scale change or a bad
-- saved position a window could end up unreachable). Returns true when it was moved.
function UI.clampFrame(f)
	local l, r, b, t = f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop()
	if not l or not r or not b or not t then
		return false
	end
	local us, fs = UIParent:GetEffectiveScale(), f:GetEffectiveScale()
	local k = 1
	if us and fs and us > 0 then
		k = fs / us
	end
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	local L0, R0, B0, T0 = l * k, r * k, b * k, t * k
	local cx, cy = (L0 + R0) / 2, (B0 + T0) / 2
	local dx, dy = 0, 0
	if cx < 10 then
		dx = 10 - cx
	elseif cx > sw - 10 then
		dx = (sw - 10) - cx
	end
	if cy < 10 then
		dy = 10 - cy
	elseif cy > sh - 10 then
		dy = (sh - 10) - cy
	end
	if dx == 0 and dy == 0 then
		return false
	end
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (L0 + dx) / k, (B0 + dy) / k)
	return true
end

function UI.sanitizeAll(quiet)
	local n = 0
	for i = 1, table.getn(UI.list) do
		if UI.clampFrame(UI.list[i].frame) then
			n = n + 1
		end
	end
	if not quiet then
		if n > 0 then
			say(L("Moved back on screen: ") .. n)
		else
			say(L("All windows are on screen."))
		end
	end
	return n
end

function UI.snapFrame(f)
	if not UI.snap then
		UI.clampFrame(f)
		return
	end
	local l, r, b, t = f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop()
	if not l or not r or not b or not t then
		return
	end
	local xs, ys = guideLines(f)
	local dx = pullTo({ l, (l + r) / 2, r }, xs, UI.thresh)
	local dy = pullTo({ b, (b + t) / 2, t }, ys, UI.thresh)
	local g = UI.grid or 0
	if not dx and g > 0 then
		dx = math.floor(l / g + 0.5) * g - l
	end
	if not dy and g > 0 then
		dy = math.floor(b / g + 0.5) * g - b
	end
	dx = dx or 0
	dy = dy or 0
	if dx ~= 0 or dy ~= 0 then
		f:ClearAllPoints()
		f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l + dx, b + dy)
	end
	UI.clampFrame(f)
end

-- Lock / unlock overlays ----------------------------------------------

local function makeOverlay(e)
	local ov = CreateFrame("Button", nil, UIParent)
	ov:SetFrameStrata("DIALOG")
	ov:SetAllPoints(e.frame)
	ov:EnableMouse(true)
	ov:RegisterForDrag("LeftButton")
	ov:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	ov:SetBackdropColor(0.78, 0.58, 0.22, 0.20)
	ov:SetBackdropBorderColor(0.78, 0.58, 0.22, 1)
	local lab = ov:CreateFontString(nil, "OVERLAY")
	lab:SetFont(FONT, 11, "OUTLINE")
	lab:SetPoint("CENTER", ov, "CENTER", 0, 0)
	lab:SetTextColor(1, 0.85, 0.4, 1)
	lab:SetText(AegisL and AegisL.t(e.label) or e.label)
	ov.entry = e
	-- gold grip at the bottom-right corner: drag to resize (scales the whole window)
	local grip = CreateFrame("Button", nil, ov)
	grip:SetWidth(14)
	grip:SetHeight(14)
	grip:SetPoint("BOTTOMRIGHT", ov, "BOTTOMRIGHT", 0, 0)
	grip:SetFrameLevel(ov:GetFrameLevel() + 3)
	grip:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	grip:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
	grip:SetBackdropBorderColor(0.78, 0.58, 0.22, 1)
	local gt = grip:CreateFontString(nil, "OVERLAY")
	gt:SetFont(FONT_NUM, 11, "OUTLINE")
	gt:SetPoint("CENTER", grip, "CENTER", 0, 0)
	gt:SetText("+")
	gt:SetTextColor(1, 0.86, 0.45)
	grip:SetScript("OnMouseDown", function()
		this.sizing = true
		this:SetScript("OnUpdate", function()
			local f = e.frame
			local w = f:GetWidth()
			local l = f:GetLeft()
			if not w or w <= 0 or not l then
				return
			end
			local cx = GetCursorPosition() / UIParent:GetEffectiveScale()
			local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
			local left = l * k
			local ns = (cx - left) / w
			if ns > 0 then
				UI.setScale(e.key, ns, true)
			end
		end)
	end)
	grip:SetScript("OnMouseUp", function()
		this.sizing = false
		this:SetScript("OnUpdate", nil)
		saveEntry(e)
	end)
	-- the overlay hands the drag to the frame's own handlers, so saving and snapping stay in the modules
	ov:SetScript("OnDragStart", function()
		local me = this
		local f = me.entry.frame
		local fn = f:GetScript("OnDragStart")
		if fn then
			this = f
			fn()
			this = me
		end
	end)
	ov:SetScript("OnDragStop", function()
		local me = this
		local f = me.entry.frame
		local fn = f:GetScript("OnDragStop")
		if fn then
			this = f
			fn()
			this = me
		end
	end)
	e.overlay = ov
	return ov
end

function UI.refreshOverlays()
	for i = 1, table.getn(UI.list) do
		local e = UI.list[i]
		local want = (not UI.locked) and e.frame:IsShown()
		if want then
			local ov = e.overlay or makeOverlay(e)
			ov:Show()
		elseif e.overlay then
			e.overlay:Hide()
		end
	end
end

function UI.setLocked(v, quiet)
	if not v and UnitAffectingCombat and UnitAffectingCombat("player") then
		say(L("Not in combat: windows can only be unlocked out of combat."))
		return
	end
	UI.locked = v and true or false
	AegisDB = AegisDB or {}
	AegisDB.locked = UI.locked
	UI.refreshOverlays()
	if not quiet then
		if UI.locked then
			say(L("Locked. Positions are fixed."))
		else
			say(L("Unlocked. Drag the gold fields; releasing snaps them in place."))
		end
	end
end

function UI.setSnap(v)
	UI.snap = v and true or false
	AegisDB = AegisDB or {}
	AegisDB.snap = UI.snap
end

function UI.setGrid(n)
	n = tonumber(n) or 0
	if n < 0 then
		n = 0
	elseif n > 64 then
		n = 64
	end
	UI.grid = math.floor(n)
	AegisDB = AegisDB or {}
	AegisDB.grid = UI.grid
end

function UI.resetAll()
	UI.resetScales()
	for i = 1, table.getn(UI.list) do
		if UI.list[i].reset then
			UI.list[i].reset()
		end
	end
	-- addons without a draggable overlay of their own (chat, ...) hook in here
	UI.resetHooks = UI.resetHooks or {}
	for i = 1, table.getn(UI.resetHooks) do
		pcall(UI.resetHooks[i])
	end
	say(L("Positions reset."))
end

-- /aegis debug fstack: frame inspector. Hover any frame: name, type, size, parent chain, alpha, strata/level.
-- Hold CTRL to pick the frame under the mouse: its name and parent chain open in a copy window
-- (Ctrl+C copies the selection, the 1.12 client has no clipboard API). Plain clicks are not used on
-- purpose: they would also click whatever lies under the cursor.
local fstack
local function describe(f)
	local out = {}
	local name = f:GetName()
	out[1] = "name: " .. tostring(name)
	out[2] = "type: " .. f:GetObjectType()
	out[3] = "size: " .. math.floor((f:GetWidth() or 0) + 0.5) .. " x " .. math.floor((f:GetHeight() or 0) + 0.5)
	out[4] = string.format("alpha: %.2f  scale: %.2f", f:GetAlpha() or 0, f:GetScale() or 1)
	if f.GetFrameStrata then
		out[5] = "strata: " .. tostring(f:GetFrameStrata()) .. "  level: " .. tostring(f:GetFrameLevel())
	end
	local chain = {}
	local p = f:GetParent()
	local n = 0
	while p and n < 6 do
		chain[table.getn(chain) + 1] = tostring(p:GetName() or "?")
		p = p:GetParent()
		n = n + 1
	end
	out[table.getn(out) + 1] = "parents: " .. table.concat(chain, " < ")
	return out
end

function UI.fstack(on)
	if not fstack then
		fstack = CreateFrame("Frame", "AegisFstackFrame", UIParent)
		fstack:SetFrameStrata("TOOLTIP")
		fstack:SetWidth(280)
		fstack:SetHeight(96)
		fstack:EnableMouse(false)
		fstack:SetBackdrop({ bgFile = SOLID, edgeFile = SOLID, tile = false, edgeSize = 1,
			insets = { left = 1, right = 1, top = 1, bottom = 1 } })
		fstack:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
		fstack:SetBackdropBorderColor(0.78, 0.58, 0.22, 1)
		fstack.text = fstack:CreateFontString(nil, "OVERLAY")
		fstack.text:SetFont(FONT_NUM, 11, "OUTLINE")
		fstack.text:SetPoint("TOPLEFT", fstack, "TOPLEFT", 6, -6)
		fstack.text:SetWidth(268)
		fstack.text:SetJustifyH("LEFT")
		fstack:Hide()
		fstack.ctl = false
		fstack:SetScript("OnUpdate", function()
			local f = GetMouseFocus and GetMouseFocus()
			if not f or f == this or f == WorldFrame then
				this.text:SetText("|cffd2a24a/aegis debug fstack|r  " .. L("hover a frame, hold CTRL to copy its name"))
				this:SetHeight(24)
				this.cur = nil
			else
				local lines = describe(f)
				this.cur = f
				this.text:SetText(table.concat(lines, "\n"))
				this:SetHeight(12 * table.getn(lines) + 12)
			end
			local x, y = GetCursorPosition()
			local sc = UIParent:GetEffectiveScale()
			this:ClearAllPoints()
			this:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / sc + 16, y / sc + 16)
			local ctl = IsControlKeyDown() and true or false
			if ctl and not this.ctl and this.cur then
				local lines = describe(this.cur)
				local api = UI.api and UI.api.fonts
				if api and api.showText then
					api.showText(table.concat(lines, "\n"))
				end
			end
			this.ctl = ctl
		end)
	end
	if on == nil then
		on = not fstack:IsShown()
	end
	if on then
		fstack:Show()
		say("fstack: " .. L("hover a frame, hold CTRL to copy its name. /aegis debug fstack stops."))
	else
		fstack:Hide()
	end
end

-- Loading ----------------------------------------------------------------

local core = CreateFrame("Frame")
core:RegisterEvent("ADDON_LOADED")
core:RegisterEvent("PLAYER_ENTERING_WORLD")
core:RegisterEvent("PLAYER_REGEN_DISABLED")
core:RegisterEvent("PLAYER_REGEN_ENABLED")
core:RegisterEvent("DISPLAY_SIZE_CHANGED")
core:RegisterEvent("UI_SCALE_CHANGED")
core.acc = 0
core.fix = 0
core:SetScript("OnEvent", function()
	if event == "PLAYER_REGEN_DISABLED" then
		-- combat: lock automatically, restore afterwards
		if not UI.locked then
			UI.setLocked(true, true)
			core.relock = true
		end
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		if core.relock then
			core.relock = nil
			UI.setLocked(false, true)
		end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" or event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
		core.fix = 2          -- let every module place its frame first, then check bounds
		return
	end
	if arg1 ~= "AegisUI" then
		return
	end
	AegisDB = AegisDB or {}
	if AegisDB.locked ~= nil then
		UI.locked = AegisDB.locked
	end
	if AegisDB.snap ~= nil then
		UI.snap = AegisDB.snap
	end
	if AegisDB.grid ~= nil then
		UI.grid = AegisDB.grid
	end
	UI.refreshOverlays()
end)
-- frames can appear/disappear while unlocked (e.g. the target card): keep the overlays in step
core:SetScript("OnUpdate", function()
	if core.fix > 0 then
		core.fix = core.fix - (arg1 or 0)
		if core.fix <= 0 then
			core.fix = 0
			UI.applyScales()
			UI.sanitizeAll(true)
		end
	end
	core.acc = core.acc + (arg1 or 0)
	if core.acc < 0.5 then
		return
	end
	core.acc = 0
	if not UI.locked then
		UI.refreshOverlays()
	end
end)
