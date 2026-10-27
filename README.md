# AegisUI

UI-Pack für **Azeroth Survivors** (WoW-1.12-Client, Lua 5.0, Interface 11200). Dunkel, eckig, goldene Akzente.

Das Pack besteht aus vier getrennten Addons, die zusammen ein UI ergeben:

| Addon | Inhalt |
|---|---|
| `AegisUI` | Hub (`/aegis`), Minimap-Button, Lock/Snap, quadratische Minimap, eigene Aktionsleiste + XP-Leiste, Chat-Reskin, Skin-Engine für Fremd-Addons, Profil Export/Import |
| `AegisMeter` | DPS-Meter mit wählbarem DPS-Fenster (Standard / 10 / 60 / 120 s) und Run-Log |
| `AegisNav` | Wegpunkt-Pfeil, Boss-/Guardian-HP-Leiste mit Enrage-Effekt |
| `AegisUnits` | Spieler-/Zielkarten und Nameplates |

Jedes Addon läuft auch einzeln; der Hub zeigt nur, was installiert ist.

## Installation

Die Ordner `AegisUI`, `AegisMeter`, `AegisNav`, `AegisUnits` in `Interface/AddOns` kopieren und das Spiel neu starten (das Spiel liest Addons nur beim Login). `/aegis` öffnet den Hub.

## Befehle

`/aegis`, `/aegis lock|unlock|reset`, `/aegis meter|nav|units [Befehl]`, `/aegis chat`, `/aegis profile`.
Ausführlich: [docs/UEBERSICHT.md](docs/UEBERSICHT.md).

## Credits

- Die Zuordnung Zaubername → Icon in `AegisMeter/AegisIcons.lua` stammt aus **AZSStats** (Slimjim) und **ASBuilder** (Ulaş Çolaker).
- LuckyOdds wird nur umgestaltet (Skin), nicht mitgeliefert. SurvivorUI wird nicht mitgeliefert.
