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
	["  (running)"] = "  (laufen)",
	[" (active)"] = " (aktiv)",
	[" (combat)"] = " (Kampf)",
	[" targets, heading "] = " Ziele, Heading ",
	[" visible: "] = " sichtbar: ",
	[" yd (only used for the distance display)"] = " yd (nur fuer die Entfernungsanzeige)",
	["AZS_SetHudShown is missing in this client."] = "AZS_SetHudShown fehlt in diesem Client.",
	["Arrow / boss HP"] = "Pfeil / Boss-HP",
	["Automatic target (fighting guardian, chest, guardian, lair)."] = "Automatisches Ziel (kaempfender Guardian, Truhe, Guardian, Lair).",
	["Chest"] = "Truhe",
	["Error: "] = "Fehler: ",
	["Map aspect ratio "] = "Karten-Seitenverhaeltnis ",
	["Map width "] = "Kartenbreite ",
	["Target changed. /aegisnav auto = automatic again."] = "Ziel gewechselt. /aegisnav auto = wieder automatisch.",
	["Usage: /aegisnav hud <name> on|off"] = "Benutzung: /aegisnav hud <name> on|off",
	["here!"] = "da!",
	["no position"] = "keine Position",
	["no target"] = "kein Ziel",
	["off"] = "aus",
	["on"] = "an",
})
