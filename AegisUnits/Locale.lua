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
	[", default 110)"] = ", Standard 110)",
	["Default player and target frames "] = "Standard-Spieler- und Zielfeld ",
	["Distance from center "] = "Abstand zur Mitte ",
	["Error: "] = "Fehler: ",
	["Player card"] = "Spielerkarte",
	["Player frame "] = "Spielerfeld ",
	["Target card"] = "Zielkarte",
	["Target frame "] = "Zielfeld ",
	["Usage: /aegis units gap <pixels>  (current "] = "Benutzung: /aegis units gap <Pixel>  (aktuell ",
	["hidden"] = "versteckt",
	["off"] = "aus",
	["off (back to default after restart)"] = "aus (nach Neustart wieder Standard)",
	["on"] = "an",
	["on (fully active after /reload or restart)"] = "an (wirkt nach /reload bzw. Neustart voll)",
	["visible"] = "sichtbar",
	["commands:"] = "Befehle:",
})
