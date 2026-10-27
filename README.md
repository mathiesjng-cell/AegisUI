# AegisUI

UI-Pack für **Azeroth Survivors** (WoW-1.12-Client, Lua 5.0, Interface 11200). Dunkel, eckig, goldene Akzente.

Das Pack besteht aus vier getrennten Addons, die zusammen ein UI ergeben. Jedes läuft auch einzeln; der Hub zeigt nur, was installiert ist.

| Addon | Inhalt |
|---|---|
| `AegisUI` | Hub (`/aegis`), Minimap-Button, Lock/Snap, quadratische Minimap, eigene Aktionsleiste + XP-Leiste, Chat-Reskin, Skin-Engine für Fremd-Addons, Profil Export/Import |
| `AegisMeter` | DPS-Meter mit wählbarem DPS-Fenster (Standard / 10 / 60 / 120 s) und Run-Log |
| `AegisNav` | Wegpunkt-Pfeil, Boss-/Guardian-HP-Leiste mit Enrage-Effekt |
| `AegisUnits` | Spieler-/Zielkarten und Nameplates |

## Installation

Die Ordner `AegisUI`, `AegisMeter`, `AegisNav`, `AegisUnits` in `Interface/AddOns` kopieren und das Spiel neu starten (das Spiel liest Addons nur beim Login). `/aegis` öffnet den Hub. Nicht benötigte Module einfach weglassen.

## Befehle

`/aegis`, `/aegis lock|unlock|reset`, `/aegis meter|nav|units [Befehl]`, `/aegis chat`, `/aegis profile`. Die langen Befehle `/aegismeter`, `/aegisnav`, `/aegisunits` gibt es zusätzlich.

## Design

| Zweck | Wert (r,g,b,a) |
|---|---|
| Panel | 0.04, 0.05, 0.08, 0.96 |
| Rand | 0.14, 0.16, 0.22, 1 |
| Gold (Akzent) | 0.78, 0.58, 0.22, 1 |
| Zeile | 0.06, 0.07, 0.10, 1 |
| Zeilenrand | 0.17, 0.19, 0.25, 1 |
| Gedimmter Text | 0.49, 0.51, 0.58 |
| Gesundheitsverlauf | Grün (0.10,0.80,0.45) → Orange (0.96,0.62,0.18) → Rot (0.74,0.16,0.26) |

Schriften: FRIZQT (Text mit Outline), ARIALN (Zahlen). Panels sind 1 px umrandet, oben eine goldene Linie.

---

## Funktionen

### AegisUI (Hub + Basis)
- **Hub-Fenster** (`/aegis`, auch `/aegisui`, `/mui`; oder Minimap-Button) mit 3 Tabs:
  - **LAYOUT:** Sperren/Entsperren, Snap, Raster, Quadratische Minimap, „Original ausblenden“ (Spieler-/Zielrahmen, Boss-Leiste, Gryphons + Leistenhintergrund), Reset.
  - **MODULE:** Meter, Nav, Units ein/aus; „Eigene Aktionsleiste + XP-Leiste“; DPS-Zeitfenster (Stepper + Umschalter Standard/10/60/120 s); RUN-LOG ANZEIGEN; Karten-Abstand der Unit-Karten.
  - **SKINS:** dynamische Liste aller registrierten Skins (an/aus), plus „SurvivorUI ersetzen“, falls SurvivorUI installiert ist.
