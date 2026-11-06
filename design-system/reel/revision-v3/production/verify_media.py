from pathlib import Path
from html.parser import HTMLParser
import subprocess,json
R=Path(__file__).resolve().parent; P=R/'project'; clips=[];bad=[]
class Parser(HTMLParser):
    def handle_starttag(self,tag,attrs):
        d=dict(attrs)
        if tag!='video':return
        duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(P/d['src'])]))
        end=float(d.get('data-duration',0))+float(d.get('data-media-start',0))
        clips.append({'id':d['id'],'source_duration':duration,'needed_end':end,'source':d['src']})
        if end>duration+.035:bad.append(d['id'])
Parser().feed((P/'index.html').read_text(encoding='utf-8'))
(R/'qa/media-windows.json').write_text(json.dumps(clips,indent=2))
print('Video windows',len(clips),'Out of range:',bad)
assert not bad
