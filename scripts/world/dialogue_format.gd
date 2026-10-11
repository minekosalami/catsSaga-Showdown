extends RefCounted

const RAINBOW := ["#FF6666", "#FFA94D", "#FFE066", "#78E08F", "#74C0FC", "#B197FC", "#F783D8"]

static func literal(text: String) -> String:
	var result := ""
	for character in text:
		result += "[lb]" if character == "[" else ("[rb]" if character == "]" else character)
	return result

static func format_text(text: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("The Refraction|\\b(?i:SATURATE)\\b(?:\\(\\))?")
	var result := ""
	var cursor := 0
	for match in pattern.search_all(text):
		result += literal(text.substr(cursor, match.get_start() - cursor))
		var term := match.get_string()
		if term == "The Refraction":
			result += "[color=#B47AFF][b]" + term + "[/b][/color]"
		else:
			for index in range(term.length()):
				result += "[color=" + RAINBOW[index % RAINBOW.size()] + "]" + term[index] + "[/color]"
		cursor = match.get_end()
	return result + literal(text.substr(cursor))
