extends RefCounted

const SLOT_COUNT:=5
const FORMAT_VERSION:=1
const MAX_BYTES:=2097152
var directory: String

func configure(path: String) -> void:directory=path
func slot_path(slot: int) -> String:return directory.path_join("slot_%d.json" % slot)

func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {"ok":false,"error":"空存档"}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>MAX_BYTES:return {"ok":false,"error":"存档无法读取"}
	var parser:=JSON.new()
	if parser.parse(file.get_as_text())!=OK:return {"ok":false,"error":"存档已损坏"}
	var parsed: Variant=parser.data
	if not parsed is Dictionary:return {"ok":false,"error":"存档已损坏"}
	var record: Dictionary=parsed
	if record.get("format","")!="campus_save" or record.get("version",0)!=FORMAT_VERSION:return {"ok":false,"error":"存档版本不兼容"}
	var payload: Variant=record.get("payload")
	if not payload is String or payload.sha256_text()!=record.get("sha256",""):return {"ok":false,"error":"存档校验失败"}
	var state_parser:=JSON.new()
	if state_parser.parse(payload)!=OK:return {"ok":false,"error":"存档内容无效"}
	var state: Variant=state_parser.data
	if not state is Dictionary:return {"ok":false,"error":"存档内容无效"}
	return {"ok":true,"state":state,"saved_at":str(record.get("saved_at","")),"location":str(record.get("location","")),"backup":false}

func read_slot(slot: int) -> Dictionary:
	if slot<1 or slot>SLOT_COUNT:return {"ok":false,"error":"存档槽位无效"}
	var result:=read_file(slot_path(slot))
	if not result["ok"]:
		var backup:=read_file(slot_path(slot)+".bak")
		if backup["ok"]:backup["backup"]=true;return backup
	return result

func write_slot(slot: int, state: Dictionary, location: String) -> Dictionary:
	if slot<1 or slot>SLOT_COUNT:return {"ok":false,"error":"存档槽位无效"}
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return {"ok":false,"error":"无法创建存档文件夹"}
	var path:=slot_path(slot)
	var temporary:=path+".tmp"
	var backup:=path+".bak"
	var payload:=JSON.stringify(state)
	var record: Dictionary={"format":"campus_save","version":FORMAT_VERSION,"saved_at":Time.get_datetime_string_from_system(false,true),"location":location,"payload":payload,"sha256":payload.sha256_text()}
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:return {"ok":false,"error":"无法写入存档"}
	file.store_string(JSON.stringify(record,"  "))
	file.flush()
	file.close()
	if not read_file(temporary)["ok"]:return {"ok":false,"error":"存档写入校验失败，旧档保留"}
	var existed:=FileAccess.file_exists(path)
	var backed_up:=false
	if existed and read_file(path)["ok"]:
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup)!=OK:return {"ok":false,"error":"备份无法更新，旧档保留"}
		if DirAccess.rename_absolute(path,backup)!=OK:return {"ok":false,"error":"无法备份旧存档"}
		backed_up=true
	elif existed:
		# Keep a valid recovery backup when replacing a damaged primary record.
		if DirAccess.remove_absolute(path)!=OK:return {"ok":false,"error":"无法替换损坏的存档"}
	if DirAccess.rename_absolute(temporary,path)!=OK:
		if backed_up:DirAccess.rename_absolute(backup,path)
		return {"ok":false,"error":"存档替换失败，已尝试恢复旧档"}
	return {"ok":true,"error":""}