- Fußzeile im Hub: `UI 4.7  Meter 4.7  Nav 4.7  Units 4.7`.
- **Minimap-Button:** an der Karte entlang ziehbar (Shift = frei), Icon `icon.tga`.
- **Lock/Snap:** Alle Fenster (Meter, Karten, Leiste, HP-Leiste, LuckyOdds-Panel …) registrieren sich im Hub; entsperrt kann man sie ziehen, sie rasten am Raster/anderen Fenstern ein.
- **Quadratische Minimap** mit schwarzem 2-px-Rahmen (Schalter im Hub).
- **Eigene Aktionsleiste** (`AegisBars.lua`):
  - 7 Slots (Aktionsslots 1–6 und 12 – nur diese nutzt das Spiel), 34×34 px, dunkles Panel + Goldlinie, verschiebbar.
  - Icons zugeschnitten (0.08–0.92), 1-px dunkler Rahmen, Standard-Buttonrahmen entfernt (auch Bonus-, MultiBar-, Shapeshift- und Pet-Buttons).
  - **XP-Leiste** 1 px über der Leiste: lila Füllung, blauer „Rested“-Bereich, Text „aktuell / max  Prozent“.
  - **Menü-Buttons** (C, T, B, Q, F, M, ESC) als quadratische Buttons in der Leiste, goldener Buchstabe, Hover = goldener Rand. Sie öffnen die Fenster direkt (ToggleCharacter usw.). Die Original-Menübuttons sind unsichtbar.
  - Original-Grafiken (Gryphons, MainMenuBar-Texturen, EndCaps) per Schalter ausgeblendet; der unsichtbare `MainMenuBar`-Rahmen hat die Maus deaktiviert (sonst fängt er Klicks ab).
  - Debug: `/aegis bars` (Zustand der Leiste), `/aegis who` (zeigt den Frame unter der Maus – hilft bei „was liegt da noch“).
- **SurvivorUI-Integration:** Beim ersten Login mit SurvivorUI werden dessen Aktionsleiste, Unit-Frames und Buffs abgeschaltet (Hinweis: /reload). Im Hub wieder umschaltbar.

### AegisUI-Skin-Engine (`AegisSkin.lua`)
Reskinnen fremder Addons „ingame“, ohne deren Code zu kopieren:
- `AegisSkin.RegisterSkin(addonName, label, skinFn, default)` – der Skin wird angewendet, sobald das Addon geladen ist (ADDON_LOADED + PLAYER_LOGIN), mit pcall und Fehlermeldung im Chat.
- Helfer: `ApplyPanel`, `ApplyRow`, `SkinIcon`, `GoldLine`, `StyleText`.
- Schalter pro Skin im Hub (SKINS-Tab), gespeichert in `AegisDB.skins`.
- Vorhanden: **LuckyOdds** (`Skin_LuckyOdds.lua`): dunkles Panel, Goldlinie, umrandete Zeilen, Icon-Rahmen, Schriften/Farben. Der LuckyOdds-Minimap-Button bleibt absichtlich im Original.
- Weitere Addons nach Wunsch (EllesmereUI-Look): einfach neue `Skin_<Addon>.lua` mit `RegisterSkin`.
- Stolperfallen in 1.12: `SetBackdrop` macht zuvor geholte `GetRegions()`-Handles ungültig → danach neu holen und mit pcall arbeiten.

### AegisMeter (DPS-Meter)
- Zeilen pro Zauber mit Icon, Schaden, Anteil, DPS; Ansichten: Schaden / Heilung / Boss / Erlittener Schaden.
- Hover: Schaden, Anteil, DPS, Treffer, Krits. Reset-Knopf, Zeitanzeige, Footer mit TOTAL und DPS.
- **DPS-Zeitfenster:** Klick auf die DPS-Zahl unten rechts schaltet Standard (Schnitt über den ganzen Lauf) → 10 s → 60 s → 120 s. Auch über Hub oder `/aegismeter dps avg|10|60|120` (5–120 s möglich).
- **Run-Log:** läuft automatisch im Run mit (Gesamtschaden pro Sekunde, alle 5 s Zauber-Snapshot), nur im Speicher, wird bei neuem Run geleert. `/aegismeter log [Sekunden]` oder Hub-Knopf: pro Intervall DPS, Änderung in %, Top-3-Zauber; Summe, Spitze, Tief. Textfeld mit Ctrl+C-Kopie.
- **Icons eingebaut:** `AegisIcons.lua` (255 Zaubername → Icon), damit nichts „?“ ist und nichts extern nötig ist.
- Befehle: `/aegismeter` (auch `/ameter`, `/mm`): `reset`, `debug`, `inspect`, `globals [filter]`, `dps …`, `log …`.
- Befund Debug: Die Daten des Spiels laufen korrekt (Gesamtschaden wächst); der Eindruck „steht still“ kam vom Lauf-Schnitt.

