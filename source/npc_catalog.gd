extends RefCounted

const ORDINARY_IDS: Array[String]=["student_male","student_female","legacy_student_1","legacy_student_2","legacy_student_3","legacy_student_4"]
const OFFICE_IDS: Array[String]=["homeroom_teacher","english_teacher","wen_cong"]
const SPECIALS: Dictionary={"B12":{"id":"lao_li","name":"牢李"},"B05":{"id":"yang_zi","name":"阳子"},"B01":{"id":"la_jiao","name":"辣椒"}}
const NAMED_IDS: Array[String]=["lao_li","lao_chou","fei_yan","lao_ao","yang_zi","lao_shuo","lao_dong","la_jiao","gou_ga","wr"]
const TEN_CLASS_STUDENTS: Dictionary={"B12":NAMED_IDS,"B05":NAMED_IDS,"B01":NAMED_IDS}
var characters: Dictionary={}
var project_root: String

func configure(path: String) -> bool:
	project_root=path.get_base_dir().get_base_dir()
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:return false
	for item: Dictionary in parsed.get("characters",[]):characters[item["id"]]=item
	if characters.has("english_teacher"):characters["english_teacher"]["display_name"]="老美子"
	if characters.has("fei_yan"):
		var leon: Dictionary=characters["fei_yan"].duplicate(true)
		leon["source"]="res://assets/characters/leon_v15/atlas.png";leon["pixel_grid"]=true
		for d: int in range(4):leon["source_regions"][["front","back","left","right"][d]]=[128*d,0,128,160]
		characters["fei_yan"]=leon
	for id: String in ORDINARY_IDS:
		if not characters.has(id):return false
	for id: String in OFFICE_IDS:
		if not characters.has(id):return false
	for item: Dictionary in SPECIALS.values():
		if not characters.has(item["id"]):return false
	for roster: Array in TEN_CLASS_STUDENTS.values():
		for id: String in roster:
			if not characters.has(id):return false
	if not characters.has("zhao_mugei"):return false
	return true

func height(id: String) -> float:
	return 40.8*float(characters[id]["height_px"])/104.0

func source_image(id: String) -> Image:
	return Image.load_from_file(project_root.path_join(str(characters[id]["source"]).trim_prefix("res://")))

func frame(id: String, direction: int, source: Image=null) -> Image:
	if source==null:source=source_image(id)
	if source==null:return null
	var key: String=["front","back","left","right"][direction]
	var box: Array=characters[id]["source_regions"][key]
	var result:=source.get_region(Rect2i(int(box[0]),int(box[1]),int(box[2]),int(box[3])))
	return result.get_region(result.get_used_rect())

func dialogue_portrait(id: String) -> Image:
	if id=="fei_yan":
		var path:=project_root.get_base_dir().path_join("新增立绘/费眼_Leon_RE2_2019.png")
		if FileAccess.file_exists(path):return Image.load_from_file(path)
	return frame(id,0)
