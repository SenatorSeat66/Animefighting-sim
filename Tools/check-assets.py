"""Validate resources the runtime loads by fixed paths and atlas dimensions."""
import struct,wave
from pathlib import Path
for v in range(5):
 p=Path(f'Assets/Resources/Art/fighter-{v}.png');b=p.read_bytes()
 assert b[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',b[16:24])==(2048,1536),p
 assert Path(f'Tools/fighter-{v}.blend').is_file()
for v in range(4):
 p=Path(f'Assets/Resources/Art/arena-{v}.png');b=p.read_bytes()
 assert b[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',b[16:24])==(2560,1440),p
 assert Path(f'Tools/arena-{v}.blend').is_file()
for name in ['impact','deflect']:
 with wave.open(f'Assets/Resources/Audio/{name}.wav') as w:
  assert w.getnframes()>0 and w.getframerate()==44100 and w.getnchannels()==1
print('PASS: 5 pose atlases, 4 arenas, editable Blender sources, 2 audio files')