### AegisNav (Wegpunkt-Pfeil + Boss-HP-Leiste)
- Pfeil zeigt zum Ziel, exakte Distanz in Yards (aus Spielerposition und Weltkoordinaten).
- Boss-/Guardian-HP-Leiste: dunkles Panel, goldene Linie, 3-stufiger Farbverlauf.
- **Enrage** unter 30 % Boss-HP: pulsierende Füllung (dunkelrot ↔ gold), pulsierender Rand, Label „! ENRAGE !“.
- Boss-Koordinaten fallen auf die Lair-Koordinaten (nach ID) zurück, wenn der Boss keine eigenen hat (ingame noch ungetestet).
- Befehle: `/aegisnav` (auch `/anav`, `/mn`).

### AegisUnits (Spieler-/Zielkarten + Nameplates)
- Karten für Spieler/Ziel im Panel-Stil, Nameplate-Leiste mit Panel-Farben und Goldlinie.
- Kartenabstand einstellbar (Hub).
- Original-Spieler-/Zielrahmen per Schalter ausblendbar.
- Befehle: `/aegisunits` (auch `/aunits`, `/mu`).

---

## Architektur

- **Selbst-Registrierung:** Jedes Modul definiert `hubHook()` (beim Laden und bei PLAYER_LOGIN) → `AegisUI.register(key, label, frame, reset)` und `AegisUI.api.<modul> = { version, … }`. Der Hub baut seine Zeilen bei PLAYER_LOGIN nur für vorhandene `api`-Einträge → jedes Addon läuft auch ohne AegisUI.
- Gespeichert: `AegisDB` (Hub, Skins, Leiste, Minimap), `AegisMeterDB`, `AegisNavDB`, `AegisUnitsDB`.
- Spiel-API (AZS_*): `AZS_GetMeter/GetHealing/GetBossMeter`, `AZS_TAKEN`, `AZS_GetRunTime`, `AZS_GetBosses/Guardians/Lairs`, `AZS_LAIRS`, `AZS_CHESTS`, `AZS_RUN` (px/py in Yards), `AZS_STATS` (Luck). Kartenkoordinaten mx/my (0..1) ≠ Weltkoordinaten x/y (Yards).
- Lua-5.0-Regeln: globale `this`/`arg1`/`event`, kein `#`, kein `select`, kein `string.match`; `math.mod`, `table.getn`, `getglobal`; `string.gsub` gibt 2 Werte; max. 32 Upvalues pro Funktion, max. 200 Locals pro Chunk; Positionen nach PLAYER_LOGIN/ENTERING_WORLD neu setzen; Drag zuverlässig nur über `RegisterForDrag`.

## Bekannte Punkte

- Ingame ungetestet: Boss-Fallback über Lair-ID, Enrage-Visuals, Run-Log mit echten Daten.
- Mögliche nächste Schritte: weitere Skins im EllesmereUI-Stil, alte Slash-Aliase (`/mm`, `/mn`, `/mu`, `/mui`) entfernen, LuckyOdds-Logik als eigenes Modul (Unabhängigkeit).

## Credits

AegisUI ist ein Fan-Projekt für **Azeroth Survivors** (ein Fan-Spiel von Aethus) und steht in keiner Verbindung zu Blizzard Entertainment. Das Pack baut auf den Daten und Schnittstellen anderer Addons auf; die Autoren verdienen Dank:

| Addon / Projekt | Autor | Verwendung in AegisUI |
|---|---|---|
| **AZSStats** | Slimjim | Die Zuordnung Zaubername → Icon in `AegisMeter/AegisIcons.lua` stammt zum Teil aus `AZSStatsIcons.lua`. |
| **ASBuilder** | Ulaş Çolaker | Die Icon-Zuordnung stammt zum Teil aus `Data.lua`. |
| **LuckyOdds** | Cadoky laut README (im `.toc` steht Ulaş Çolaker) | AegisUI gestaltet das Odds-Panel nur um (`Skin_LuckyOdds.lua`). LuckyOdds wird nicht mitgeliefert und nicht kopiert; es muss separat installiert sein. |
| **SurvivorUI** (Standard-UI des Spiels) | Azeroth-Survivors-Team | Wird nicht mitgeliefert. AegisUI kann einzelne Teile davon abschalten und ersetzt sie durch eigene Module. |

Wenn du Autor eines dieser Projekte bist und eine andere Nennung oder Entfernung wünschst, bitte ein Issue aufmachen.
