from pathlib import Path
import json, shutil

game=Path(__file__).resolve().parents[1]
stage=game/'android_source'
stage.mkdir(exist_ok=True)
for source in (game/'source').iterdir():
    if source.is_file() and source.name!='export_presets.cfg':shutil.copy2(source,stage/source.name)
package=stage/'package';package.mkdir(exist_ok=True)
(package/'.gdignore').write_text('',encoding='utf-8')
shutil.copytree(game/'资源',package/'资源',dirs_exist_ok=True)
for name in ['素材引用.json','战斗与刷新配置.json','办公室配置.json','剧情配置.json','任务配置.json','物资与交易配置.json','关系与攻略配置.json']:
    shutil.copy2(game/name,package/name)
project=(stage/'project.godot').read_text(encoding='utf-8')
project=project.replace('[application]','[application]\nconfig/mobile_bundle=true\nconfig/quit_on_go_back=false')
project=project.replace('window/stretch/mode="canvas_items"','window/stretch/mode="canvas_items"\nwindow/stretch/aspect="expand"\nwindow/handheld/orientation=0')
project=project.replace('[rendering]','[rendering]\ntextures/vram_compression/import_etc2_astc=true')
project+='\n[input_devices]\npointing/emulate_mouse_from_touch=false\npointing/emulate_touch_from_mouse=false\n\n[editor_plugins]\nenabled=PackedStringArray("res://addons/raw_bundle/plugin.cfg")\n'
(stage/'project.godot').write_text(project,encoding='utf-8')
addon=stage/'addons/raw_bundle';addon.mkdir(parents=True,exist_ok=True)
(addon/'plugin.cfg').write_text('[plugin]\nname="Campus raw assets"\ndescription="Package original image and scene bytes without importer remapping"\nauthor="Campus"\nversion="1.0"\nscript="plugin.gd"\n',encoding='utf-8')
(addon/'plugin.gd').write_text('''@tool
extends EditorPlugin
class RawBundle extends EditorExportPlugin:
    func _get_name() -> String:return "CampusRawBundle"
    func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
        add_tree("res://package")
    func add_tree(path: String) -> void:
        for folder: String in DirAccess.get_directories_at(path):add_tree(path.path_join(folder))
        for file: String in DirAccess.get_files_at(path):
            if file.begins_with("."):continue
            var full:=path.path_join(file)
            add_file(full,FileAccess.get_file_as_bytes(full),false)
var exporter:=RawBundle.new()
func _enter_tree() -> void:
    add_export_plugin(exporter)
    var settings:=EditorInterface.get_editor_settings()
    var tools:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("android_tools")
    var java:=""
    for folder: String in DirAccess.get_directories_at(tools.path_join("jdk")):
        if FileAccess.file_exists(tools.path_join("jdk").path_join(folder).path_join("bin/java.exe")):
            java=tools.path_join("jdk").path_join(folder);break
    if not java.is_empty():settings.set_setting("export/android/java_sdk_path",java)
    settings.set_setting("export/android/android_sdk_path",tools.path_join("sdk"))
func _exit_tree() -> void:remove_export_plugin(exporter)
''',encoding='utf-8')
template=(game/'android_tools/templates/android_release.apk').as_posix()
preset=f'''[preset.0]
name="Android"
platform="Android"
runnable=true
export_filter="all_resources"
include_filter="mod_example.json"
exclude_filter="addons/*,tests/*,human_scale_details.gd"
export_path="../gei子的冒险.apk"

[preset.0.options]
custom_template/release="{template}"
custom_template/debug="{template}"
gradle_build/use_gradle_build=false
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=10
version/name="1.5.1"
package/unique_name="org.campus.gei.adventure"
package/name="gei子的冒险"
package/signed=true
screen/immersive_mode=true
screen/edge_to_edge=false
permissions/internet=false
permissions/read_external_storage=false
permissions/write_external_storage=false
user_data_backup/allow=false
'''
(stage/'export_presets.cfg').write_text(preset,encoding='utf-8')
print(json.dumps({'android_source':str(stage),'raw_asset_files':sum(1 for p in package.rglob('*') if p.is_file())},ensure_ascii=False))
