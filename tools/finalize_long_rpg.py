"""Record tested delivery and explicitly identify reused unchanged-system checks."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
read = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
names = ['campaign', 'sidequest', 'puzzle', 'mod', 'campaign_behavior', 'campaign_save',
         'update_save', 'balance', 'stamina', 'expansion', 'stream_recovery', 'economy',
         'campus_life', 'lesson', 'sound', 'presentation', 'story_region',
         'music_farming', 'relationship', 'leon_pixel', 'phone', 'story', 'class_ten', 'social', 'campus_rooms', 'animation_flow']
checks = {}
for name in names:
    checks[name] = read(root / 'runtime' / (name + '_checks.json'))
    assert checks[name]['passed'], name
checks['update_save_restart'] = read(root / 'runtime/update_save_checks_restart.json')
assert checks['update_save_restart']['passed']
checks['time'] = read(root / '时间昼夜验证报告.json')
assert checks['time']['passed']
apk = read(root / 'runtime/android_package_checks.json')
assert apk['signature_verified'] and apk['exported_resource_payload_tested_with_desktop_engine']
assert apk['exported_payload_touch_checks'] == apk['exported_payload_touch_checks_wide'] == 49
assert apk['configuration_files_checked'] == 7
assert sha(root / 'gei子的冒险.apk') == apk['sha256']
log = (root / 'runtime/apk-mod-final.log').read_text(encoding='utf-8')
assert 'MOD_CHECKS 33 FAILURES 0' in log and 'ERROR:' not in log
assert read(root / '剧情续写完成检查.json')['windows_launcher_passed']
for source in (root / 'source').glob('*.gd'):
    assert (root / 'android_source' / source.name).read_bytes() == source.read_bytes(), source.name
personal = read(root / 'runtime/personal-files-before-v1.2.2.json')
assert all(sha(root / name) == checksum for name, checksum in personal.items())
frozen = root.parent / 'gei子的冒险win.zip'
assert sha(frozen) == '3df2e8b27ee1970406b5e8722e7a7042f17a738a3439f46d3bc84a01b7eba6cc'
assert frozen.stat().st_size == 408939518 and frozen.stat().st_mtime_ns == 1791194178223172900
manifest = read(root / '素材打包清单.json')
assert all(sha(root / item['file']) == item['sha256'] for item in manifest['files'])
report = {
    'version': (root / 'VERSION').read_text().strip(),
    'content_audit': read(root / 'runtime/content_audit.json'),
    'checks': {name: {'checks': result.get('checks'), 'passed': True} for name, result in checks.items()},
    'unchanged_base_formula_and_stream_checks_reused': ['balance', 'stream_recovery'],
    'windows_launcher_passed': True,
    'windows_pck_sha256': sha(root / 'runtime/campus.pck'),
    'apk_sha256': apk['sha256'], 'android_version_code': 16,
    'original_android_identity_and_signature_verified': True,
    'exported_apk_desktop_checks': {'touch_standard': 49, 'touch_wide': 49, 'mod_runtime': 33},
    'runtime_asset_hashes_verified': len(manifest['files']),
    'original_assets_modified': False, 'personal_files_unchanged': True,
    'existing_share_zip_unchanged': True,
    'four_hour_human_playthrough_measured': False,
    'physical_android_device_tested': False, 'android_emulator_tested': False,
    'desktop_settings_and_save_checks': read(root / '存读档验证报告_界面.json'),
    'mobile_ui_fix_checks': read(root / 'runtime/mobile_ui_fix_checks.json'),
    'mobile_ui_fix_exported_standard': read(root / 'runtime/mobile_ui_fix_apk_checks.json'),
    'mobile_ui_fix_exported_wide': read(root / 'runtime/mobile_ui_fix_apk_wide_checks.json'),
    'source_checks_reused_from_preceding_release': ['mod','balance','stream_recovery','economy','lesson','sound','story_region','class_ten','social','campus_rooms','time'],
    'notes': 'Playtime is an explicit content estimate. APK runtime checks use the exported payload on the desktop engine; they are not Android device tests.'
}
assert not report['desktop_settings_and_save_checks']['failures']
assert all(report[key]['passed'] for key in ['mobile_ui_fix_checks','mobile_ui_fix_exported_standard','mobile_ui_fix_exported_wide'])
report['campus_rooms_exported_apk_checks']=read(root/'runtime/campus_rooms_apk_checks.json')
assert report['campus_rooms_exported_apk_checks']['passed'] and report['campus_rooms_exported_apk_checks']['checks']==checks['campus_rooms']['checks'] and checks['campus_rooms']['mapped_buildings']==14
report['furniture_navigation_checks_reused_from_v1_8_0']=read(root/'runtime/furniture_route_checks.json')
assert report['furniture_navigation_checks_reused_from_v1_8_0']['passed']
report['social_exported_apk_checks']=read(root/'runtime/social_apk_checks.json')
assert report['social_exported_apk_checks']['passed'] and report['social_exported_apk_checks']['checks']==checks['social']['checks'] and checks['social']['checks']>=575
report['class_ten_exported_apk_checks']=read(root/'runtime/class_ten_apk_checks.json')
report['current_configuration_font_coverage']=read(root/'runtime/v16_font_checks.json')
report['fresh_content_checks_this_version']=read(root/'runtime/v16_fresh_content_checks.json')
report['desktop_settings_checks_reused_from_v1_5_1']=True
report['release_touch_gesture_checks']={name:read(root/'runtime'/(name+'_checks.json')) for name in ['touch_release','touch_release_wide','touch_release_apk','touch_release_apk_wide']}
assert all(result['passed'] and result['checks']==37 for result in report['release_touch_gesture_checks'].values())
assert report['class_ten_exported_apk_checks']['passed'] and report['current_configuration_font_coverage']['passed']
assert all(report['fresh_content_checks_this_version'][name]==checks[name]['checks'] for name in ['campaign','campaign_behavior','campaign_save','sidequest','puzzle','campus_life','relationship','phone','story'])

# Animation checks must run against both final common source and exported APK.
report['animation_flow_exported_apk_checks']=read(root/'runtime/animation_flow_apk_checks.json')
assert report['animation_flow_exported_apk_checks']['passed'] and report['animation_flow_exported_apk_checks']['checks']==checks['animation_flow']['checks']
report['animation_pose_limits']={'world_slow_walk_minimum':2,'world_hero_walk':4,'world_hero_run':8,'pixel_leon_and_staff':4,'monster_pose_keys':3,'battle_idle_pose_keys':3,'extra_walk_frame_images':0}
report['unchanged_seating_and_navigation_checks_reused_from_v1_8_0']=True
(root/'本版完成检查.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({key:report[key] for key in ['version','checks','exported_apk_desktop_checks','personal_files_unchanged']},ensure_ascii=False))
