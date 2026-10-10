"""Check packaged font coverage for every character in current JSON content."""
from pathlib import Path
import json, sys, unicodedata
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'runtime/python-libs'))
from fontTools.ttLib import TTFont
font=TTFont(root/'资源/字体/NotoSansSC-Regular.ttf');cmap=font.getBestCmap()
def texts(v):
    if isinstance(v,str):return [v]
    if isinstance(v,list):return sum((texts(x) for x in v),[])
    if isinstance(v,dict):return sum((texts(x) for x in v.values()),[])
    return []
characters=set(''.join(sum((texts(json.loads((root/n).read_text(encoding='utf-8'))) for n in ['剧情配置.json','任务配置.json','关系与攻略配置.json','物资与交易配置.json']),[])))
missing=sorted(c for c in characters if not c.isspace() and ord(c) not in cmap and unicodedata.category(c)!='Cc')
assert not missing,missing
(root/'runtime/v16_font_checks.json').write_text(json.dumps({'passed':True,'characters':len(characters),'missing':[]},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('FONT_COVERAGE',len(characters),'PASS')
