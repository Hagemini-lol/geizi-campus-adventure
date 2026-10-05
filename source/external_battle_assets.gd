extends RefCounted

# Read the existing, single-root UI component scenes without importing or copying
# their sources/images into this project. Dependencies stay in the external tree.
static var root: String=""
static var cache: Dictionary={}
static var reads: Array[String]=[]

static func external_path(path: String) -> String:
	return root.path_join(path.trim_prefix("res://")) if path.begins_with("res://") else path

static func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(external_path(path))

static func fetch(path: String) -> Resource:
	var absolute:=external_path(path)
	if cache.has(absolute):return cache[absolute]
	reads.append(absolute)
	if path.ends_with(".gd"):
		var source:=read_text(path)
		# Runtime dependencies cannot be compile-time constants. Dynamic locals
		# also avoid inference from these externally compiled scripts.
		var expression:=RegEx.new()
		expression.compile('const (\\w+) = preload\\(')
		source=expression.sub(source,'var $1 = preload(',true)
		source=source.replace(":=","=")
		source=source.replace("const EFFECT_SCENES =","var EFFECT_SCENES =")
		source=source.replace('FileAccess.get_file_as_string(', 'preload("res://external_battle_assets.gd").read_text(')
		expression.compile('(?<![\\w.])(?:preload|load)\\(')
		source=expression.sub(source,'preload("res://external_battle_assets.gd").fetch(',true)
		# The previous replacement must not rewrite its own adapter preload.
		source=source.replace('preload("res://external_battle_assets.gd").fetch("res://external_battle_assets.gd")','preload("res://external_battle_assets.gd")')
		var script:=GDScript.new()
		script.source_code=source
		if script.reload()!=OK:push_error("外部战斗组件编译失败："+path);return null
		cache[absolute]=script
		return script
	if path.ends_with(".tscn"):
		var text:=read_text(path)
		var expression:=RegEx.new()
		expression.compile('\\[node name="([^"]+)" type="([^"]+)"\\]')
		var match_value:=expression.search(text)
		if match_value==null:push_error("战斗组件不是受支持的单根节点场景："+path);return null
		var node: Node=ClassDB.instantiate(match_value.get_string(2))
		node.name=match_value.get_string(1)
		expression.compile('\\[ext_resource type="Script" path="([^"]+)"')
		match_value=expression.search(text)
		if match_value!=null:node.set_script(fetch(match_value.get_string(1)))
		var in_node:=false
		for line: String in text.split("\n"):
			if line.begins_with("[node "):in_node=true;continue
			if not in_node or not line.contains(" = "):continue
			var parts:=line.strip_edges().split(" = ",true,1)
			if parts[0] in ["script","editor_description"] or parts[0].begins_with("metadata/"):continue
			node.set(parts[0],str_to_var(parts[1]))
		var scene:=PackedScene.new()
		scene.pack(node);node.free()
		cache[absolute]=scene
		return scene
	if path.ends_with(".png") or path.ends_with(".svg"):
		var image:=Image.load_from_file(absolute)
		if image==null:return null
		image.generate_mipmaps()
		return ImageTexture.create_from_image(image)
	return null
