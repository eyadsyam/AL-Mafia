from pathlib import Path
from html.parser import HTMLParser
import subprocess,json
import numpy as np
R=Path(__file__).resolve().parent
video=R/'exports/MAFIA_V3_صاحبك_اللي_بريء.mp4'
expected_frames=json.loads((R/'timeline.locked.json').read_text(encoding='utf-8'))['frames']
p=subprocess.Popen(['ffmpeg','-v','error','-i',str(video),'-vf','scale=180:320','-f','rawvideo','-pix_fmt','gray','pipe:1'],stdout=subprocess.PIPE)
rows=[];prev=None;run=0;longest=0
for f in range(expected_frames):
    data=p.stdout.read(180*320)
    assert len(data)==180*320,f'Could not decode frame {f}'
    arr=np.frombuffer(data,dtype=np.uint8).astype(np.int16)
    delta=float(np.abs(arr-prev).mean()) if prev is not None else None
    run=run+1 if delta is not None and delta<.01 else 0
    longest=max(longest,run)
    rows.append({'frame':f,'seconds':round(f/30,6),'luma_mean':round(float(arr.mean()),4),'near_black_percent':round(float((arr<7).mean()*100),4),'mean_delta':None if delta is None else round(delta,4)})
    prev=arr
assert not p.stdout.read(1),'Unexpected extra frames'
assert p.wait()==0
captions=[]
class Parser(HTMLParser):
    def handle_starttag(self,tag,attrs):
        d=dict(attrs)
        if tag=='section' and d.get('id','').startswith('cap'):
            a=float(d['data-start']);b=a+float(d['data-duration'])
            captions.append((d['id'],a,b))
Parser().feed((R/'project/index.html').read_text(encoding='utf-8'))
overlaps=[]
for f in range(expected_frames):
    active=[i for i,a,b in captions if a<=f/30<b]
    if len(active)>1:overlaps.append({'frame':f,'ids':active})
assert not overlaps,overlaps
assert max(x['near_black_percent'] for x in rows)<99.0
(R/'qa/every-frame.json').write_text(json.dumps({'frames_decoded':len(rows),'all_frames_caption_overlap_checked':True,'caption_overlap_frames':overlaps,'longest_pixel_identical_run_frames':longest,'interpretation':'Pixel changes do not certify anatomy or marketing quality. Review contact sheets and targeted full-size frames as well.','frames':rows},indent=2))
subprocess.run(['ffmpeg','-v','error','-i',str(video),'-vf','scale=90:160,tile=20x15','-vsync','0','-y',str(R/'qa/all-v3-frames-%02d.jpg')],check=True)
print(json.dumps({'frames_decoded':len(rows),'caption_overlaps':len(overlaps),'longest_identical_run':longest,'max_near_black_percent':max(x['near_black_percent'] for x in rows)}))
