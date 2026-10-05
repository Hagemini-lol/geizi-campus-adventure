from pathlib import Path
import hashlib, json

game=Path(__file__).resolve().parents[1]
read=lambda path:json.loads(path.read_text(encoding='utf-8-sig'))
package=read(game/'runtime/android_package_checks.json')
normal=read(game/'runtime/mobile_checks.json')
wide=read(game/'runtime/mobile_checks_wide.json')
furniture=read(game/'runtime/furniture_route_checks.json')
lessons=read(game/'runtime/lesson_checks.json')
assert normal['passed'] and wide['passed'] and package['signature_verified']
assert furniture['passed']
assert lessons['passed']
assert package['exported_resource_payload_tested_with_desktop_engine']
assert package['exported_payload_touch_checks']==normal['checks']
assert package['exported_payload_touch_checks_wide']==wide['checks']
manifest=(game/'runtime/android_manifest.txt').read_text(encoding='utf-8')
assert "versionCode='2'" in manifest and "versionName='1.0.1'" in manifest
assert hashlib.sha256((game/'校园自由漫游.apk').read_bytes()).hexdigest()==package['sha256']
report={'version':2,'game_version':'1.0.1','apk':package,'touch_checks':{'standard':normal,'wide':wide},'furniture_checks':furniture,'lesson_checks':lessons,
    'windows_pck_sha256':hashlib.sha256((game/'runtime/campus.pck').read_bytes()).hexdigest(),
    'android_minimum':'7.0 / API 24','orientation':'landscape','original_assets_edited':False,
    'existing_zip_modified':False,'device_attached':False}
(game/'安卓完成检查.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
readme=game/'说明.md'
section='\n\n## 安卓触屏版（2026-10-05）\n\n本文件夹的 `校园自由漫游.apk` 可发送到 Android 7.0 及以上 ARM 手机和平板安装。采用横屏，复用摇杆和圆形按钮素材：摇杆移动，X 交互，Y 菜单，×2 奔跑，点击地图五倍寻路；支持列表滑动、触屏对话与战斗。完整素材已封装，存档和设置写入应用私有目录。操作与构建方式见 `安卓版使用说明.md`，安卓工程保存在 `android_source`。签名与素材校验、标准/宽屏触控及最终导出内容检查通过，尚未真机测试。\n'
text=readme.read_text(encoding='utf-8-sig')
if '## 安卓触屏版（2026-10-05）' not in text:readme.write_text(text+section,encoding='utf-8')
print(json.dumps({'apk_MB':round(package['bytes']/1048576,1),'touch_checks':normal['checks']+wide['checks'],
    'asset_hashes':package['asset_hashes_checked'],'signature':'verified','physical_device_tested':False},ensure_ascii=False))
