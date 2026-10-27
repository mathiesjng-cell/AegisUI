# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/) (PATCH = fixes and polish, MINOR = features, MAJOR = milestones).

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
