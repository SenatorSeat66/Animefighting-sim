"""Original short synthesized sword impacts; no sampled third-party recordings."""
import math,random,wave,struct
from pathlib import Path
random.seed(81);out=Path('Assets/Resources/Audio');out.mkdir(parents=True,exist_ok=True)
for name,base in [('impact',230),('deflect',1350)]:
 sr=44100;frames=[]
 for i in range(int(sr*.55)):
  t=i/sr;env=math.exp(-t*(14 if name=='impact' else 10))
  v=(math.sin(t*math.tau*base)+.35*math.sin(t*math.tau*base*2.71)+.22*random.uniform(-1,1))*env*.43
  frames.append(struct.pack('<h',int(max(-1,min(1,v))*32767)))
 with wave.open(str(out/(name+'.wav')),'wb') as w:w.setparams((1,2,sr,0,'NONE','NONE'));w.writeframes(b''.join(frames))
