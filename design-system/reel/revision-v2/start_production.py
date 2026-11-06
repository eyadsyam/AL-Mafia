from pathlib import Path
import json,shutil
R=Path(__file__).resolve().parent
P=R/'production'
for d in ['project/assets/video','project/assets/audio','project/assets/art','project/assets/fonts','project/assets/vendor','exports','qa','research']:
    (P/d).mkdir(parents=True,exist_ok=True)
old=R.parent/'production/project'
for d in ['fonts','vendor']:
    shutil.copytree(old/'assets'/d,P/'project/assets'/d,dirs_exist_ok=True)
for name in ['score.ogg','card.ogg']:
    shutil.copy2(old/'assets/audio'/name,P/'project/assets/audio'/name)
for f in (R/'assets').iterdir():
    if f.is_file(): shutil.copy2(f,P/'project/assets/art'/f.name)
shutil.copy2(old/'hyperframes.json',P/'project/hyperframes.json')
s=json.loads((R.parent/'STATE.json').read_text(encoding='utf-8'))
s['phase']='revision_v2_acting_production'
s['production_started']=True
s['revision_v2']['production_started']=True
s['revision_v2']['selected_by_owner']='A: صاحبك اللي بريء; latest user authorizes one complete film first'
s['creative_flow_id']='VGfqmPBQWx3ZImBHYd2P'
s['active_runs']={'hook':{'node':'ogcuZlBSpadGukceSCBr','sessions':['r3ueDkkxpDeNcPHwlItP']},'voice':{'sessions':['q2nQqeaEjsGfAuwGLu74','hSiMxttwmBNsPINYMGRo','mllgXGeJa32YUp5zEvHw','yAHY7sanYNVgBr6E35jj']}}
s['known_dependencies']=['Finish and inspect acting clips, Adam narration, measured timeline, picture/audio/render QA.']
(R.parent/'STATE.json').write_text(json.dumps(s,ensure_ascii=False,indent=2),encoding='utf-8')
print(str(P))
