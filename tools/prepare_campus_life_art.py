"""Pack generated transparent sprites without redrawing the original artwork."""
from pathlib import Path
import json, shutil
from PIL import Image

root = Path(__file__).resolve().parents[1]
generated = Path('C:/Users/李科奇/.codex/generated_images/01a119fe-4fad-75e1-9efd-2badd4b2ddcd')
files = {
    'cook_hu': 'exec-8881c4f5-4f1c-4733-b3f2-f4c4800968a7.png',
    'clerk_qiu': 'exec-44bf5a0d-c86b-402c-874c-f64dcaf58112.png',
    'worker_hou': 'exec-62da34fc-1dd5-42b7-a3ee-42dd33af49fb.png',
    'warden_chen': 'exec-fdd53d55-cccb-43cc-a61e-d0d26e22ebfd.png',
    'warden_zhou': 'exec-eff86dd0-6fbf-4b85-b9e8-2814bc9f59ac.png',
}
target = root / '资源/原项目/assets/characters/staff_v15'
masters = root / '美术生成记录/校园生活v1.5'
target.mkdir(parents=True, exist_ok=True); masters.mkdir(parents=True, exist_ok=True)
for ident, filename in files.items():
    source = Image.open(generated / filename).convert('RGBA')
    assert source.getpixel((0, 0))[3] == 0, 'Expected transparent generated background'
    shutil.copy2(generated / filename, masters / (ident + '.png'))
    sheet = Image.new('RGBA', (512, 480))
    for row in range(3):
        for column in range(4):
            box = (column * source.width // 4, row * source.height // 3,
                   (column + 1) * source.width // 4, (row + 1) * source.height // 3)
            frame = source.crop(box)
            bounds = frame.getchannel('A').point(lambda a: 255 if a > 24 else 0).getbbox()
            assert bounds, (ident, row, column)
            frame = frame.crop(bounds)
            width = round(frame.width * 140 / frame.height)
            frame = frame.resize((width, 140), Image.Resampling.LANCZOS)
            assert width <= 128, (ident, width)
            sheet.alpha_composite(frame, (column * 128 + (128-width)//2, row * 160 + 16))
    sheet.save(target / (ident + '.png'))
notes = {'tool': 'built-in imagegen', 'style_reference': '普通教室.png / 班主任.png',
         'backgrounds': ['cafeteria', 'dorm', 'gym', 'print'],
         'sprite_request': 'Four directions; three rows standing, walk A, walk B; adult school staff; transparent background.',
         'packing': 'Only grid extraction, transparent bounds and uniform resize; original masters retained.',
         'staff': files}
(masters / '生成与打包记录.json').write_text(json.dumps(notes, ensure_ascii=False, indent=2), encoding='utf-8')
print('Five staff atlases packed, 60 poses, 512x480 per atlas.')
