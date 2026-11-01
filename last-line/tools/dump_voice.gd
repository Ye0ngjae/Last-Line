extends SceneTree
## Lists every speech clip the game can ask for, as {voice_id: [text, ...]} JSON.
## godot --headless --path last-line -s tools/dump_voice.gd -- <out.json>

func _init() -> void:
	var tpls: Array = Radio.all_templates()
	for m: Mission in Mission.catalog():
		for e: Dictionary in m.radio:
			tpls.append([e.from, e.en])
	var out := {}
	for t in tpls:
		var id: String = RadioVoice.VOICES[t[0]]
		if not out.has(id):
			out[id] = {}
		for text in RadioVoice.needed(t[1]):
			out[id][text] = true
	var res := {}
	for id in out:
		res[id] = out[id].keys()
	var path: String = OS.get_cmdline_user_args()[0]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	quit()
