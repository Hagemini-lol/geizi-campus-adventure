"""Verify the user's release without exposing authentication credentials."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

game = Path(__file__).resolve().parents[1]
workspace = game.parent
version = (game / 'VERSION').read_text(encoding='utf-8').strip()
folder = game / 'releases' / ('v' + version)
gh = workspace / 'version_tools/gh/bin/gh.exe'
env = os.environ.copy()
env['GH_CONFIG_DIR'] = str(workspace / 'version_tools/github_config')
repository = 'Hagemini-lol/geizi-campus-adventure'

def api(path):
    for attempt in range(3):
        result = subprocess.run([str(gh), 'api', path], env=env, capture_output=True, text=True, encoding='utf-8')
        if result.returncode == 0:return json.loads(result.stdout)
        print('GitHub API retry: ' + path + ' / ' + result.stderr.strip(), flush=True)
        time.sleep(2)
    raise RuntimeError('GitHub read failed: ' + path)

def digest(file):
    result = hashlib.sha256()
    with file.open('rb') as stream:
        while block := stream.read(1048576):result.update(block)
    return result.hexdigest()

repo = api('repos/' + repository)
assert repo['default_branch'] == 'main'
# Observe existing visibility; never change it as part of a release.
release = next(item for item in api('repos/' + repository + '/releases') if item['tag_name'] == 'v' + version)
expected_commit = subprocess.check_output(['git','-c','safe.directory=' + game.as_posix(),'-C',str(game),
    'rev-parse','v' + version + '^{}'], text=True).strip()
tag = api('repos/' + repository + '/git/ref/tags/v' + version)['object']
for step in range(5):
    if tag['type'] != 'tag':break
    tag = api('repos/' + repository + '/git/tags/' + tag['sha'])['object']
assert tag['type'] == 'commit' and tag['sha'] == expected_commit
assert api('repos/' + repository + '/commits/main')['sha'] == expected_commit
manifest = json.loads((folder / 'release-manifest.json').read_text(encoding='utf-8'))
files = manifest['artifacts'] + [{'file':'SHA256SUMS.txt', 'bytes':(folder / 'SHA256SUMS.txt').stat().st_size,
    'sha256':digest(folder / 'SHA256SUMS.txt')}]
assets = {item['name']: item for item in release['assets']}
assert set(assets) == {item['file'] for item in files}, 'Release assets still incomplete'
checks = []
for file in files:
    asset = assets[file['file']]
    assert asset['state'] == 'uploaded' and asset['size'] == file['bytes'], file['file']
    assert asset['digest'] == 'sha256:' + file['sha256'], file['file']
    assert digest(folder / file['file']) == file['sha256'], 'Local artifact changed: ' + file['file']
    checks.append({'name': file['file'], 'bytes': file['bytes'], 'sha256': file['sha256'],
        'server_digest_matches_local': True, 'download_url':asset['browser_download_url']})
if '--published' in sys.argv:assert not release['draft']
report = {'repository':repo['html_url'], 'private':repo['private'], 'version':version,
    'commit':expected_commit, 'source_and_tag_verified':True, 'release':release['html_url'],
    'published':not release['draft'], 'assets':checks, 'existing_share_zip_modified':False}
(folder / 'github-publication-checks.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
