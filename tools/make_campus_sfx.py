"""Original synthesized foley and spell cues, deterministic PCM; no external audio."""
from pathlib import Path
import math, random, wave, struct, json, hashlib
root=Path(__file__).resolve().parents[1]
out=root/'资源/原创音效/v1.5';out.mkdir(parents=True,exist_ok=True)
rate=22050
def tone(t,f):return math.sin(2*math.pi*f*t)
def dec(t,d):return math.exp(-t/d)
def chirp(t,f,change):return math.sin(2*math.pi*(f*t+change*t*t/2))
def pluck(t,f):return (tone(t,f)+.3*tone(t,f*2)+.12*tone(t,f*3))*dec(t,.15)
cues={
 'ui_confirm':(.07,'轻木质确认，避免尖锐提示音'),
 'interact':(.14,'点头交谈与拾取的小木扣声'),
 'door':(.25,'门把与木门落扣'),
 'paper':(.25,'轻翻纸页与装订'),
 'trade':(.28,'两枚硬币轻碰'),
 'craft':(.48,'工具轻敲、收束完成'),
 'quest_complete':(.85,'三音确认与柔和尾音'),
 'puzzle_tick':(.10,'机关转动轻扣'),
 'puzzle_success':(.64,'解开机关的上行泛音'),
 'attack_swing':(.20,'手臂与衣料带动的短风声'),
 'impact':(.18,'拳击和普通物理命中的低频闷响'),
 'guard':(.22,'架臂格挡的干燥双击'),
 'dodge':(.26,'侧移避让的柔和风声'),
 'charge':(.52,'聚力时逐渐升起的谐波'),
 'fire':(.60,'火焰喷发和余烬的粗糙噪声'),
 'ice':(.58,'冰晶落下的清脆泛音'),
 'lightning':(.46,'雷电短裂与电弧尾音'),
 'wind':(.55,'气流扫过的连续带通风声'),
 'light':(.62,'光系清澈且温暖的共鸣'),
 'dark':(.72,'暗系低沉失谐与短脉冲'),
 'barrier':(.52,'屏障展开的空心共振'),
 'heal':(.45,'恢复与补给的轻柔双音'),
 'rest':(.36,'稳住呼吸的低声气流'),
 'story_rumble':(.95,'异变、震动和爆裂的低沉滚动'),
 'story_reveal':(.90,'发现线索与剧情转折的悬浮泛音'),
 'boss_thread':(.68,'勾尬牵线的紧绷拨弦与低频牵拉'),
 'boss_phase':(.95,'勾尬阶段变化的绷断、回响与压力上升'),
 'break_stance':(.38,'破势时的断裂短击'),
 'victory':(.90,'简短胜利收束'),
 'defeat':(.75,'失败的低落收束，避免惊吓'),
 'escape':(.28,'撤离的渐远风声'),
}
records=[]
for index,(name,(length,description)) in enumerate(cues.items()):
 rng=random.Random(1500+index);low=0.;values=[]
 for i in range(round(rate*length)):
  t=i/rate;n=rng.uniform(-1,1);low=.92*low+.08*n;high=n-low
  if name=='ui_confirm':v=(tone(t,520)+.25*tone(t,780))*dec(t,.025)
  elif name=='interact':v=(tone(t,330)*.6+low*4)*dec(t,.045)
  elif name=='door':v=(tone(t,105)+low*3)*dec(t,.09)+high*.12*dec(abs(t-.12),.014)
  elif name=='paper':v=high*(.25+.6*math.sin(math.pi*t/length)**2)
  elif name=='trade':v=pluck(t,1260)*.65+(pluck(t-.085,1640)*.5 if t>.085 else 0)
  elif name=='craft':v=low*3*dec(t%.12,.025)+tone(t,480)*dec(abs(t-.34),.03)*.3
  elif name in ('quest_complete','victory','puzzle_success'):
   freqs=[392,494,587] if name=='victory' else [330,440,554] if name=='quest_complete' else [523,659,784]
   v=sum(pluck(t-j*.12,f)*.7 for j,f in enumerate(freqs) if t>=j*.12)
  elif name=='puzzle_tick':v=(high*.35+tone(t,260))*dec(t,.025)
  elif name in ('attack_swing','dodge','escape'):v=(n*.22+low*2.5)*math.sin(math.pi*t/length)**2
  elif name=='impact':v=(chirp(t,135,-440)*.8+low*3)*dec(t,.05)
  elif name=='guard':v=(tone(t,210)*.65+high*.2)*dec(t,.04)+(tone(t,360)*.3*dec(t-.07,.04) if t>=.07 else 0)
  elif name=='charge':v=(chirp(t,180,350)+.25*chirp(t,360,600))*(t/length)*.65
  elif name=='fire':v=(low*4+high*.22)*(1+.25*tone(t,27))*dec(t,.23)
  elif name=='ice':v=sum(pluck(t-j*.035,940+j*311)*.55 for j in range(4) if t>=j*.035)
  elif name=='lightning':v=(high*.7+tone(t,84)*.25)*dec(t,.12)*(1 if int(t/.035)%3==0 else .28)
  elif name=='wind':v=(low*3+high*.08)*(math.sin(math.pi*t/length)**1.2)
  elif name=='light':v=(tone(t,440)+tone(t,660)*.45+tone(t,880)*.2)*dec(t,.24)
  elif name=='dark':v=(tone(t,89)+tone(t,92)*.7+low*1.5)*dec(t,.3)*(1+.15*tone(t,11))
  elif name=='barrier':v=(chirp(t,170,260)+tone(t,510)*.28+low*.5)*dec(t,.2)
  elif name=='heal':v=(tone(t,392)+.5*tone(t,588))*dec(t,.17)
  elif name=='rest':v=low*3*math.sin(math.pi*t/length)**2
  elif name=='story_rumble':v=(low*4+tone(t,54)*.5+tone(t,83)*.3)*dec(t,.35)
  elif name=='story_reveal':v=(tone(t,294)+tone(t,441)*.45+chirp(t,588,120)*.2)*math.sin(math.pi*t/length)*dec(t,.7)
  elif name=='boss_thread':v=(pluck(t,187)+pluck(t,199)*.7+chirp(t,78,-24)*.35)*dec(t,.45)
  elif name=='boss_phase':v=(high*.45*dec(t,.07)+tone(t,65)+tone(t,69)*.65+chirp(t,260,-100)*.25)*dec(t,.4)
  elif name=='break_stance':v=(high*.4+chirp(t,240,-400))*dec(t,.08)
  elif name=='defeat':v=(chirp(t,240,-100)+.3*chirp(t,360,-150))*dec(t,.3)
  else:raise ValueError(name)
  values.append(v)
 # Remove DC and soften both ends. Six voices at -12 dB remain below full scale.
 mean=sum(values)/len(values)
 values=[(v-mean)*min(1,i/(rate*.005),(len(values)-1-i)/(rate*.025)) for i,v in enumerate(values)]
 peak=max(abs(v) for v in values);values=[v*.60/max(peak,.001) for v in values]
 pcm=struct.pack('<'+'h'*len(values),*(round(v*32767) for v in values))
 path=out/(name+'.wav')
 with wave.open(str(path),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(pcm)
 records.append({'id':name,'file':name+'.wav','seconds':length,'purpose':description,'peak':round(max(abs(v) for v in values),4),'rms':round(math.sqrt(sum(v*v for v in values)/len(values)),4),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(out/'音效索引.json').write_text(json.dumps({'version':1,'author':'Original mathematical synthesis for gei子的冒险','license':'CC0-1.0','rate':rate,'channels':1,'format':'PCM signed 16-bit','max_voices':6,'voice_volume_db':-12,'cues':records},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(len(records),'original cues;',sum(p.stat().st_size for p in out.glob('*.wav')),'PCM bytes')
