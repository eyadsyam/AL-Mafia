from pathlib import Path
import subprocess,json,argparse
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parent;P=R.parent
parser=argparse.ArgumentParser();parser.add_argument('--video',default=str(P/'exports/MAFIA_REEL_DRAFT.mp4'));args=parser.parse_args();video=Path(args.video).resolve()
def extract(name,frames,scale='360:640'):
    target=R/name;target.mkdir(exist_ok=True)
    select='+'.join(f'eq(n,{n})' for n in sorted(set(frames)))
    subprocess.run(['ffmpeg','-v','error','-i',str(video),'-vf',f"select='{select}',scale={scale}",'-fps_mode','vfr','-y',str(target/'frame-%03d.jpg')],check=True)
    return sorted(target.glob('frame-*.jpg'))
def sheet(name,files,labels,columns=5):
    width=270;height=480;rows=(len(files)+columns-1)//columns
    for begin in range(0,len(files),15):
        subset=files[begin:begin+15];rows=(len(subset)+columns-1)//columns
        im=Image.new('RGB',(columns*width,rows*(height+25)),(18,18,18));d=ImageDraw.Draw(im)
        for i,file in enumerate(subset):
            thumb=Image.open(file).convert('RGB');thumb=thumb.resize((width,height))
            x=(i%columns)*width;y=(i//columns)*(height+25)
            im.paste(thumb,(x,y+25));d.text((x+8,y+5),str(labels[begin+i]),fill=(230,230,230))
        im.save(R/f'{name}-{begin//15+1}.jpg',quality=88)
D=json.loads((P/'timeline.locked.json').read_text(encoding='utf-8'))
frames=list(range(0,1770,30));files=extract('film-frames',frames);sheet('film-contact',files,[f'{x/30:.2f}s' for x in frames])
boundaries=[s['start_frame'] for s in D['scenes'][1:]]
frames=sorted(set(max(0,min(1769,b+d)) for b in boundaries for d in [-2,-1,0,1,2]));files=extract('transition-frames',frames);sheet('transition-sheet',files,[f'f{x}' for x in frames])
frames=[0,3,6,12,15,24,36,60,84,120,164];files=extract('opening-frames',frames);sheet('opening-strip',files,[f'f{x}' for x in frames])
frames=[1540,1550,1620,1695,1769];files=extract('end-frames',frames);sheet('end-strip',files,[f'f{x}' for x in frames])
print('Encoded-video QA sheets ready')
