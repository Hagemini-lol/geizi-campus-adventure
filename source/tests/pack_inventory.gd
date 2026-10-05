extends SceneTree

var files: Array[String]=[]
func visit(path: String) -> void:
	for file: String in DirAccess.get_files_at(path):files.append(path.path_join(file))
	for directory: String in DirAccess.get_directories_at(path):visit(path.path_join(directory))
func _initialize() -> void:
	visit("res://")
	var images:=files.filter(func(path: String):return path.get_extension().to_lower() in ["png","jpg","jpeg","svg","ctex"])
	var report: Dictionary={"files":files,"image_entries":images,"passed":images.is_empty()}
	var file:=FileAccess.open("D:/Godot/校园自由漫游/包体内容检查.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PACK_INVENTORY ",files.size()," image_entries=",images.size());quit(0 if images.is_empty() else 1)
