# AegisUI Pack: Addon API

Reference for the four Aegis addons (`AegisUI`, `AegisMeter`, `AegisNav`, `AegisUnits`): the
globals, saved variables, module API, skin engine and slash commands. It follows the layout of the
game's own addon documentation (Azeroth Survivors: Addon API).

All addons are ordinary 1.12 addons (`## Interface: 11200`, Lua 5.0). Every module also works on
its own; the hub only shows the modules that are installed.

---

## Contents

1. [Conventions](#conventions)
2. [Game API used](#game-api-used)
3. [Core (`AegisUI`)](#core-aegisui)
4. [Module API (`AegisUI.api`)](#module-api-aegisuiapi)
5. [Skin engine (`AegisSkin`)](#skin-engine-aegisskin)
6. [Localisation (`AegisL`)](#localisation-aegisl)
7. [Saved variables](#saved-variables)
8. [Slash commands](#slash-commands)
9. [Examples](#examples)

---

## Conventions

- **Versions:** SemVer (`MAJOR.MINOR.PATCH`). All four addons carry the same version; it is in each
  `.toc`, in `AegisHub.lua` (`VERSION`), in the meter's load message and in `api.<module>.version`.
- **Lua 5.0:** `this`, `event`, `arg1`…, `table.getn`, `math.mod`, `string.find` (no `#`, `select`,
  `string.match`, `string.gmatch`); at most 32 upvalues per function and 200 locals per chunk.
- **Self-registration:** a module calls `hubHook()` at load and on `PLAYER_LOGIN`; it registers its
  frame with `AegisUI.register(...)` and publishes `AegisUI.api.<module>`. Without AegisUI it runs
  anyway.
- **Pixel size:** use `AegisSkin.px()`, not a fixed `1`, for borders.
- **Keys vs. labels:** register labels and similar strings stay English in code and are translated
  at display time with `L(...)`.

---

## Game API used

The addons read the run through the game's `AZS_*` API (see the game's addon documentation).

| used | by | for |
|---|---|---|
| `AZS_GetMeter()`, `AZS_GetHealing()`, `AZS_GetBossMeter()` | AegisMeter | the meter rows and totals |
| `AZS_TAKEN` | AegisMeter | damage taken, by source |
| `AZS_GetRunTime()` | AegisMeter | timer badge, DPS windows, run log |
| `AZS_RUN.kills` | AegisMeter | kill counter (falls back to counting "dies" messages of the combat log) |
| `AZS_SPELLS` | AegisMeter | cooldown bar under the spell icon |
| `AZS_GetPhase()`, `AZS_GetUpcomingBosses()`, `AZS_SCHEDULE`, `AZS_UNITS`, `AZS_ZONE` | AegisMeter | `/aegismeter inspect` and `globals` diagnostics |
| `AZS_GetBosses()`, `AZS_GetGuardians()` | AegisNav, AegisMeter (debug) | boss/guardian HP bar, arrow targets |
| `AZS_GetLairs()`, `AZS_LAIRS`, `AZS_GetFlaggedLair()` | AegisNav | arrow targets (`mx`, `my`, `x`, `y`) |
| `AZS_RUN.px`, `.py` | AegisNav | the hero's position in yards, for exact distances |
| `AZS_CHESTS` | AegisNav | cache targets |
| `AZS_HUD_CVARS`, `AZS_SetHudShown()`, `AZS_IsHudShown()` | AegisUI, AegisNav | hiding the game's HUD parts that Aegis replaces |
| `AZS_UnitKind(unit)` | AegisUnits | target card label (final / boss / guardian / elite), gold caps on the target's nameplate |
| `UnitClassification()`, `UnitIsEnemy()`, `UnitIsFriend()` | AegisUnits | elite marker, card edge colour (fallback and edge colour) |

Combat events used (not part of the AZS API): `CHAT_MSG_SPELL_SELF_DAMAGE`,
`CHAT_MSG_COMBAT_SELF_HITS`, `CHAT_MSG_SPELL_PERIODIC_*_DAMAGE`, `CHAT_MSG_COMBAT_*VS_SELF_HITS`,
`CHAT_MSG_COMBAT_HOSTILE_DEATH`.

---

## Core (`AegisUI`)

### `AegisUI` (global table)

| field | type | meaning |
|---|---|---|
| `locked` | boolean | windows are locked in place |
| `snap` | boolean | snapping on release |
| `grid` | number | grid size in px (0 = off, max 64) |
| `thresh` | number | snap distance to guide lines, px |
| `list` | table | registered frames: `{ key, label, frame, reset }` |
| `api` | table | module API, see below |

### Functions

#### `AegisUI.register(key, label, frame, reset)`
Registers a movable frame. `label` is shown on the unlock overlay (translated), `reset` is called
by `AegisUI.resetAll()`. The frame must have `OnDragStart`/`OnDragStop` scripts (the overlay hands
the drag to them) and call `AegisUI.snapFrame(frame)` on drop.

#### `AegisUI.snapFrame(frame)`
Snaps to screen edges/centre and to the edges of the other registered frames (within `thresh`), else
to the grid, then keeps the frame on screen.

#### `AegisUI.clampFrame(frame)` → `moved`
Moves a frame back so its centre is on screen. `true` when it was moved.

#### `AegisUI.sanitizeAll(quiet)` → `n`
Runs `clampFrame` on every registered frame. Runs by itself 2 s after entering the world and after a
resolution or scale change; `/aegis fix` runs it by hand.

#### `AegisUI.setLocked(v, quiet)` / `AegisUI.setSnap(v)` / `AegisUI.setGrid(n)` / `AegisUI.resetAll()` / `AegisUI.refreshOverlays()`
Set or apply the layout state. Values are saved in `AegisDB`.

---

## Module API (`AegisUI.api`)

Each module publishes a table of getters/setters; the hub builds its rows from them. Setters save
into the module's own saved variable.

### `api.meter` (AegisMeter)

| function | meaning |
|---|---|
| `version` | version string |
| `isShown()` / `setShown(on)` | meter window visible |
| `cycleDps()` | next DPS window preset (default, 10, 60, 120 s) |
| `getDps()` / `setDps(n)` | DPS window in seconds, `0` = whole run |
| `showLog()` | open the run log |
| `getRows()` / `setRows(n)` | rows shown, 3 to 10 |
| `getWidth()` / `setWidth(n)` | window width, 260 to 520 px |
| `getTitle()` / `setTitle(on)` | title text in the header |
| `getKills()` / `setKills(on)` | kill counter in the header (right-aligned) |
| `getTimer()` / `setTimer(on)` | run timer badge in the header |

### `api.nav` (AegisNav)

| function | meaning |
|---|---|
| `version` | version string |
| `isShown()` / `setShown(on)` | arrow and boss bar visible |
| `getHudHidden(name)` / `setHudHidden(name, hidden)` | hide a part of the game's HUD (`bosses`, `flag`, …) |

### `api.units` (AegisUnits)

| function | meaning |
|---|---|
| `version` | version string |
| `getPlayer()` / `setPlayer(on)` | player card |
| `getTarget()` / `setTarget(on)` | target card |
| `getPlates()` / `setPlates(on)` | nameplate restyle |
| `getStockHidden()` / `setStockHidden(hide)` | hide the stock player/target frames |
| `getGap()` / `setGap(n)` | distance of each card from the screen centre, px |
| `getTargetFade()` / `setTargetFade(on)` | dim the target card (alpha 0.15) unless the target is a boss or guardian |

### `api.bars`, `api.map`, `api.survivor`, `api.chat`, `api.ct`, `api.fonts` (AegisUI)

| module | function | meaning |
|---|---|---|
| `bars` | `getCustom()` / `setCustom(v)` | own action bar and XP bar |
| `bars` | `getArt()` / `setArt(v)` | hide gryphons and bar textures |
| `bars` | `getSkin()` / `setSkin(v)` | skin the stock buttons |
| `bars` | `getNoDim()` / `setNoDim(v)` | keep action icons at full brightness |
| `bars` | `getShortCd()` / `setShortCd(v)` | hide cooldown sweeps shorter than 2 s |
| `map` | `getSquare()` / `setSquare(v)` | square minimap |
| `map` | `getClean()` / `setClean(v)` | no zoom buttons, wheel zoom, Aegis zone font |
| `survivor` | `getOff(key)` / `setOff(key, off)` | switch off a part of SurvivorUI |
| `chat` | `isOn()` / `setOn(on)` | chat reskin (off takes effect after `/reload`) |
| `chat` | `debugTabs()` | print tab geometry |
| `ct` | `getMode()` / `cycleMode()` | combat numbers: `off`, `crit`, `all` |
| `ct` | `getSize()` / `cycleSize()` | `small`, `medium`, `large` |
| `ct` | `test()` | show test numbers |
| `fonts` | `getHealing()` / `setHealing(on)`, `hasHealing()` | the client's healing numbers (CVar `CombatHealing`) |
| `fonts` | `getFont()` / `setFont(on)` | ARIALN as number font (after a restart) |
| `fonts` | `getDamage()` / `setDamage(on)` | the client's damage numbers (CVar `CombatDamage`) |
| `fonts` | `diag()` | `/aegis ct2` capture |
| `fonts` | `showText(text)` | open the copyable diagnostics window |

---

## Skin engine (`AegisSkin`)

Restyles other addons without copying their code.

### `AegisSkin.color`

| key | value (r, g, b, a) |
|---|---|
| `panel` | 0.04, 0.05, 0.08, 0.96 |
| `solid` | 0.04, 0.04, 0.04, 0.96 (neutral, for chat and meter over bright ground) |
| `edge` | 0.14, 0.16, 0.22, 1 |
| `row` / `rowEdge` | 0.06, 0.07, 0.10, 1 / 0.17, 0.19, 0.25, 1 |
| `gold` | 0.78, 0.58, 0.22, 1 |
| `dim` | 0.49, 0.51, 0.58, 1 |

### Functions

| function | meaning |
|---|---|
| `px()` | size of one physical pixel in UI units |
| `RegisterSkin(addonName, label, skinFn, defaultState)` | skin applied once the addon is loaded (pcall, errors go to chat) |
| `GetLook(module)` → `bg, edge, outer, solid, bgPreset, edgePreset` | appearance of one module (`core`, `meter`, `units`, `chat`); falls back to the global `AegisDB.look` |
| `SetLook(key, value, module)` / `ResetLook(module)` | change (`bg`, `edge`, `outer`, `solid`, `bgp`, `edgep`) or reset; panels follow live |
| `TrackPanel(frame, bgRGB, edgeRGB, outlineTextures, module, noEdge)` / `RefreshLook()` | let a panel follow the module's appearance settings (`noEdge` leaves the border colour alone) |
| `EDGE_PRESETS` / `BG_PRESETS` | colour presets `{name, r, g, b}`; index 1 keeps the panel's own colour |
| `ApplyPanel(frame)` / `ApplySolid(frame, module)` | panel backdrop and border; `ApplySolid` uses the neutral `solid` colour |
| `OuterBlack(frame)` | 1 px black outline outside the edge |
| `ApplyRow(frame)` | darker bordered row or button |
| `SkinIcon(texture)` | crop and frame an icon |
| `GoldLine(frame)` | thin gold line at the top edge |
| `StyleText(fs, kind, size, r, g, b)` | font and colour of a font string |
| `IsEnabled(addon)` / `SetEnabled(addon, on)` / `ApplySkin(addon)` / `IsLoaded(addon)` | skin state |
| `Discover()` | list of loaded third-party addons with skinnable frames (experimental) |
| `SkinGenericFrame(frame)` / `GenericEnabled(addon)` / `SetGeneric(addon, on)` | generic skinning of other addons |

1.12 pitfall: `SetBackdrop` invalidates `GetRegions()` handles fetched earlier; fetch them again
afterwards.

---

## Localisation (`AegisL`)

Every addon ships `Locale.lua`; the first one loaded defines `AegisL`, the others add their strings.

| function | meaning |
|---|---|
| `AegisL.lang()` | `"en"` or `"de"`: `AegisDB.lang`, else the client locale (`deDE` = German) |
| `AegisL.add(table)` | add German translations: `{ ["English source"] = "Deutsch" }` |
| `AegisL.t(text)` | translated text (the English source when none exists) |

Usage: `local L = AegisL.t`; source strings are English, German values live in `Locale.lua`.

---

## Saved variables

### `AegisDB` (AegisUI)

| field | meaning |
|---|---|
| `locked`, `snap`, `grid` | layout state |
| `lang` | `"en"`, `"de"` or nil (auto) |
| `look` | appearance: `bg` (50-100), `edge` (0-100), `outer` (false = no outline) |
| `mapClean` | clean minimap on |
| `pixel` | pixel-perfect borders |
| `square` | square minimap |
| `chat` | `false` = chat reskin off |
| `tab2` | last open hub page |
| `looks` | per-module appearance `{ [module] = { bg, edge, outer, solid, bgp, edgep } }` |
| `hub` | `{ point, rel, x, y }` hub window position |
| `angle`, `free` | minimap button position (angle on the edge, or free `{ x, y }`) |
| `skins`, `generic` | skin switches per addon |
| `bars` | action bar settings (`custom`, `skin`, `hideArt`, `noDim`, `shortCd`, position) |
| `ct` | combat numbers: `mode`, `size`; `owned`, `prev` remember the client's CVar |
| `dmgFont` | `false` = keep the stock number font |
| `svDone` | SurvivorUI hand-over done |

### `AegisMeterDB`

`point, rel, x, y` (position), `mode` (`damage`, `healing`, `boss`, `taken`), `hidden`,
`dpsWindow` (seconds, `0` = whole run), `rows` (3–10), `width` (260–520), `noTitle`, `noKills`,
`noTimer`, `dump` (last text window, not exported).

### `AegisNavDB`

`point, rel, x, y`, `hidden`, `hud` (hidden game HUD parts), `aspect`, `yards`.

### `AegisUnitsDB`

`player`, `target`, `plates` (switches), `fade` (dim target card), `stock` (hide stock frames), `gap`, `bottom` (card layout).

Profile export/import (`/aegis profile`) writes all four tables as one `AEGIS1:` text (meter `dump`
left out).

---

## Slash commands

| command | module |
|---|---|
| `/aegis`, `/aegisui` | hub, layout, chat, profile, language, diagnostics |
| `/aegismeter` | DPS meter |
| `/aegisnav` | waypoint arrow, boss bar |
| `/aegisunits` | cards, nameplates |

The full list with descriptions is in the README (section "Commands (full reference)").

---

## Examples

### A module that registers with the hub

```lua
local frame = CreateFrame("Frame", "MyModuleFrame", UIParent);
frame:SetMovable(true);
frame:RegisterForDrag("LeftButton");
frame:SetScript("OnDragStart", function()
	if ( AegisUI and AegisUI.locked ) then return; end
	this:StartMoving();
end);
frame:SetScript("OnDragStop", function()
	this:StopMovingOrSizing();
	if ( AegisUI ) then AegisUI.snapFrame(this); end
end);

local function hubHook()
	if ( not AegisUI or AegisUI.hooked_my ) then return; end
	AegisUI.hooked_my = true;
	AegisUI.register("my", "My Module", frame, function()
		frame:ClearAllPoints();
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	end);
	AegisUI.api.my = {
		version = "1.0.0",
		isShown = function() return frame:IsShown(); end,
		setShown = function(on) if ( on ) then frame:Show(); else frame:Hide(); end end,
	};
end
hubHook();
local ev = CreateFrame("Frame");
ev:RegisterEvent("PLAYER_LOGIN");
ev:SetScript("OnEvent", hubHook);
```

### Skinning another addon

```lua
AegisSkin.RegisterSkin("SomeAddon", "Some Addon", function()
	AegisSkin.ApplySolid(SomeAddonFrame);
	AegisSkin.OuterBlack(SomeAddonFrame);
	AegisSkin.GoldLine(SomeAddonFrame);
end, true);
```

### Translating a string

```lua
local L = AegisL.t;
AegisL.add({ ["Kill counter"] = "Kill-Zähler" });
DEFAULT_CHAT_FRAME:AddMessage(L("Kill counter"));
```
