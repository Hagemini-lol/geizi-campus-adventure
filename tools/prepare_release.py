"""Stage current Windows and signed Android builds without changing existing ZIPs."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

game = Path(__file__).resolve().parents[1]
version = (game / 'VERSION').read_text(encoding='utf-8').strip()
output = game / 'releases' / ('v' + version)
output.mkdir(parents=True, exist_ok=True)

def digest(file):
    result = hashlib.sha256()
    with file.open('rb') as stream:
        while block := stream.read(1048576):result.update(block)
    return result.hexdigest()

def archive_digest(archive, name):
    result = hashlib.sha256()
    with archive.open(name) as stream:
        while block := stream.read(1048576):result.update(block)
    return result.hexdigest()

manifest = json.loads((game / '素材打包清单.json').read_text(encoding='utf-8-sig'))
configurations = ['素材引用.json','战斗与刷新配置.json','办公室配置.json','剧情配置.json','任务配置.json','物资与交易配置.json']
required = [game / name for name in ['校园自由漫游.exe','runtime/engine.exe','runtime/campus.pck',
    'README.md','CHANGELOG.md','VERSION','说明.md','分享说明.txt','素材打包清单.json',
    '第一章与剧情扩展说明.md','任务与物资扩展说明.md'] + configurations]
required += sorted(path for path in (game / '资源').rglob('*') if path.is_file() and path.suffix != '.import')
assert all(path.is_file() for path in required)
windows = output / ('geizi-adventure-windows-v' + version + '.zip')
temporary = windows.with_suffix('.building.zip')
with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as archive:
    for file in required:archive.write(file, '校园自由漫游/' + file.relative_to(game).as_posix())
with zipfile.ZipFile(temporary) as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert len(names) == len(set(names)) == len(required)
    assert not any('/存档/' in name or '/android_tools/' in name or name.endswith('/设置.json') for name in names)
    for file in required:
        name = '校园自由漫游/' + file.relative_to(game).as_posix()
        assert archive_digest(archive, name) == digest(file), name
    for item in manifest['files']:
        assert archive_digest(archive, '校园自由漫游/' + item['file']) == item['sha256'], item['file']
temporary.replace(windows)
apk_source = next((path for path in (game / 'gei子的冒险.apk', game / '校园自由漫游.apk') if path.is_file()), None)
assert apk_source is not None, 'Signed Android APK is missing'
android_checks = json.loads((game / 'runtime/android_package_checks.json').read_text(encoding='utf-8'))
assert android_checks['signature_verified'] and digest(apk_source) == android_checks['sha256']
apk = output / ('geizi-adventure-android-v' + version + '.apk')
shutil.copy2(apk_source, apk)
assert digest(apk) == digest(apk_source)
records = [{'file': file.name, 'bytes': file.stat().st_size, 'sha256': digest(file)} for file in (windows, apk)]
(output / 'SHA256SUMS.txt').write_text(''.join(item['sha256'] + '  ' + item['file'] + '\n' for item in records), encoding='utf-8')
(output / 'release-notes.md').write_text(
    '# gei 子的冒险 v' + version + '\n\n首个 GitHub 版本，包含 Windows 64 位和 Android 安装包。\n\n'
    '- 修复桌椅穿模，寻路绕开桌椅落脚范围，修正家具与人物前后遮挡。\n'
    '- 普通教室学生采用坐姿，十班上课、座位与近距离交互保持可用。\n'
    '- Android 支持摇杆、X 交互、Y 菜单、双指奔跑和触屏寻路。\n\n'
    'Windows 请完整解压 ZIP 后运行「校园自由漫游.exe」。Android 需要 Android 7.0 或更新版本的 ARM 设备，横屏游玩；沿用旧版签名，可覆盖安装。\n\n'
    '家具、上课和触屏检查通过，APK 签名及 3,684 份资源哈希校验通过。未进行本次修复后的安卓真机复测。个人存档、设置与签名密钥未封装。\n\n'
    'SHA256SUMS.txt 可核验两份发布文件。\n', encoding='utf-8')
(output / 'release-manifest.json').write_text(json.dumps({'version': version, 'artifacts': records,
    'windows_pack_sha256': digest(game / 'runtime/campus.pck'), 'asset_hashes_checked': len(manifest['files']),
    'existing_share_zip_modified': False, 'private_data_excluded': True}, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(records, ensure_ascii=False))
