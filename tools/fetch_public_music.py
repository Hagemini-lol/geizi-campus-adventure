"""Download author's CC0 OGG originals with resumable partial transfers."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import time
import urllib.parse
import urllib.request

root = Path(__file__).resolve().parents[1] / '资源/公开配乐/v1.5'
root.mkdir(parents=True, exist_ok=True)
items = [
    ('day', 'Town3 - Sunshine Coast', 'jrpg-pack-2-towns'),
    ('night', 'Town2 - Where Time Stands Still', 'jrpg-pack-2-towns'),
    ('battle', 'Action1 - Encounter With The Witches', 'jrpg-pack-5-action'),
    ('tension', 'Evil5 - Whispers From Beyond', 'jrpg-pack-3-evil'),
    ('heroic', 'Action2 - Army Approaching', 'jrpg-pack-5-action'),
    ('final_boss', 'Evil3 - Apocalypse', 'jrpg-pack-3-evil'),
]

def download(item):
    key, title, page = item
    url = 'https://opengameart.org/sites/default/files/' + urllib.parse.quote(title + '.ogg', safe='')
    dest = root / (key + '.ogg')
    offset = dest.stat().st_size if dest.exists() else 0
    headers = {'User-Agent': 'Mozilla/5.0'}
    if offset: headers['Range'] = f'bytes={offset}-'
    start = time.monotonic()
    try:
        response = urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30)
    except urllib.error.HTTPError as error:
        if error.code != 416: raise
        response = None  # Already complete; verify OGG below and record original bytes.
    if response is not None:
        with response as incoming, dest.open('ab' if incoming.status == 206 else 'wb') as output:
            while chunk := incoming.read(32768):
                output.write(chunk)
                if time.monotonic() - start > 600: raise TimeoutError('download checkpoint retained')
    content = dest.read_bytes()
    assert content[:4] == b'OggS'
    print(key, len(content), round(time.monotonic() - start, 1), flush=True)
    return dict(id=key, title=title, author='Juhani Junkala / SubspaceAudio', file=dest.name,
                license='CC0 1.0', license_url='https://creativecommons.org/publicdomain/zero/1.0/',
                source_page='https://opengameart.org/content/' + page, download_url=url,
                bytes=len(content), sha256=hashlib.sha256(content).hexdigest(),
                processing='Original Ogg Vorbis bytes; renamed only; loop enabled at runtime.')

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    tracks = list(pool.map(download, items))
(root / '曲目与来源.json').write_text(json.dumps({'tracks': tracks,
    'runtime': 'At most two compressed streams during .65 second crossfade; saved Music volume bus.'},
    ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('MUSIC_READY', sum(item['bytes'] for item in tracks), flush=True)
