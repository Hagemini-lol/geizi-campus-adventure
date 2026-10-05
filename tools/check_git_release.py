"""Verify source-index exclusions and lossless game resources before publishing."""
from pathlib import Path
import hashlib
import json
import subprocess

game = Path(__file__).resolve().parents[1]
version = (game / 'VERSION').read_text(encoding='utf-8').strip()
command = ['git', '-c', 'safe.directory=' + game.as_posix(), '-C', str(game)]
output = subprocess.check_output(command + ['ls-files', '--stage', '-z'])
index = {}
for record in output.split(b'\0'):
    if not record:continue
    metadata, name = record.split(b'\t', 1)
    index[name.decode('utf-8')] = metadata.split()[1].decode('ascii')
for name in index:
    assert not name.startswith(('runtime/', 'android_tools/', 'android_source/', 'releases/', '存档/'))
    assert name != '设置.json'
    assert not name.endswith(('.apk', '.exe', '.keystore', '.jks', '/credentials.json'))
manifest = json.loads((game / '素材打包清单.json').read_text(encoding='utf-8-sig'))
for item in manifest['files']:
    name = item['file']
    data = (game / name).read_bytes()
    assert hashlib.sha256(data).hexdigest() == item['sha256'], name
    git_hash = hashlib.sha1(b'blob ' + str(len(data)).encode('ascii') + b'\0' + data).hexdigest()
    assert index.get(name) == git_hash, 'Resource bytes changed in Git index: ' + name
report = {'version': version, 'indexed_files': len(index), 'asset_hashes_checked': len(manifest['files']),
    'resource_git_blobs_preserve_original_bytes': True, 'private_and_generated_files_excluded': True}
(game / 'releases' / ('v' + version) / 'source-integrity.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
