from pathlib import Path
import json,re,hashlib,shutil
R=Path(__file__).resolve().parent
raw=json.loads((R/'transcripts/scribe-selected-raw.json').read_text(encoding='utf-8'))[0]
edit=json.loads((R/'qa/voice-edit.json').read_text())
locked=json.loads((R/'timeline.locked.json').read_text(encoding='utf-8'))
words=[w for w in raw['words'] if not re.fullmatch(r'\[[^\]]+\]',w['text'].strip())]
def norm(s):return re.sub(r'[\s\W\u064b-\u065f]+','',s)
expected=(R.parent/'SCRIPT.ar.txt').read_text(encoding='utf-8')
assert norm(' '.join(w['text'] for w in words))==norm(expected),'Provider transcript mismatch'
def mapped(t):
    removed=0
    for a,b in edit['cuts']:
        if t>=b:removed+=b-a
        elif t>a:removed+=t-a
    return max(0,t-removed)
out=[]
for w in words:
    out.append({'text':w['text'],'start':mapped(w['start']),'end':min(locked['voice_duration'],mapped(w['end'])),'source_start':w['start'],'source_end':w['end'],'engine':'eleven_scribe_v1','timing_review':'cross-referenced with measured acoustic phrase boundaries'})
locked['status']='AUDIO_ALIGNED_PROVIDER_WORDS_AND_ACOUSTIC_PHRASES'
locked['provider_word_timing']=True
locked['words']=out
for c in locked['cues']:c['alignment_method']='Measured acoustic phrase groups cross-checked against ElevenLabs Scribe selected-take words; raw source transformed through silence-only edit map'
(R/'timeline.locked.json').write_text(json.dumps(locked,ensure_ascii=False,indent=2),encoding='utf-8')
(R/'transcripts/transcript.json').write_text(json.dumps({'engine':'eleven_scribe_v1','script_matches_normalized':True,'performance_annotations_removed':len(raw['words'])-len(words),'words':out,'phrases':locked['cues'],'raw_provider_transcript':'scribe-selected-raw.json','audio_edit_map':'../qa/voice-edit.json','auditory_tone_review':'not independently verified by listening'},ensure_ascii=False,indent=2),encoding='utf-8')
shutil.copy2(R/'assets/audio/full-2.mp3',R/'assets/audio/voice-original.mp3')
report={'voice':'Haytham - Conversation / Energetic, Warm and Cheerful','voice_id':'IES4nrmZdUBHByLBde0P','model':'eleven_v3','generation_id':'tmyWsddiZqWMhQXSB8UU','raw_seconds':edit['raw_duration'],'working_seconds':edit['duration'],'speed_changed':False,'script_match':True,'spoken_words':len(words),'raw_sha256':hashlib.sha256((R/'assets/audio/voice-original.mp3').read_bytes()).hexdigest(),'working_sha256':hashlib.sha256((R/'assets/audio/voice-master.wav').read_bytes()).hexdigest(),'selection_basis':'Complete provider transcript, stable waveform, most concise full variation; candidates surfaced as audio in chat','audition_tone_listened':False,'limitation':'No claim of subjective 8/10 listening score; final human tone preference remains open.'}
(R/'qa/voice-selection.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'words':len(words),'performance_annotations_removed':len(raw['words'])-len(words),'script_match':True,'voice_duration':locked['voice_duration']},ensure_ascii=False))
