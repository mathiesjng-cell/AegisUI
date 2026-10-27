# AegisUI

[![Version](https://img.shields.io/badge/version-5.4.14-c8942e)](CHANGELOG.md)
![Interface](https://img.shields.io/badge/interface-11200-555)
![Lua](https://img.shields.io/badge/Lua-5.0-2c2d72)
![Game](https://img.shields.io/badge/Azeroth%20Survivors-WoW%201.12-0a0d14)

A UI pack for **Azeroth Survivors** (WoW 1.12 client, Lua 5.0, Interface 11200). Dark, square, gold accents.

The pack is made of four separate addons that together form one UI. Each one also runs on its own; the hub only shows what is installed.

| Addon | What it does |
|---|---|
| `AegisUI` | Hub (`/aegis`), minimap button, lock/snap, square minimap, custom action bar + XP bar, chat reskin, skin engine for third-party addons, profile export/import |
| `AegisMeter` | DPS meter with a selectable DPS window (default / 10 / 60 / 120 s) and a run log |
| `AegisNav` | Waypoint arrow, boss/guardian HP bar with enrage effect |
| `AegisUnits` | Player/target cards and nameplates |

## Installation

Copy the folders `AegisUI`, `AegisMeter`, `AegisNav` and `AegisUnits` into `Interface/AddOns` and restart the game (the game only reads addons at login). `/aegis` opens the hub. Leave out any module you do not need.

## Languages

The pack speaks **English and German**. By default it follows the game client (German client = German, otherwise English). Override it in the hub (LAYOUT tab, "Language") or with `/aegis lang en|de|auto`, then `/reload`.

## Documentation

[`docs/API.md`](docs/API.md) describes the globals, module API, skin engine, saved variables and commands.

## Commands

All commands start with `/aegis`; the full list is at the bottom of this page.

## Design

| Purpose | Value (r, g, b, a) |
|---|---|
| Panel | 0.04, 0.05, 0.08, 0.96 |
| Border | 0.14, 0.16, 0.22, 1 |
| Gold (accent) | 0.78, 0.58, 0.22, 1 |
| Row | 0.06, 0.07, 0.10, 1 |
| Row border | 0.17, 0.19, 0.25, 1 |
| Dimmed text | 0.49, 0.51, 0.58 |
| Health ramp | green (0.10, 0.80, 0.45) → orange (0.96, 0.62, 0.18) → red (0.74, 0.16, 0.26) |

Fonts: FRIZQT (outlined text), ARIALN (numbers). Panels have a 1 px border and a gold line on top.

## Features

### AegisUI (hub + base)
- **Hub window** with three tabs: LAYOUT (lock/unlock, snap, grid, square minimap, hide original frames, pixel-perfect borders, language, profile export/import, reset), MODULES (meter/nav/units/chat/action bar switches, DPS window, card spacing, run log) and SKINS (all registered skins plus experimental generic skinning of other addons, SurvivorUI replacement).
- **Minimap button**: draggable along the map edge (Shift = free).
- **Lock/snap**: all windows register with the hub; unlocked, they can be dragged and snap to the grid.
- **Square minimap** with a black 2 px border.
- **Custom action bar**: 7 slots (action slots 1–6 and 12, the ones the game uses), XP bar 1 px above it (purple fill, blue rested bar, "current / max  percent"), square menu buttons (C, B, T, Q, F, M, ESC) inside the bar, stock art (gryphons, bar textures) hidden.
- **Chat reskin**: panel behind the chat, transparent chat background, flat Aegis-style tabs (General, Combat Log, …), mouse-wheel scrolling (Shift = page, Ctrl = top/bottom), square edit box with a gold border while typing. Switch with `/aegis chat`.
- **Combat numbers** (`AegisCT.lua`): own floating numbers instead of the client's (which cannot be styled). Hits are summed per target for 0.3 s and shown as one number above the enemy's nameplate; crits are gold and bigger; damage taken rises in red over your character. Modes: Off / Crits only / All hits, three sizes. Enemy nameplates should be on (default key `V`). The number font can be switched to ARIALN (after a restart).
- **Profile export/import**: settings of all four addons as copyable text.
- **Pixel-perfect borders** in the skin engine (1 physical pixel at any resolution and UI scale).
- **SurvivorUI integration**: switches off its action bar, unit frames and buffs when AegisUI replaces them.

### Skin engine (`AegisSkin.lua`)
Reskins other addons in-game without copying their code.
- `AegisSkin.RegisterSkin(addonName, label, skinFn, default)` runs a skin as soon as the addon is loaded, guarded by `pcall`; errors go to the chat. Skins can be switched in the hub.
- Helpers: `ApplyPanel`, `ApplyRow`, `SkinIcon`, `GoldLine`, `StyleText`.
- Included skin: **LuckyOdds** (dark panel, gold line, bordered rows, icon borders, fonts).
- Experimental generic skinning: the hub lists other loaded addons; switched on, AegisSkin guesses the main frame by name, applies the panel and gold line, crops spell icons and sets Aegis fonts. Off by default.
- 1.12 pitfall: `SetBackdrop` invalidates previously fetched `GetRegions()` handles, so re-fetch them afterwards.

### AegisMeter
- Rows per spell with icon, damage, share and DPS; views: damage, healing, boss damage, damage taken.
- Hover shows damage, share, DPS, hits and crits. Reset button, run timer, footer with TOTAL and DPS.
- **DPS window**: click the DPS number in the footer to cycle default (whole-run average) → 10 → 60 → 120 s. Also in the hub or with `/aegismeter dps avg|10|60|120`.
- **Run log**: records damage every second and a per-spell snapshot every 5 s for the current run (memory only; a new run clears it). `/aegismeter log [seconds]` or the hub button shows DPS per interval, change in percent, top three spells, peak and low.
- Spell icons are built in (`AegisIcons.lua`), nothing external needed.

### AegisNav
- Waypoint arrow with exact distance in yards (from the player and world coordinates).
- Boss/guardian HP bar: dark panel, gold line, three-stage colour ramp.
- **Enrage** below 30 % boss HP: pulsing fill, pulsing border, "! ENRAGE !" label.
- A short gold flash on the arrow whenever a new target is logged.
- Boss coordinates fall back to lair coordinates (by id) when a boss has none of its own.

### AegisUnits
- Player and target cards in the panel style, nameplate bar with panel colours and a gold line.
- Adjustable card spacing; the original player/target frames can be hidden.

## Architecture

- **Self-registration**: each module defines `hubHook()` (called at load and again at PLAYER_LOGIN), which calls `AegisUI.register(key, label, frame, reset)` and fills `AegisUI.api.<module>`. The hub builds its rows at PLAYER_LOGIN only for modules that are present, so every addon works without AegisUI.
- **Localisation**: every addon ships `Locale.lua` (`AegisL`). English strings are the source; `AegisL.add({ ["English"] = "Deutsch" })` adds translations; `L = AegisL.t`.
- **Saved variables**: `AegisDB` (hub, skins, bar, minimap, language), `AegisMeterDB`, `AegisNavDB`, `AegisUnitsDB`.
- **Game API** (AZS_*): `AZS_GetMeter/GetHealing/GetBossMeter`, `AZS_TAKEN`, `AZS_GetRunTime`, `AZS_GetBosses/Guardians/Lairs`, `AZS_LAIRS`, `AZS_CHESTS`, `AZS_RUN`, `AZS_STATS`. Map coordinates mx/my (0..1) are not the world coordinates x/y (yards).
- **Lua 5.0 rules**: globals `this`/`arg1`/`event`; no `#`, no `select`, no `string.match`; use `table.getn`, `math.mod`, `getglobal`; `string.gsub` returns two values; at most 32 upvalues per function and 200 locals per chunk.

## Known points

- Not yet verified in game: the boss lair fallback, the enrage visuals and the run log with real data.
- Ideas: more skins in an EllesmereUI style, minimap-button orbit correction for single known addons.

## Credits

AegisUI is a fan project for **Azeroth Survivors** (a fan game by Aethus) and is not affiliated with Blizzard Entertainment. It builds on the data and interfaces of other addons, and their authors deserve thanks:

| Addon / project | Author | Use in AegisUI |
|---|---|---|
| **AZSStats** | Slimjim | Part of the spell name → icon mapping in `AegisMeter/AegisIcons.lua` comes from `AZSStatsIcons.lua`. |
| **ASBuilder** | Ulaş Çolaker | Part of the icon mapping comes from `Data.lua`. |
| **LuckyOdds** | Cadoky per its README (its `.toc` lists Ulaş Çolaker) | AegisUI only restyles the odds panel (`Skin_LuckyOdds.lua`). LuckyOdds is not included or copied; install it separately. |
| **SurvivorUI** (the game's default UI) | Azeroth Survivors team | Not included. AegisUI can switch off parts of it and replaces them with its own modules. |

If you are the author of one of these projects and want a different credit or removal, please open an issue.

## Commands (full reference)

Every module has its own full command; `/aegis meter|nav|units <command>` forwards to it, so `/aegis meter log` and `/aegismeter log` do the same.

### `/aegis` (hub and general)

| Command | Description |
|---|---|
| `/aegis` | Open or close the hub window. |
| `/aegis lock` | Lock all windows in place. |
| `/aegis unlock` | Unlock: gold fields appear, drag windows, they snap to the grid on release. |
| `/aegis reset` | Reset all window positions. |
| `/aegis meter\|nav\|units [command]` | Forward a command to that module (without a command: meter and nav toggle their window, units prints its help). |
| `/aegis chat` | Switch the chat reskin on or off (off takes effect after `/reload`). |
| `/aegis profile` | Open the profile window: export or import all settings as text. |
| `/aegis lang en\|de\|auto` | Set the language (English, German, or follow the game client); then `/reload`. |
| `/aegis cttest` | Show test numbers (white, gold crit, red damage taken). |
| `/aegis ct` | Debug: combat-text CVars and globals. |
| `/aegis ct2` | Debug: 15 s capture of combat events and nameplate frames, result in a copyable window. |
| `/aegis slot` | Debug: state of each action slot (usable, cooldown, colour). |
| `/aegis slotparts [n]` | Debug: textures and children of action button n, in a copyable window. |
| `/aegis fix` | Move windows that ended up off screen back onto it. |
| `/aegis bars` | Debug: state of the custom action bar. |
| `/aegis who` | Debug: shows the name of the frame under the mouse; run it again to stop. |

### `/aegismeter` (DPS meter)

| Command | Description |
|---|---|
| `/aegismeter` | Show or hide the meter. |
| `/aegismeter reset` | Reset the current view (the game's own meter keeps its numbers). |
| `/aegismeter dps avg\|10\|60\|120` | DPS window: whole-run average or the last N seconds (5–120 s possible). Without a value it prints the current window. |
| `/aegismeter log [seconds]` | Show the run log of the current run; optional interval length in seconds (minimum 5, default 10). |
| `/aegismeter debug` | Print what the game hands to the meter (run it twice in combat, a few seconds apart). |
| `/aegismeter inspect` | Dump the game's data tables (bosses, guardians, lairs, run) into a copy window. |
| `/aegismeter globals [filter]` | List the game's `AZS_*` API functions, or everything matching the filter. |

### `/aegisnav` (waypoint arrow, boss HP bar)

| Command | Description |
|---|---|
| `/aegisnav` | Show or hide the arrow. |
| `/aegisnav next` | Switch to the next target manually. |
| `/aegisnav auto` | Back to automatic target choice (fighting guardian, chest, guardian, lair). |
| `/aegisnav aspect <n>` | Map aspect ratio used for the direction. |
| `/aegisnav yards <n>` | Map width in yards (only for the distance display when no world coordinates exist). |
| `/aegisnav hud <name> on\|off` | Show or hide one of the game's own HUD parts (for example the original boss bar). |
| `/aegisnav info` | Debug: list all targets with coordinates and state. |

### `/aegisunits` (player/target cards, nameplates)

| Command | Description |
|---|---|
| `/aegisunits player on\|off` | Player card on or off. |
| `/aegisunits target on\|off` | Target card on or off. |
| `/aegisunits gap <pixels>` | Distance of the two cards from the screen centre (default 110). |
| `/aegisunits plates on\|off` | Nameplate bars on or off (fully active after `/reload`). |
| `/aegisunits stock on\|off` | Show or hide the game's default player and target frames. |
