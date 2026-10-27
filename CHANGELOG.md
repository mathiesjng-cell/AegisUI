# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/) (PATCH = fixes and polish, MINOR = features, MAJOR = milestones).

## [Unreleased]
### Added
- Nav: chests are only arrow targets while the run gold covers the next cache (`AZS_RUN.gold >= AZS_RUN.chest`)
- Timer widget (`AegisTimerFrame`, draggable, scalable, hub toggle): session clock, next boss, soonest lair fill
- Timer widget: the session clock survives /reload (new session after a gap of more than 2 minutes)
- Nameplates: at most 10 full plates (target > boss/elite > screen centre), the rest shrinks and dims to 20 % (bar and texts only); trash fades to 20 % while a boss or guardian is up (both configurable in the hub)
- Hub: DPS time window moved to the top of the Meter page
- Reset defaults now also puts the chat back to the bottom-left corner (default size) and docks LuckyOdds to its right edge again (`UI.resetHooks`)
- Hub: toggle "Original skill / jewelry rows" (hides the game's `build` HUD part)
- `/aegis fstack`: frame inspector. Hover shows name, type, size, alpha, scale, strata/level and the parent chain; holding CTRL opens a copy window with that text (Ctrl+C copies; plain clicks are not used so nothing underneath is triggered).
- `/aegis debug [tool]`: all internal diagnostics in one place (fstack, who, bars, ct, ct2, cttest, slot, slotparts, mapdiag, targetcard, fix). The old direct commands keep working.
- Inset look for status bars (`AegisSkin.Bevel`): dark line under the top edge, faint light line above the bottom edge, soft vertical gradient. Used on the XP bar and the unit card bars.
- Level-up: a small gold arrow rises above the player card for 2 s and fades out (`PLAYER_LEVEL_UP`).
- Smooth nav arrow: the update step only sets the wanted angle, the arrow turns towards it every frame along the shortest way round.
- DoT ticks in "crits only" mode: shown small and dimmed to 60 % (hub switch, `AegisDB.ct.dots`, default on). No class check: in this client DoTs arrive as their own periodic events.
- Nameplates: hostile bars use a muted crimson instead of neon red, non-target bars are 85 % opaque (the bar, never the plate frame, so target detection by alpha keeps working), fonts 1 pt smaller, inset bevel on the bar.
- Login banner (version and modules, 20 % dark background, 6 s). `/aegis banner` switches it off and on.
### Changed
- Defaults: chat pinned bottom-left on first start, the LuckyOdds window docks to the chat's right edge while it has no saved position, the meter sits bottom-right with 7 rows. The game's own damage meter and its minimap button are hidden (`AegisMeterDB.showStock = true` keeps them).
- Release strategy: no version bump for dev commits; the version changes only for a release tag.

## [5.9.2] - 2026-10-27
### Changed
- Meter header: run timer and title text ("Overall Damage") are off by default; both can be switched on again in the hub (`AegisMeterDB.showTimer` / `showTitle`).

## [5.9.1] - 2026-10-27
### Fixed
- Clean minimap no longer touches the player arrow and the map markers (guardian lairs, red flag): only real buttons with a ring texture are flattened, Models are skipped. Before, the arrow was pushed to the map's corner and the markers disappeared.

## [5.9.0] - 2026-10-27
### Added
- Resizable windows: every registered Aegis window (meter, player and target card, nav arrow, action bar, LuckyOdds window) scales 50-250 %. While unlocked each window shows a gold "+" grip in its bottom-right corner; dragging it resizes. The hub (Core page, WINDOW SIZE) has a stepper per window. Saved in `AegisDB.scales[key]`; "Reset positions" and the Core "Reset defaults" restore size 100 %.
- `AegisUI.register(key, label, frame, reset, onScale)` takes an optional scale callback; new core functions `getScale`, `setScale`, `setScaleSaved`, `applyScales`, `resetScales`.
### Changed
- Unit cards compute their gap and height in screen units, so they stay symmetric when scaled.
- The stock action buttons follow the bar's scale.

## [5.8.0] - 2026-10-27
### Added
- Chat: +50 x +60 px on first start, width/height steppers in the hub (Chat page) and a gold "+" grip at the top-right corner while unlocked for free resizing (`AegisDB.chatW/chatH`).
- Minimap size (60-200 %) in the hub; the buttons scale with the map (`MinimapCluster:SetScale`).
- AZSStats' minimap button now slides along the square map's edge; Shift + drag places it freely (`AegisDB.azsAngle` / `azsFree`).
### Changed
- The 2 s limit on cooldown sweeps is gone for good: every sweep runs as the game draws it. The hub switch is removed.
- The Aegis Nav box only catches the mouse while the layout is unlocked, so clicks and camera work through it.

## [5.7.3] - 2026-10-27
### Fixed
- Minimap buttons of other addons (LuckyOdds, AZSStats): the icon is now found by its `Interface\Icons` texture, every other texture (ring, background) is cleared instead of only hidden. `/aegis mapdiag` also lists the textures of those buttons.

## [5.7.2] - 2026-10-27
### Fixed
- The zoom buttons are back: small flat +/- squares in the map's bottom-right corner (the wheel still zooms).
- Round addon buttons parked next to the map (parented to UIParent) are flattened as well.

## [5.7.1] - 2026-10-27
### Changed
- Clean minimap is now on by default and also restyles the buttons around the map: round gold rings removed, flat square dark frames with a gold edge, buttons moved onto the edge of the square map. Close X, world map button, calendar sun and zoom buttons are hidden (the wheel zooms).
### Added
- `/aegis mapdiag`: lists the minimap's child frames in a copy window.

## [5.7.0] - 2026-10-27
### Added
- Per-module font size (8-24 px, 12 = original sizes, all texts scale proportionally) and font choice (Default, Arial Narrow, Friz Quadrata, Morpheus, Skurri) for Meter and Units (`AegisSkin.GetFont/RefreshFonts`, keys `fsize` / `fontp`). Reset Defaults restores the original fonts.
### Not included
- Chat and action bar have no font setting (chat fonts belong to the game's chat settings).

## [5.6.0] - 2026-10-27
### Added
- Hub rebuilt: a flat module list on the left (Core, Meter, Units, Fonts, Chat, Minimap, Skins) and a scrollable control panel on the right with 1 px gold separators between Opacity, Colors and Contrast.
- Per-module appearance (`AegisDB.looks[module]`): background opacity, border opacity, "force solid dark background" (98 %), border and background colour presets, black outline toggle, and a **Reset Defaults** button on every page. Modules: Core (action bar), Meter, Units (cards, background only), Chat.
- Nameplates: elite, boss and guardian plates get a small gold crown (built from textures) on the bar's top-left corner; a subtle gold inner glow appears while a boss or guardian is targeted.
### Changed
- The old global appearance block is replaced by the per-module look; saved global values still act as the fallback.
### Not included
- Header text colour, font size and font choice per module, and the health-bar flash.

## [5.5.0] - 2026-10-27
### Added
- Appearance settings (hub, LAYOUT tab): background opacity (50-100 %), border opacity, black outline on/off, reset. Chat panel, meter and action bar follow them live (`AegisSkin.GetLook/SetLook/ResetLook/TrackPanel/RefreshLook`).
- Hub tabs scroll with the mouse wheel when their content is longer than the window.
- Target card dimming: the card fades (alpha only) between 0.15 and 1 over 0.15 s and is fully visible only for bosses and guardians. Hub toggle and `/aegis targetcard [toggle]`.
- Meter header: kill counter right-aligned ("Kills: 1.2k"), run timer can be switched off; minimum width 220 px.
- Clean minimap option: no zoom buttons, mouse wheel zooms, zone name in the Aegis font.
- Combat guard: windows lock automatically when combat starts and unlock again afterwards; unlocking in combat is refused.

### Changed
- The action bar panel uses the solid look (neutral near-black with outline).

## [5.4.14] - 2026-10-27
### Added
- Action bar: "Never dim action icons" (the game's self-casting spells flip between usable and not usable all the time, which blacked out the Auto Shot slot) and "Hide short cooldown sweeps (< 2 s)". Both on by default.
- Diagnostics `/aegis slot` and `/aegis slotparts [n]` (textures and children of an action button, in a copyable window).

## [5.4.7] - [5.4.11] - 2026-10-27
### Changed
- Combat numbers: only enemies with a visible nameplate get a number, at most 6 per 0.3 s (crits first, then the biggest); numbers no longer run into each other; large values are shortened (1.1k, 28.8k, 500k, 1.2M, 5.0B); with several enemies of the same name the number goes to the target's plate, else the plate closest to the hero.

## [5.4.6] - 2026-10-27
### Changed
- Target card shows what the enemy is to the run (FINAL BOSS / BOSS / GUARDIAN / ELITE) via `AZS_UnitKind`, with the old classification as fallback.
- The target's nameplate gets the gold caps for any special enemy.

## [5.4.5] - 2026-10-27
### Added
- `docs/API.md`: reference for the pack's globals, module API, skin engine, saved variables and commands (same layout as the game's addon documentation).

### Changed
- Kill counter reads the game's `AZS_RUN.kills` (falls back to counting "dies" messages).

## [5.4.4] - 2026-10-27
### Changed
- Combat numbers: crit colour amber `#FFB100`, 1 px black shadow on top of the thick outline.
- Chat panel and meter: neutral `#0A0A0A` at 96 % opacity, 1 px black outline outside the border (`AegisSkin.ApplySolid`, `AegisSkin.OuterBlack`).

## [5.4.3] - 2026-10-27
### Added
- Bounds check for all registered windows (after login, resolution/scale changes and after dragging); `/aegis fix` runs it by hand.

## [5.4.2] - 2026-10-27
### Added
- Meter layout settings: number of rows (3-10), width (260-520 px), title on/off, kill counter (counts "dies" messages of the combat log).

## [5.4.1] - 2026-10-27
### Added
- Target card edge colour by reaction (hostile / neutral / friendly / dead).
- Nameplates: gold caps for elite enemies, larger plate with a bright edge for the target.

## [5.4.0] - 2026-10-27
### Added
- `AegisCT`: own floating combat numbers (Off / Crits only / All hits, three sizes, test numbers via `/aegis cttest`). Hits are summed per target for 0.3 s, shown above the enemy nameplate; crits gold and bigger; damage taken in red over the character.
- Hub: combat-number controls in the MODULES tab.

### Changed
- The old "Damage numbers over enemies" switch is hidden while `AegisCT` is loaded; `AegisCT` switches the client's own numbers off and restores them when set to Off.

## [5.3.1] - 2026-10-27
### Added
- `/aegis ct2`: 15 s capture of combat events and nameplate frames (diagnostic).

## [5.3.0] - 2026-10-27
### Added
- `AegisFonts`: switches for the client's damage and healing numbers and an ARIALN number font (applies after a restart).
- `/aegis ct`: combat-text diagnostic.

## [5.2.2]
### Added
- `/aegis chat on|off` with a confirmation message.

## [5.2.0] - [5.2.1]
### Fixed
- Chat text was hidden behind the reskin panel; the panel now sits below the chat frame (strata/level sync).

## [5.1.0]
### Added
- Chat tabs (General, Combat Log, ...) reskinned with a gold underline for the selected tab.

## [5.0.0]
### Added
- English and German localisation for all four addons (`/aegis lang`).
- Profile export/import, generic skinning of other addons (experimental), pixel-perfect borders.
- Run log and selectable DPS window in the meter; waypoint flash in the nav arrow.
- English README with full command reference and credits.

## [4.x]
- Custom action bar, XP bar and square menu buttons; chat reskin; skin engine with LuckyOdds skin; hub with lock/snap; AegisMeter, AegisNav, AegisUnits.
