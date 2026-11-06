from pathlib import Path
import json,re,subprocess,wave,shutil
import numpy as np
R=Path(__file__).resolve().parent
plan=json.loads((R.parent/'timeline.plan.json').read_text(encoding='utf-8'))
w=wave.open(str(R/'assets/audio/voice-master.wav'),'rb');rate=w.getframerate();x=np.frombuffer(w.readframes(w.getnframes()),np.int16);duration=len(x)/rate
cmd=subprocess.run(['ffmpeg','-hide_banner','-i',str(R/'assets/audio/voice-master.wav'),'-af','silencedetect=noise=-35dB:d=0.25','-f','null','NUL'],capture_output=True,text=True)
starts=[float(t) for t in re.findall(r'silence_start: ([\d.]+)',cmd.stderr)]
ends=[float(t) for t in re.findall(r'silence_end: ([\d.]+)',cmd.stderr)]
regions=[];p=0
for a,b in zip(starts,ends):
    if a-p>.12:regions.append([p,a])
    p=b
if duration-p>.12:regions.append([p,duration])
counts=[2,1,3,1,1,1,1,2,2,3,2,2,3,1,3,2,4,2,2]
assert len(regions)==sum(counts),(len(regions),sum(counts),regions)
cues=[];idx=0
for cue,n in zip(plan['cues'],counts):
    parts=regions[idx:idx+n];idx+=n
    cues.append({**cue,'speech_start':parts[0][0],'speech_end':parts[-1][1],'subphrases':parts,'start_frame':round(parts[0][0]*30),'end_frame':round(parts[-1][1]*30),'alignment_method':'measured acoustic phrase groups; ASR confirmation pending'})
cm={c['id']:c for c in cues}
scenes=[]
for i,s in enumerate(plan['scenes']):
    start=0 if i==0 else cm[s['cue_ids'][0]]['start_frame']
    end=1770 if i==len(plan['scenes'])-1 else cm[plan['scenes'][i+1]['cue_ids'][0]]['start_frame']
    scenes.append({**s,'start_frame':start,'end_frame':end,'planned_frames':[s['start_frame'],s['end_frame']]})
hop=int(rate*.01);samples=[]
for i in range(0,len(x),hop):
    z=x[i:i+hop].astype(float)/32768;samples.append(float(np.sqrt(np.mean(z*z))))
scale=np.percentile(samples,85)
energy=np.clip(np.array(samples)/max(scale,.001),0,1)
smooth=[];v=0
for a in energy:
    v+=(a-v)*(.32 if a>v else .22);smooth.append(round(v,4))
locked={**plan,'status':'AUDIO_PHRASE_TIMED_ASR_PENDING','cues':cues,'scenes':scenes,'voice_duration':duration,'end_hold':{'start_frame':round(duration*30),'end_frame':1770},'speech_regions':regions,'energy_hop':.01,'energy':smooth}
(R/'timeline.locked.json').write_text(json.dumps(locked,ensure_ascii=False,indent=2),encoding='utf-8')
def ts(t):
    ms=round(t*1000);return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'
(R/'transcripts/transcript.srt').write_text('\n\n'.join(f"{i+1}\n{ts(c['speech_start'])} --> {ts(c['speech_end'])}\n{c['text']}" for i,c in enumerate(cues))+'\n',encoding='utf-8')
P=R/'project';(P/'assets/art').mkdir(parents=True,exist_ok=True);(P/'assets/audio').mkdir(parents=True,exist_ok=True);(P/'assets/character').mkdir(parents=True,exist_ok=True);(P/'assets/fonts').mkdir(parents=True,exist_ok=True)
manifest=json.loads((R.parent/'assets.manifest.json').read_text(encoding='utf-8'))['assets'];assets={}
for a in manifest:
    if a['id'].startswith('font_'):
        dest=P/'assets/fonts'/Path(a['path']).name
    elif a['path'].startswith('references/art/'):
        dest=P/'assets/art'/(a['id']+Path(a['path']).suffix)
        assets[a['id']]=dest.relative_to(P).as_posix()
    else:continue
    shutil.copy2(R.parent/a['path'],dest)
for f in (R/'assets/character').glob('*.png'):shutil.copy2(f,P/'assets/character'/f.name)
shutil.copy2(R/'assets/audio/voice-master.wav',P/'assets/audio/voice-master.wav')
shutil.copy2(R.parent/'references/audio/score_loop.ogg',P/'assets/audio/score.ogg')
shutil.copy2(R.parent/'references/audio/card_flip.ogg',P/'assets/audio/card.ogg')
data={**locked,'assets':assets}
(P/'data.js').write_text('window.REEL_DATA='+json.dumps(data,ensure_ascii=False)+';',encoding='utf-8')
print(json.dumps({'speech_regions':len(regions),'voice_duration':duration,'scene_times':[[s['id'],s['start_frame']/30,s['end_frame']/30] for s in scenes]},ensure_ascii=False))
