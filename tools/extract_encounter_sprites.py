from PIL import Image
from collections import deque
from pathlib import Path
import json,hashlib
p=Path('assets/npc textures/ENCOUNTERS-SHEET.png'); src=Image.open(p).convert('RGBA')
# Original 2000px sheet: 12px outer border, 20px dividers, 644px cells.
# Read exact divider runs from the source; no resize or colour thresholding.
pix=src.load(); w,h=src.size
runs=[]; start=None
for x in range(w):
 black=pix[x,12][:3]==(0,0,0)
 if black and start is None:start=x
 if not black and start is not None:runs.append((start,x));start=None
if start is not None:runs.append((start,w))
# Cross-section y=12 is inside the unoccupied top margin of every cell.
assert len(runs)==3, runs
names=['Purrrresents!','FireKittens','TopCat','Sharpurr','BiNarty','Toasters','2kMEOWpH','Sir Swirlur']
records=[]
for i,name in enumerate(names):
 x0,x1=runs[i%3]; y0,y1=runs[i//3]
 im=src.crop((x0,y0,x1,y1)); px=im.load(); cw,ch=im.size
 seen=set(); todo=deque()
 for x in range(cw):todo.extend([(x,0),(x,ch-1)])
 for y in range(ch):todo.extend([(0,y),(cw-1,y)])
 while todo:
  x,y=todo.popleft()
  if (x,y) in seen or not(0<=x<cw and 0<=y<ch) or px[x,y][:3]!=(0,0,0):continue
  seen.add((x,y)); px[x,y]=(0,0,0,0)
  todo.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
 bbox=im.getbbox(); assert bbox
 im=im.crop(bbox)
 path=Path(f'assets/encounters/enemy_{i}.png');im.save(path,optimize=True)
 records.append(dict(index=i,name=name,cell=[x0,y0,x1-x0,y1-y0],occupied_bbox=list(bbox),file=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
manifest=dict(source=str(p),source_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),method='Lossless crop; flood-fill only exact RGB(0,0,0) connected to cell perimeter to alpha zero. All retained RGB and alpha values unchanged. No thresholding, repainting or resampling.',sprites=records)
Path('resources/encounters/sprite-provenance.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Source',src.size,'cell runs',runs,'extracted',len(records))
