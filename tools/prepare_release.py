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
required = [game / name for name in ['gei子的冒险.exe','runtime/engine.exe','runtime/campus.pck',
    'README.md','CHANGELOG.md','VERSION','说明.md','分享说明.txt','素材打包清单.json',
    '第一章与剧情扩展说明.md','任务与物资扩展说明.md','安卓版使用说明.md',
    '剧情续写实现说明.md','分区加载与卡桌修复说明.md','覆盖更新与存档说明.md',
    '内容与战斗扩充说明.md','内容量与游玩时长.md','Mod制作说明.md','本版发布说明.md'] + configurations]
required += sorted(path for path in (game / 'mods').rglob('*.json') if path.is_file())
required += sorted(path for path in (game / '资源').rglob('*') if path.is_file() and path.suffix != '.import')
assert all(path.is_file() for path in required)
windows = output / ('geizi-adventure-windows-v' + version + '.zip')
temporary = windows.with_suffix('.building.zip')
with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as archive:
    for file in required:archive.write(file, 'gei子的冒险/' + file.relative_to(game).as_posix())
with zipfile.ZipFile(temporary) as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert len(names) == len(set(names)) == len(required)
    assert not any('/存档/' in name or '/android_tools/' in name or name.endswith('/设置.json') for name in names)
    for file in required:
        name = 'gei子的冒险/' + file.relative_to(game).as_posix()
        assert archive_digest(archive, name) == digest(file), name
    for item in manifest['files']:
        assert archive_digest(archive, 'gei子的冒险/' + item['file']) == item['sha256'], item['file']
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
(output / 'release-notes.md').write_text((game / '本版发布说明.md').read_text(encoding='utf-8'), encoding='utf-8')

(output / 'release-manifest.json').write_text(json.dumps({'version': version, 'artifacts': records,
    'windows_pack_sha256': digest(game / 'runtime/campus.pck'), 'asset_hashes_checked': len(manifest['files']),
    'existing_share_zip_modified': False, 'private_data_excluded': True}, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(records, ensure_ascii=False))
