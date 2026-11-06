from pathlib import Path
import json,re,subprocess
R=Path(__file__).resolve().parent
raw=json.loads((R/'research/fekry-take2-scribe.json').read_text(encoding='utf-8'))[0]
# Provider retains performance annotations in metadata; they are not captions.
words=[];tag=False
for w in raw['words']:
    if '[' in w['text']: tag=True
    if not tag and w.get('type')=='word': words.append(w)
    if ']' in w['text']: tag=False
def norm(s): return re.sub(r'[\W\u064b-\u065f]+','',s)
lines=(R.parent/'SCRIPT-A.ar.txt').read_text(encoding='utf-8').strip().splitlines()
assert norm(' '.join(w['text'] for w in words))==norm(' '.join(lines))
cues=[];i=0
for j,line in enumerate(lines):
    collected=[];target=norm(line)
    while norm(' '.join(w['text'] for w in collected))!=target:
        collected.append(words[i]);i+=1
        assert len(collected)<30
    cues.append({'id':j+1,'text':line,'start':collected[0]['start'],'end':collected[-1]['end'],'first_frame':round(collected[0]['start']*30),'last_frame':round(collected[-1]['end']*30)})
subprocess.run(['ffmpeg','-v','error','-y','-i',str(R/'project/assets/audio/fekry-take-2.mp3'),'-ar','48000','-ac','1','-af','highpass=f=80,equalizer=f=250:t=q:w=1:g=-1.5,equalizer=f=3000:t=q:w=1:g=1.2,acompressor=threshold=0.15:ratio=2:attack=10:release=120:makeup=1.15',str(R/'project/assets/audio/voice-master.wav')],check=True)
old=json.loads((R.parent.parent/'revision-v2/production/timeline.locked.json').read_text(encoding='utf-8'))
anchors=[[0,0]]+[[a['start'],b['start']] for a,b in zip(old['cues'],cues)]+[[old['cues'][-1]['end'],cues[-1]['end']],[57,52]]
data={'fps':30,'duration':52,'frames':1560,'voice':'Fekry Egyptian','voice_id':'B1W8tTuESCJzhOnd15nC','source_take':2,'speech_speed_changed':False,'provider_word_timing':True,'script_match':True,'words':words,'cues':cues,'old_time_mapping':anchors,'voice_duration':50.43374149659864}
(R/'timeline.locked.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
def stamp(t):
    ms=round(t*1000); return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'
(R/'exports/MAFIA_V3_AR.srt').write_text('\n\n'.join(f"{c['id']}\n{stamp(c['start'])} --> {stamp(c['end'])}\n{c['text']}" for c in cues)+'\n',encoding='utf-8')
s=json.loads((R.parent.parent/'STATE.json').read_text(encoding='utf-8'))
s['voice']={'name':'Fekry | Egyptian Arabic','voice_id':'B1W8tTuESCJzhOnd15nC','model':'eleven_multilingual_v2','new_audio_generated':True,'audio_generated':True,'selected_take':2,'owner_authorized_other_egyptian_male':True}
s['timing']={'locked':'revision-v3/production/timeline.locked.json','aligned':True,'duration':52,'fps':30,'word_source':'ElevenLabs Scribe Fekry take 2'}
s['revision_v3']['voice_gate']=True
(R.parent.parent/'STATE.json').write_text(json.dumps(s,ensure_ascii=False,indent=2),encoding='utf-8')
for c in cues:print(c['id'],round(c['start'],2),round(c['end'],2),c['text'].encode('ascii','backslashreplace').decode())
