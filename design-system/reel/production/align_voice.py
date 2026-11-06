from pathlib import Path
import os
os.environ['HF_HUB_DISABLE_XET']='1'
import json,re,subprocess,wave,sys
import numpy as np
from faster_whisper import WhisperModel

R=Path(__file__).resolve().parent
raw=R/'assets/audio/full-2.mp3'
pcm=subprocess.check_output(['ffmpeg','-v','error','-i',str(raw),'-f','s16le','-ac','1','-ar','48000','-'])
x=np.frombuffer(pcm,dtype=np.int16)
result=subprocess.run(['ffmpeg','-hide_banner','-i',str(raw),'-af','silencedetect=noise=-35dB:d=0.25','-f','null','NUL'],capture_output=True,text=True)
starts=[float(t) for t in re.findall(r'silence_start: ([\d.]+)',result.stderr)]
ends=[float(t) for t in re.findall(r'silence_end: ([\d.]+)',result.stderr)]
gaps=list(zip(starts,ends))
# Fit the edit using silence only; preserve speech samples at native speed.
desired_removal=max(0,len(x)/48000-56.5)
lo,hi=.18,.8
for _ in range(40):
    keep=(lo+hi)/2
    removal=sum(max(0,e-s-keep) for s,e in gaps if e-s>.4)
    if removal>desired_removal:lo=keep
    else:hi=keep
keep=(lo+hi)/2
cuts=[]
for s,e in gaps:
    if e-s>.4 and e-s>keep:
        a=s+keep/2;b=e-keep/2
        if b>a:cuts.append((int(a*48000),int(b*48000)))
out=[];last=0
for a,b in cuts:out.append(x[last:a]);last=b
out.append(x[last:]);y=np.concatenate(out)
master=R/'assets/audio/voice-master.wav'
with wave.open(str(master),'wb') as w:w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes(y.tobytes())
(R/'qa/voice-edit.json').write_text(json.dumps({'raw_duration':len(x)/48000,'duration':len(y)/48000,'removed_silence_seconds':sum((b-a)/48000 for a,b in cuts),'cuts':[[a/48000,b/48000] for a,b in cuts],'speech_speed_changed':False},indent=2))
print('Working voice duration',len(y)/48000,flush=True)
if '--preprocess-only' in sys.argv:raise SystemExit(0)
print('Loading Arabic small ASR model',flush=True)
model=WhisperModel('small',device='cpu',compute_type='int8',cpu_threads=4)
segments,info=model.transcribe(str(master),language='ar',word_timestamps=True,beam_size=5,vad_filter=False)
words=[];segs=[]
for s in segments:
    segs.append({'start':s.start,'end':s.end,'text':s.text})
    words.extend({'start':w.start,'end':w.end,'word':w.word,'probability':w.probability} for w in s.words)
    print(round(s.start,2),round(s.end,2),s.text.encode('ascii','backslashreplace').decode(),flush=True)
(R/'transcripts/asr.json').write_text(json.dumps({'language':info.language,'segments':segs,'words':words,'engine':'faster-whisper-small-int8','timestamps_measured':True},ensure_ascii=False,indent=2),encoding='utf-8')
print('ASR saved',flush=True)
