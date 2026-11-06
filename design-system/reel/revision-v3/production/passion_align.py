from pathlib import Path
import json,re,subprocess,wave
import numpy as np
R=Path(__file__).resolve().parent
raw=json.loads((R/'research/fekry-passion1-scribe.json').read_text(encoding='utf-8'))[0]
words=[];tag=False
for w in raw['words']:
    if '[' in w['text']:tag=True
    if not tag and w.get('type')=='word':words.append(w)
    if ']' in w['text']:tag=False
log=(R/'qa/passion-silences-30.log').read_text(encoding='utf-8',errors='replace')
ss=[float(x) for x in re.findall(r'silence_start: ([\d.]+)',log)]
se=[float(x) for x in re.findall(r'silence_end: ([\d.]+)',log)]
silences=list(zip(ss,se));cuts=[]
for a,b in zip(words,words[1:]):
    lo=a['end']+.045;hi=b['start']-.045
    # Protect complete measured words and their consonant/breath edges.
    keep=.32 if b['text'].startswith('فاكر') else .16
    for s,e in silences:
        x=max(lo,s);y=min(hi,e)
        if y-x>keep+.06:cuts.append([x+keep/2,y-keep/2])
pcm=subprocess.check_output(['ffmpeg','-v','error','-i',str(R/'project/assets/audio/fekry-passion-1.mp3'),'-f','s16le','-ac','1','-ar','48000','pipe:1'])
x=np.frombuffer(pcm,dtype=np.int16)
remaining=len(x)/48000-sum(b-a for a,b in cuts)
print(json.dumps({'raw_seconds':len(x)/48000,'safe_pause_removal':sum(b-a for a,b in cuts),'working_seconds':remaining,'cuts':cuts}))
if remaining>58.1:raise SystemExit('More than58.1s after protected pause edit; do not force-fit or speed speech.')
chunks=[];pos=0
for a,b in cuts:
    ai=round(a*48000);bi=round(b*48000)
    chunks.append(x[pos:ai]);pos=bi
chunks.append(x[pos:])
for i,chunk in enumerate(chunks):
    c=chunk.copy();n=min(240,len(c)//2)
    if i>0:c[:n]=(c[:n]*np.linspace(0,1,n)).astype(np.int16)
    if i<len(chunks)-1:c[-n:]=(c[-n:]*np.linspace(1,0,n)).astype(np.int16)
    chunks[i]=c
y=np.concatenate(chunks)
with wave.open(str(R/'project/assets/audio/passion-edited.wav'),'wb') as w:
    w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes(y.tobytes())
def mapped(t):return t-sum(max(0,min(t,b)-a) for a,b in cuts if t>a)
def norm(s):return re.sub(r'[\W\u064b-\u065f]+','',s)
lines=(R.parent/'SCRIPT-A.ar.txt').read_text(encoding='utf-8').strip().splitlines()
assert norm(' '.join(w['text'] for w in words))==norm(' '.join(lines))
out=[dict(w,source_start=w['start'],source_end=w['end'],start=mapped(w['start']),end=mapped(w['end'])) for w in words]
cues=[];i=0
for j,line in enumerate(lines):
    group=[]
    while norm(' '.join(w['text'] for w in group))!=norm(line):group.append(out[i]);i+=1
    cues.append({'id':j+1,'text':line,'start':group[0]['start'],'end':group[-1]['end'],'first_frame':round(group[0]['start']*30),'last_frame':round(group[-1]['end']*30)})
old=json.loads((R.parent.parent/'revision-v2/production/timeline.locked.json').read_text(encoding='utf-8'))
anchors=[[0,0]]+[[a['start'],b['start']] for a,b in zip(old['cues'],cues)]+[[old['cues'][-1]['end'],cues[-1]['end']],[57,57.5]]
for old_t,keyword in [(22.0,'وتصوّتوا'),(30.0,'أهو')]:
    word=next(w for w in out if norm(w['text'])==norm(keyword))
    anchors.append([old_t,word['start']])
anchors.sort()
assert all(b[1]>=a[1] for a,b in zip(anchors,anchors[1:]))
d={'fps':30,'duration':57.5,'frames':1725,'voice':'Fekry passion-directed Egyptian','voice_id':'B1W8tTuESCJzhOnd15nC','source_take':'passion1','model':'eleven_v3','speech_speed_changed':False,'provider_word_timing':True,'script_match':True,'words':out,'cues':cues,'old_time_mapping':anchors,'voice_duration':len(y)/48000,'voice_edit_cuts':cuts}
(R/'timeline.locked.json').write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
(R/'qa/passion-pause-edit.json').write_text(json.dumps({'raw_seconds':len(x)/48000,'working_seconds':len(y)/48000,'cuts':cuts,'protected_word_margin_seconds':.045,'speech_speed_changed':False,'method':'Only quiet sub-intervals entirely between measured word envelopes; preserve0.16s of each ordinary gap and0.32s before reveal question.'},indent=2))
subprocess.run(['ffmpeg','-v','error','-y','-i',str(R/'project/assets/audio/passion-edited.wav'),'-af','highpass=f=80,equalizer=f=250:t=q:w=1:g=-1,equalizer=f=3000:t=q:w=1:g=1,acompressor=threshold=0.15:ratio=2:attack=10:release=120:makeup=1.1',str(R/'project/assets/audio/voice-master.wav')],check=True)
def stamp(t):
    m=round(t*1000);return f'{m//3600000:02}:{m//60000%60:02}:{m//1000%60:02},{m%1000:03}'
(R/'exports/MAFIA_V3_AR.srt').write_text('\n\n'.join(f"{c['id']}\n{stamp(c['start'])} --> {stamp(c['end'])}\n{c['text']}" for c in cues)+'\n',encoding='utf-8')
print('Aligned new passion take to57.5s root; protected words, original pitch/speed.')
