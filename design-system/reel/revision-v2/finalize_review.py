"""Freeze review assets and record the owner's rejection without losing V1 provenance."""
from pathlib import Path
import hashlib,json,re

ROOT=Path(__file__).resolve().parent
REEL=ROOT.parent
assets=[]
for p in sorted((ROOT/'assets').iterdir()):
    if p.is_file():
        assets.append({'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(ROOT/'assets.manifest.json').write_text(json.dumps(assets,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
script=(ROOT/'SCRIPT-A.ar.txt').read_text(encoding='utf-8')
(ROOT/'research'/'arabic-length.json').write_text(json.dumps({'words_whitespace':len(script.split()),'lines':len(script.strip().splitlines()),'planning_range_seconds':[56,59],'audio_aligned':False,'english_skill_timing_rejected':True},indent=2)+'\n',encoding='utf-8')
state=json.loads((REEL/'STATE.json').read_text(encoding='utf-8-sig'))
if 'revision_v2' not in state:
    state['previous_delivery']={'version':1,'phase':state.get('phase'),'outputs':state.get('outputs'),'creative_acceptance':'rejected_by_owner','reason':'Weak hook, static-character treatment, marketing execution rejected; Haytham voice rejected.'}
state['phase']='revision_v2_concept_review'
for key in ['voice','character','timing','milestones']:
    if key in state and key not in state['previous_delivery']:
        state['previous_delivery'][key]=state[key]
state['revision_v2']={'user_request':'Ideas and HTML first; rebuild hook, cast, environments, product demonstration and acting; Adam instead of Haytham.','status':'reviewable_concepts_ready','preferred_voice':{'name':'Adam - Deep, Rich and Expressive','voice_id':'OFHP1Qg30FPoNfkUFFlA','language':'ar','accent':'egyptian','catalogue_verified':True,'new_audio_generated':False},'recommended_direction':'A spine + B brief mascot cameo + C story material transition','selected_by_owner':None,'concept_page':'revision-v2/index.html','preview_url':'http://127.0.0.1:3033/design-system/reel/revision-v2/index.html','treatment':'revision-v2/README.md','script':'revision-v2/SCRIPT-A.ar.txt','generated_art_assets':3,'production_started':False,'full_video_rendered':False,'character_animation_completed':False,'qa':'revision-v2/QA.md'}
state['known_dependencies']=['Owner direction feedback after this requested ideas-first review.','Adam short audition and listening review before full narration.','Approved acting clips, additional true gameplay captures and measured word alignment before full V2 production.']
state['last_note']='Owner rejected V1 creatively. Three fresh concepts, three imagegen assets, real app screenshot references and silent seekable HTML camera proof prepared. Previous video/voice/audio technical evidence preserved; no V2 final video claim.'
state['outputs']={'concept_page':str(ROOT/'index.html'),'preview':'http://127.0.0.1:3033/design-system/reel/revision-v2/index.html','treatment':str(ROOT/'README.md'),'script':str(ROOT/'SCRIPT-A.ar.txt'),'qa_report':str(ROOT/'QA.md')}
state['production_started']=False
state['voice']=dict(state['revision_v2']['preferred_voice'])
state['voice']['audio_generated']=False
state['character']={'cast_sheet':'revision-v2/assets/cast-sheet.png','development_stills_ready':True,'performance_clips_ready':False}
state['timing']={'plan':'revision-v2/README.md','locked':None,'aligned':False}
state['milestones']={'concept_page':True,'art_development':True,'product_reference_capture':True,'voice_gate':False,'character_gate':False,'picture_gate':False,'audio_mix_gate':False,'render_gate':False}
(REEL/'STATE.json').write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
start=REEL/'START_HERE.md'
note='> **CURRENT — 2026-10-11 / V2 concept review:** Owner rejected the first video and Haytham. Read `STATE.json`, then `revision-v2/README.md` and open `revision-v2/index.html`. The latest request is ideas first, not another full render yet. Do not resume V1 as an approved direction.\n\n'
old=start.read_text(encoding='utf-8-sig')
if not old.startswith(note):start.write_text(note+old,encoding='utf-8')
# Verify local HTML/CSS assets. External references are plain outbound links.
paths=[]
for name in ['index.html','style.css']:
    data=(ROOT/name).read_text(encoding='utf-8')
    paths+=re.findall(r'(?:src|href)="([^"]+)"',data) if name.endswith('.html') else re.findall(r'url\([\'\"]?([^\)\'\"]+)',data)
missing=[p for p in paths if not p.startswith(('http','#')) and not (ROOT/p).exists()]
assert not missing,missing
print(json.dumps({'assets':len(assets),'script_words':len(script.split()),'local_links':'passed','state_phase':state['phase']}))
