"""Read-only checks for the prepared package; never marks production gates passed."""
from pathlib import Path
import hashlib
import json
import re

root=Path(__file__).resolve().parent
errors=[]
def check(condition,message):
    if not condition:
        errors.append(message)
def read(name):
    return json.loads((root/name).read_text(encoding='utf-8'))
manifest=read('assets.manifest.json')
plan=read('timeline.plan.json')
case=read('case-public.json')
ids=[a['id'] for a in manifest['assets']]
check(len(ids)==len(set(ids)),'duplicate asset IDs')
for asset in manifest['assets']:
    p=(root/asset['path']).resolve()
    check(p.is_relative_to(root),'asset path outside package: '+asset['id'])
    check(p.is_file(),'missing asset: '+asset['id'])
    if p.is_file():
        check(hashlib.sha256(p.read_bytes()).hexdigest()==asset['sha256'],'changed frozen asset: '+asset['id'])
check(plan['fps']==30 and plan['total_frames']==1770 and plan['duration_seconds']==59,'incorrect master timing')
check(plan['status']=='PLANNED_NOT_AUDIO_ALIGNED','planning file falsely marked aligned')
scenes=plan['scenes']; cues=plan['cues']
for group,label,finish in [(scenes,'scene',1770),(cues,'cue',1710)]:
    next_start=0
    seen=set()
    for item in group:
        check(item['id'] not in seen,'duplicate '+label+' ID')
        seen.add(item['id'])
        check(item['start_frame']==next_start,'gap/overlap at '+item['id'])
        check(isinstance(item['start_frame'],int) and isinstance(item['end_frame'],int),'noninteger frame at '+item['id'])
        check(item['end_frame']>item['start_frame'],'empty span at '+item['id'])
        next_start=item['end_frame']
    check(next_start==finish,'wrong final '+label+' boundary')
cue_map={c['id']:c for c in cues}
for scene in scenes:
    for aid in scene['asset_ids']:
        check(aid in ids,'unresolved asset '+aid)
    for cid in scene['cue_ids']:
        check(cid in cue_map,'unknown cue '+cid)
        c=cue_map.get(cid,{})
        if c:
            check(scene['start_frame']<=c['start_frame']<c['end_frame']<=scene['end_frame'],'cue outside scene '+cid)
check([cid for s in scenes for cid in s['cue_ids']]==[c['id'] for c in cues],'cues missing/repeated/reordered among scenes')
for event in plan['events']:
    check(event['cue'] in cue_map,'unknown event cue')
    c=cue_map.get(event['cue'])
    if c:
        check(c['start_frame']<=event['frame']<=c['end_frame'],'event outside cue '+event['id'])
check(plan['end_hold']=={'start_frame':1710,'end_frame':1770},'wrong end hold')
plain=' '.join((root/'SCRIPT.ar.txt').read_text(encoding='utf-8').split())
joined=' '.join(c['text'] for c in cues)
check(plain==joined,'script disagrees with cue text')
tagged=(root/'SCRIPT.eleven-v3.txt').read_text(encoding='utf-8')
check(' '.join(re.sub(r'\[[^\]]+\]','',tagged).split())==plain,'tagged script has different words')
check(plan['script_word_count']==len(plain.split()),'wrong word count')
check(cues[0]['text']=='إنت المافيا. وهما لسه مايعرفوش.','wrong opening')
check(cues[-1]['text']=='ونشوف… هتتلقط من أول جولة؟','wrong ending')
check(case['actionBudget']==12,'unverified case budget')
interview=next(a for a in case['actions'] if a['id']=='interview')
check(interview['cost']==2 and case['demo']['end_budget']==10,'wrong example action arithmetic')
check(not any(k in case for k in ('truth','clues','motives','methods')),'spoiler data in public bundle')
for name in ('START_HERE.md','TREATMENT.md','VOICE_DIRECTION.md','AUDIO_EDIT_PLAN.md','VISUAL_DIRECTION.md','CHARACTER_BUILD.md','STORYBOARD.md','PRODUCTION_RUNBOOK.md','QA_CHECKLIST.md','SHORTENING.md','STATE.json','PREPARATION_REPORT.md','references/tool-contracts/eleven-v3-guide.md','references/tool-contracts/eleven-v3-schema.json'):
    check((root/name).is_file(),'missing handoff document '+name)
for mode in ('mafia','stories'):
    check((root/f'references/identity/{mode}/img/_contact_sheet.jpg').exists(),'missing reference sheet '+mode)
report={'status':'PASS' if not errors else 'FAIL','checks':'package files, frozen SHA-256, cue text, frame coverage, asset/cue references, public case arithmetic',
 'frozen_assets':len(ids),'script_words':len(plain.split()),'scenes':len(scenes),'cues':len(cues),'frames':1770,
 'production_verified':False,'limitations':['No voice generated/listened','No presenter rig generated/tested','No final alignment/render'],'errors':errors}
print(json.dumps(report,ensure_ascii=False,indent=2))
raise SystemExit(bool(errors))
