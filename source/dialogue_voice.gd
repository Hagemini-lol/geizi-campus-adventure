extends RefCounted

# Interaction-only selection. No substitutions in authored story dialogue and
# no persistent state: existing saves do not need another schema or migration.
var game: Node2D
var cursors: Dictionary={}

func reply(actor: String, context: String, lost: String="", affinity: int=-101) -> String:
	var profiles: Dictionary=game.story_system.data.get("character_voice",{})
	var profile: Dictionary=profiles.get(actor,profiles.get("ordinary",{}))
	if context=="chat":
		var bond: int=game.relationships.bond(actor) if affinity== -101 else affinity
		var tier: String="chat_new" if bond<10 else "chat_close" if bond>=60 else "chat_warm"
		var situations: Array[String]=[]
		if actor=="lao_ao" and game.economy.day_serial<game.campaign.ao_until:situations.append("recovering")
		if actor=="yang_zi" and game.campaign.flags.get("F_YANG_CLEAR",false):situations.append("cleared")
		if game.campaign.index>=29:situations.append("finale")
		elif game.campaign.index>=23:situations.append("crisis")
		elif game.campaign.index<3:situations.append("early")
		var candidates: Array=profile.get(tier,profile.get("chat",[])).duplicate()
		for situation: String in situations:candidates.append_array(profile.get(situation,[]))
		if not candidates.is_empty():
			var key: String=actor+"/"+tier+"/"+"/".join(situations)
			var index: int=int(cursors.get(key,0))%candidates.size()
			cursors[key]=(index+1)%candidates.size()
			return str(candidates[index]["text"])
	var rows: Array=profile.get(context,profiles.get("ordinary",{}).get(context,[]))
	if rows.is_empty():return "我听着。你先说。"
	var key: String=actor+"/"+context
	var index: int=int(cursors.get(key,0))%rows.size()
	cursors[key]=(index+1)%rows.size()
	return str(rows[index]["text"]).replace("{lost}",lost)
