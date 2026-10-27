-- AegisL: tiny shared localisation helper (English source strings, German translations).
-- Every Aegis addon ships this file; the first one loaded defines AegisL, the others only add their
-- own translations. Language: AegisDB.lang = "en" | "de" (hub / "/aegis lang de|en|auto"),
-- otherwise the game client's locale (deDE = German, anything else English).
if not AegisL then
	AegisL = { de = {} }
	function AegisL.lang()
		local l = AegisDB and AegisDB.lang
		if l == "de" or l == "en" then
			return l
		end
		if GetLocale and GetLocale() == "deDE" then
			return "de"
		end
		return "en"
	end
	function AegisL.add(t)
		local k, v
		for k, v in pairs(t) do
			AegisL.de[k] = v
		end
	end
	function AegisL.t(s)
		if AegisL.lang() == "de" then
			local v = AegisL.de[s]
			if v then
				return v
			end
		end
		return s
	end
end

AegisL.add({
	["   Low: "] = "   Tief: ",
	["  (average "] = "  (Schnitt ",
	[" DPS at "] = " DPS bei ",
	[" hits (f=function, t=table)"] = " Treffer (f=Funktion, t=Tabelle)",
	[" s. Change: /aegismeter dps avg|10|60|120 (or click the DPS number). Run log: /aegismeter log [seconds]"] = " s. Aendern: /aegismeter dps avg|10|60|120 (oder Klick auf die DPS-Zahl). Run-Log: /aegismeter log [Sekunden]",
	[" seconds."] = " Sekunden.",
	["). The built-in meter keeps its numbers."] = "). Der eingebaute Meter behaelt seine Zahlen.",
	["AEGISMETER RUN LOG  (interval "] = "AEGISMETER RUN-LOG  (Intervall ",
	["AegisMeter - copy text"] = "AegisMeter - Text kopieren",
	["Click: default / 10 s / 60 s / 120 s"] = "Klick: Standard / 10 s / 60 s / 120 s",
	["DPS time window"] = "DPS-Zeitfenster",
	["DPS window: "] = "DPS-Fenster: ",
	["DPS: average over the whole run."] = "DPS: Durchschnitt ueber den ganzen Lauf.",
	["DPS: default (average over the whole run)."] = "DPS: Standard (Schnitt ueber den ganzen Lauf).",
	["DPS: last "] = "DPS: letzte ",
	["DPS: over the last "] = "DPS: ueber die letzten ",
	["Error: "] = "Fehler: ",
	["Icon scan error: "] = "Fehler beim Icon-Scan: ",
	["No log yet. The log runs automatically during a run (damage per second)."] = "Noch kein Log. Der Log laeuft automatisch im Run mit (Schaden pro Sekunde).",
	["Peak: "] = "Spitze: ",
	["Resets this view."] = "Setzt diese Ansicht zurueck.",
	["Select all"] = "Alles markieren",
	["Select all, then Ctrl+C"] = "Alles markieren, dann Strg+C",
	["The built-in meter keeps its numbers."] = "Der eingebaute Meter behaelt seine Zahlen.",
	["Time    DPS in interval   Change   Top spells (DPS)\n"] = "Zeit    DPS im Intervall   Aenderung   Top-Zauber (DPS)\n",
	["\nTotal: "] = "\nGesamt: ",
	["built-in meter visible: "] = "eingebauter Meter sichtbar: ",
	["line1: "] = "zeile1: ",
	["loaded. /aegismeter for commands; settings via /aegis if AegisUI is installed."] = "geladen. /aegismeter fuer Befehle; Einstellungen ueber /aegis, falls AegisUI installiert ist.",
	["kills"] = "Kills",
	["Kills"] = "Kills",
	["no reset"] = "ohne reset",
	["reset active"] = "reset aktiv",
	["s  display total "] = "s  anzeige total ",
	["window "] = "fenster ",
})
