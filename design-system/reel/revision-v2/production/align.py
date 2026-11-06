from pathlib import Path
import json,re,subprocess
R=Path(__file__).resolve().parent
raw=json.loads((R/'research/adam-take2-scribe.json').read_text(encoding='utf-8'))[0]
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
subprocess.run(['ffmpeg','-v','error','-y','-i',str(R/'project/assets/audio/adam-take-2.mp3'),'-ar','48000','-ac','1',str(R/'project/assets/audio/voice-master.wav')],check=True)
data={'fps':30,'duration':57,'frames':1710,'voice':'Adam Egyptian','source_take':2,'speech_speed_changed':False,'provider_word_timing':True,'script_match':True,'words':words,'cues':cues}
(R/'timeline.locked.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
def stamp(t):
    ms=round(t*1000); return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'
(R/'exports/MAFIA_V2_AR.srt').write_text('\n\n'.join(f"{c['id']}\n{stamp(c['start'])} --> {stamp(c['end'])}\n{c['text']}" for c in cues)+'\n',encoding='utf-8')
s=json.loads((R.parent.parent/'STATE.json').read_text(encoding='utf-8'))
s['voice']['new_audio_generated']=True;s['voice']['audio_generated']=True;s['voice']['selected_take']=2
s['timing']={'locked':'revision-v2/production/timeline.locked.json','aligned':True,'duration':57,'fps':30,'word_source':'ElevenLabs Scribe selected Adam take 2'}
s['milestones']['voice_gate']=True
(R.parent.parent/'STATE.json').write_text(json.dumps(s,ensure_ascii=False,indent=2),encoding='utf-8')
for c in cues:print(c['id'],round(c['start'],2),round(c['end'],2),c['text'].encode('ascii','backslashreplace').decode())
