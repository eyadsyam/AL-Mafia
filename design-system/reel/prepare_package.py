"""Freeze references and write planning data only. Does not generate/render media."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parent
WORK = ROOT.parent.parent
EPIC = WORK.parent / 'epic-roentgen-094f21'

def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

archive = ROOT / 'archive' / 'v1'
archive.mkdir(parents=True, exist_ok=True)
for filename in ('TREATMENT.md', 'SCRIPT.ar.txt'):
    old = ROOT / filename
    if old.exists() and not (archive / filename).exists():
        shutil.copy2(old, archive / filename)

asset_specs = [
 ('mafia_gallery', WORK/'assets/images/gallery/gallery_mafia.webp', 'art/mafia/gallery_mafia.webp', 'Strict presenter identity reference; derive a separate seated promotional asset.'),
 ('card_mafia', WORK/'assets/images/card_face_mafia.webp', 'art/mafia/card_mafia.webp', 'Whole unmodified role card.'),
 ('card_doctor', WORK/'assets/images/card_face_doctor.webp', 'art/mafia/card_doctor.webp', 'Whole unmodified role card.'),
 ('card_detective', WORK/'assets/images/card_face_detective.webp', 'art/mafia/card_detective.webp', 'Whole unmodified role card.'),
 ('card_citizen', WORK/'assets/images/card_face_citizen.webp', 'art/mafia/card_citizen.webp', 'Whole unmodified citizen card for public illustrative result.'),
 ('card_back', WORK/'assets/images/card_back.webp', 'art/mafia/card_back.webp', 'Card backs for mystery/online roles.'),
 ('stage_chair', WORK/'design-system/mafia/img/stage/chair.webp', 'art/mafia/stage_chair.webp', 'Reference-resolution setting; not an empty chair layer.'),
 ('stage_door', WORK/'design-system/mafia/img/stage/door.webp', 'art/mafia/stage_door.webp', 'Stage reference; brief insert only at suitable scale.'),
 ('stage_street', WORK/'design-system/mafia/img/stage/street.webp', 'art/mafia/stage_street.webp', 'Stage reference; brief insert only at suitable scale.'),
 ('night_ground', WORK/'assets/images/bg_night.webp', 'art/mafia/night.webp', 'Night illustration.'),
 ('day_ground', WORK/'assets/images/bg_day.webp', 'art/mafia/day.webp', 'Day illustration.'),
 ('brand_mark', WORK/'assets/images/splash_mask.webp', 'art/mafia/brand_mark.webp', 'Real brand art; typeset wordmark separately.'),
 ('avatar_male', EPIC/'assets/images/online/avatar_male.webp', 'art/mafia/avatar_male.webp', 'Generic online editorial seat, not a real person.'),
 ('avatar_female', EPIC/'assets/images/online/avatar_female.webp', 'art/mafia/avatar_female.webp', 'Generic online editorial seat, not a real person.'),
 ('offline_table', EPIC/'assets/images/offline/bg_table_offline.webp', 'art/mafia/offline_table.webp', 'Offline table illustration.'),
 ('story_desk', EPIC/'assets/images/stories/evidence_desk.webp', 'art/stories/evidence_desk.webp', 'Warm Stories setting.'),
 ('case_cover', EPIC/'assets/images/stories/covers/cover_01.webp', 'art/stories/cover_01.webp', 'Verified قهوة المعلم cover.'),
 ('case_location', EPIC/'assets/images/stories/locations/loc_cafe_alley.webp', 'art/stories/loc_cafe_alley.webp', 'Verified case scene.'),
 ('case_evidence', EPIC/'assets/images/stories/evidence/evidence_01.webp', 'art/stories/evidence_01.webp', 'Verified case evidence illustration; no fabricated clue.'),
 ('suspect_reda', EPIC/'assets/images/stories/suspect_n24.webp', 'art/stories/suspect_n24.webp', 'رضا المكوجي; cast portrait only, no guilt implied.'),
 ('suspect_sameh', EPIC/'assets/images/stories/suspect_n27.webp', 'art/stories/suspect_n27.webp', 'سامح صابر; cast portrait only, no guilt implied.'),
 ('suspect_ezza', EPIC/'assets/images/stories/suspect_n20.webp', 'art/stories/suspect_n20.webp', 'عزة بائعة الورد; cast portrait only, no guilt implied.'),
 ('sfx_card', WORK/'assets/audio/card_flip.ogg', 'audio/card_flip.ogg', 'Candidate; audition before use.'),
 ('sfx_night', WORK/'assets/audio/night_falls.ogg', 'audio/night_falls.ogg', 'Candidate; audition before use.'),
 ('sfx_morning', WORK/'assets/audio/morning.ogg', 'audio/morning.ogg', 'Candidate; audition before use.'),
 ('score_candidate', WORK/'assets/audio/score_loop.ogg', 'audio/score_loop.ogg', 'Candidate music; not yet auditioned.'),
 ('identity_hub', WORK/'design-system/index.html', 'identity/index.html', 'Self-contained identity hub snapshot.'),
 ('identity_readme', WORK/'design-system/README.md', 'identity/README.md', 'Design-system entry snapshot.'),
]
for mode in ('mafia','stories'):
    for filename in ('IDENTITY.md','tokens.json','tokens.css','index.html'):
        asset_specs.append((f'{mode}_{filename}', WORK/'design-system'/mode/filename, f'identity/{mode}/{filename}', 'Frozen design-system reference.'))
    for source in (WORK/'design-system'/mode/'img').rglob('*'):
        if source.is_file():
            relative = source.relative_to(WORK/'design-system'/mode).as_posix()
            asset_specs.append((f'{mode}_reference_{relative}', source, f'identity/{mode}/{relative}', 'Original curated reference; sheet may display the documented stale duplicate paths.'))
for font in (WORK/'design-system/fonts').iterdir():
    if font.is_file():
        asset_specs.append((f'font_{font.stem}', font, f'identity/fonts/{font.name}', 'Local font/licence; preserve Arabic shaping.'))

manifest = []
for key, source, dest, use in asset_specs:
    if not source.is_file():
        raise FileNotFoundError(source)
    output = ROOT/'references'/dest
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, output)
    item = dict(id=key, path=output.relative_to(ROOT).as_posix(), source=str(source),
                sha256=hashlib.sha256(output.read_bytes()).hexdigest(), bytes=output.stat().st_size,
                use=use, status='existing_frozen', modified=False)
    if output.suffix.lower() in ('.webp','.png','.jpg'):
        with Image.open(output) as im:
            item.update(width=im.width, height=im.height, mode=im.mode)
    manifest.append(item)
write_json(ROOT/'assets.manifest.json', {'version':2,'date':'2026-10-10','assets':manifest,
 'not_yet_created':['canonical seated presenter','registered presenter layers','voice audition','full voice','locked alignment','final video'],
 'source_art_policy':'Frozen copies only. No raster editing performed by this script.'})

case_source=EPIC/'assets/stories/qahwet_el_moallem.json'
case=json.loads(case_source.read_text(encoding='utf-8'))
write_json(ROOT/'case-public.json', {
 'title':case['title'], 'id':case['id'], 'actionBudget':case['actionBudget'],
 'source':str(case_source), 'source_sha256':hashlib.sha256(case_source.read_bytes()).hexdigest(),
 'coverImage':case['coverImage'], 'sceneImage':case['sceneImage'], 'evidenceImage':case['evidenceImage'],
 'cast':[{'name':c['name'],'image':c['image']} for c in case['characters'][:3]],
 'actions':[{'id':a['id'],'title':a['title'],'cost':a['cost']} for a in case['actions']],
 'demo':{'action':'interview','start_budget':12,'cost':2,'end_budget':10},
 'spoiler_policy':'No truth, motives, private objectives, culprit, clue body or solution included.'})

# End-exclusive frame budgets, not recorded speech alignment.
rows = [
 ('C01',0,84,'إنت المافيا. وهما لسه مايعرفوش.','[confident]','Direct to viewer; emphasize إنت. Confidential but audible second sentence.','100–180 ms after first sentence.'),
 ('C02',84,165,'هتعرف تخلّص الجولة من غير ما تتكشف؟','[curious]','Natural challenge; clear questioning finish.','Small breath at end.'),
 ('C03',165,315,'دي سيد المافيا. تلعبها أونلاين مع صحابك، كل واحد من مكانه.','[conversational]','Friendly brisk explanation; articulate online and brand.','Short phrase break after brand, not dramatic.'),
 ('C04',315,354,'دورك في السر.','','Concise, matter-of-fact.','No long pause.'),
 ('C05',354,435,'بالليل، المافيا تختار ضحيتها.','','Explain, not threaten.','Small separator before next role.'),
 ('C06',435,495,'الدكتور يحاول ينقذ حد،','','Emphasize يحاول; save is not guaranteed.','Comma only.'),
 ('C07',495,555,'والمحقق يكشف دور لاعب.','','Clear role name.','Reset before day.'),
 ('C08',555,630,'الصبح بقى… تبتدي الأسئلة.','[curious]','Energy drops briefly then curiosity rises.','150–250 ms at ellipsis.'),
 ('C09',630,720,'مين بيكدب؟ ومين بيغيّر كلامه؟','','Two audible distinct questions.','100–180 ms between questions.'),
 ('C10',720,810,'تتناقشوا، تصوّتوا، وتطلّعوا حد.','[conversational]','Three actions with natural progression.','Brief commas.'),
 ('C11',810,900,'طلّعتوا بريء؟ المافيا بتشكركم.','[dryly]','Dry joke, tiny smile in voice, no laugh.','150–250 ms after بريء.'),
 ('C12',900,990,'ومتجمعين في قعدة؟ العبوا أوفلاين.','[conversational]','Casual option, pronounce offline clearly.','Small question pause.'),
 ('C13',990,1110,'طيب… كفاية تخبّي. تعالى اكشف مين عملها.','','Shift viewer from hiding to investigating. Inviting.','150–220 ms after طيب, short after تخبّي.'),
 ('C14',1110,1245,'في قصص وتحقيقات، تفتح قضية زي قهوة المعلم.','','Specific case, clear title, no documentary announcer.','Comma only.'),
 ('C15',1245,1335,'تسأل الشخصيات، تفتّش، وتقارن الأدلة.','','Concrete actions.','Short commas.'),
 ('C16',1335,1425,'بس تحرّكاتك محدودة… هتبدأ بمين؟','[curious]','Point out resource limit; invite a real choice.','200–300 ms before question.'),
 ('C17',1425,1545,'وفي الآخر: مين عملها؟ ليه؟ وإزاي؟','','Three clear questions, no rapid list blur.','~150 ms between questions.'),
 ('C18',1545,1620,'سيد المافيا. ابعت لصحابك.','[conversational]','Simple name and invitation.','Short full stop.'),
 ('C19',1620,1710,'ونشوف… هتتلقط من أول جولة؟','[mischievously]','Light challenge; natural pitch; no growl or laugh.','~180 ms after ونشوف.'),
]
cues=[{'id':i,'start_frame':s,'end_frame':e,'text':t,'tag':tag,'delivery':d,'pause_guidance':p,
       'timing_status':'editorial_target_not_measured'} for i,s,e,t,tag,d,p in rows]
plain='\n'.join(c['text'] for c in cues)+'\n'
tagged='\n'.join((c['tag']+' ' if c['tag'] else '')+c['text'] for c in cues)+'\n'
(ROOT/'SCRIPT.ar.txt').write_text(plain,encoding='utf-8')
(ROOT/'SCRIPT.eleven-v3.txt').write_text(tagged,encoding='utf-8')
(ROOT/'VOICE_AUDITION.eleven-v3.txt').write_text('[confident] إنت المافيا. وهما لسه مايعرفوش.\n[conversational] تلعبها أونلاين مع صحابك، كل واحد من مكانه.\n[dryly] طلّعتوا بريء؟ المافيا بتشكركم.\n[curious] هتبدأ بمين؟\n',encoding='utf-8')

scene_specs=[
 ('S01',0,165,['C01','C02'],'mafia','Host close → medium; deal card to viewer.','مافيا أونلاين / إنت المافيا',['mafia_gallery','card_mafia','stage_chair'], 'Voice onset, card contact; badge from frame 0.'),
 ('S02',165,315,['C03'],'mafia','Three generic player areas become one editorial game arrangement; not a fake UI.','سيد المافيا / كل واحد من مكانه',['avatar_male','avatar_female','card_back'],'Online word; optional real footage only if readily available.'),
 ('S03',315,354,['C04'],'mafia','Whole Mafia role card foreground; other cards face-down.','دورك في السر',['card_mafia','card_back'],'Role reveal at phrase onset.'),
 ('S04',354,555,['C05','C06','C07'],'mafia','Night backdrop; role cards in spoken order, one dominant at a time.','بالليل',['night_ground','card_mafia','card_doctor','card_detective'],'Cuts at each role name, not within a word.'),
 ('S05',555,810,['C08','C09','C10'],'mafia','Day street → portrait group with suspicion focus → public vote illustration.','الصبح / النقاش / التصويت',['day_ground','stage_street','avatar_male','avatar_female','card_back'],'One action per phrase; no fake dialogue bubbles.'),
 ('S06',810,900,['C11'],'mafia','Whole citizen card exits group, then close host reaction.','',['card_citizen','mafia_gallery'],'Host reaction on بتشكركم; brief music dip.'),
 ('S07',900,990,['C12'],'mafia','Offline table; card passes between two positions.','أوفلاين كمان',['offline_table','card_back'],'Pass follows العبوا أوفلاين.'),
 ('S08',990,1110,['C13'],'mafia','Host leaves card at match-cut anchor; withdraws hand.','',['mafia_gallery','card_back'],'Prepare folder geometry, no Stories image yet.'),
 ('S09',1110,1245,['C14'],'stories','Hard match cut to folder at card position; reveal warm desk and case cover.','قصص وتحقيقات / قهوة المعلم',['story_desk','case_cover','case_location'],'Identity boundary at قصص وتحقيقات, adjusted to actual cue.'),
 ('S10',1245,1425,['C15','C16'],'stories','Public cast photos and action slips; choose interview, 12→10, evidence art.','تحرّكاتك محدودة',['suspect_reda','suspect_sameh','suspect_ezza','case_evidence','story_desk'],'Action cost uses verified case data; no solution or guilt cue.'),
 ('S11',1425,1545,['C17'],'stories','Three paper labels/questions land in spoken order.','مين؟ / ليه؟ / إزاي؟',['story_desk'],'Three separate word-triggered landings.'),
 ('S12',1545,1770,['C18','C19'],'mafia','Return to exact opening host/card arrangement; name and CTA; clean hold.','سيد المافيا / ابعت لصحابك',['mafia_gallery','brand_mark','card_mafia'],'Final word before f1710 target; hold f1710..1770.'),
]
scenes=[dict(id=i,start_frame=s,end_frame=e,cue_ids=cs,identity=ink,picture=pic,visible_copy=copy,
             asset_ids=assets,anchor=anchor) for i,s,e,cs,ink,pic,copy,assets,anchor in scene_specs]
events=[
 dict(id='E01',frame=0,cue='C01',trigger='film_start',action='Face/card in frame, online badge already readable, card moving.'),
 dict(id='E02',frame=14,cue='C01',trigger='card_contact',action='Card stops; hand releases after contact, tactile foley.'),
 dict(id='E03',frame=84,cue='C02',trigger='phrase_start',action='Widen camera, keep direct address.'),
 dict(id='E04',frame=165,cue='C03',trigger='phrase_start',action='Online editorial illustration enters.'),
 dict(id='E05',frame=435,cue='C06',trigger='word:الدكتور',action='Doctor whole card becomes dominant.'),
 dict(id='E06',frame=495,cue='C07',trigger='word:والمحقق',action='Detective whole card becomes dominant.'),
 dict(id='E07',frame=555,cue='C08',trigger='word:الصبح',action='Day cut, music thins briefly.'),
 dict(id='E08',frame=810,cue='C11',trigger='phrase_start',action='Citizen card public exit and host closeup.'),
 dict(id='E09',frame=855,cue='C11',trigger='word:بتشكركم',action='Tiny host head incline; dry reaction, music dip.'),
 dict(id='E10',frame=1110,cue='C14',trigger='phrase:قصص وتحقيقات',action='Clean full identity change; folder matches card geometry.'),
 dict(id='E11',frame=1290,cue='C15',trigger='word:تسأل',action='Interview action selected, show cost2 and fresh budget12→10.'),
 dict(id='E12',frame=1425,cue='C17',trigger='phrase:مين عملها',action='First question lands.'),
 dict(id='E13',frame=1470,cue='C17',trigger='word:ليه',action='Second question lands.'),
 dict(id='E14',frame=1500,cue='C17',trigger='word:وإزاي',action='Third question lands.'),
 dict(id='E15',frame=1545,cue='C18',trigger='phrase_start',action='Return to Mafia world; Stories art gone.'),
 dict(id='E16',frame=1710,cue='C19',trigger='phrase_end',action='Final clean hold, jaw rests.'),
]
plan={'version':2,'status':'PLANNED_NOT_AUDIO_ALIGNED','fps':30,'width':1080,'height':1920,
 'duration_seconds':59,'total_frames':1770,'frame_semantics':'start inclusive, end exclusive',
 'voice_start_max_ms':150,'online_spoken_deadline_seconds':10,'end_hold':{'start_frame':1710,'end_frame':1770},
 'script_word_count':len(plain.split()),'cues':cues,'scenes':scenes,'events':events,
 'retiming':'Align real audio, preserve raw, write production/timeline.locked.json; never fake word timings.'}
write_json(ROOT/'timeline.plan.json',plan)
table=['# Storyboard v2 — editorial frame map, not recorded speech timing','',
 '30 fps, 1770 frames, 59 seconds. End frames are exclusive. Resolve audio before animation lock.', '',
 '| Scene | Frames | Seconds | Cues | Picture | Text |','|---|---|---|---|---|---|']
for s in scenes:
    table.append(f"| {s['id']} | {s['start_frame']}–{s['end_frame']} | {s['start_frame']/30:g}–{s['end_frame']/30:g} | {', '.join(s['cue_ids'])} | {s['picture']} | {s['visible_copy'] or 'none'} |")
table+=['','## Voice cue map','','| Cue | Frames | Text | Delivery / pause |','|---|---|---|---|']
for c in cues:
    table.append(f"| {c['id']} | {c['start_frame']}–{c['end_frame']} | {c['text']} | {c['delivery']} {c['pause_guidance']} |")
table+=['','## Continuity and retention', '',
 'Opening assigns a secret role and sets a challenge. Online promise lands before 10 s. Night roles build the rules. Day questions raise suspicion. Wrong-vote joke pays off the Mafia viewpoint. Offline is a short use case. The phrase كفاية تخبّي reverses the viewer into an investigator. Limited moves create a real choice. Three accusation questions summarize the challenge. The final shot returns to the opening card.', '',
 'No claim that retention is guaranteed. These are editorial decisions to be judged in actual playback.', '',
 'Use VISUAL_DIRECTION.md for geometry and opening subframes; timeline.plan.json for machine-readable events.']
(ROOT/'STORYBOARD.md').write_text('\n'.join(table)+'\n',encoding='utf-8')

if not (ROOT/'STATE.json').exists():
    write_json(ROOT/'STATE.json',{'package_version':2,'phase':'prepared_waiting_for_user_start',
      'user_start_received':False,'reference_video_required':False,'production_started':False,
      'voice':{'selected_voice':None,'model':None,'flow_id':None,'sessions':[],'audio_generated':False,'audition_listened':False},
      'character':{'canonical_image':None,'rig':None,'speech_test_passed':False},
      'timing':{'plan':'timeline.plan.json','locked':None,'aligned':False},
      'milestones':{'package_integrity':False,'voice_gate':False,'character_gate':False,'picture_gate':False,'audio_mix_gate':False,'render_gate':False},
      'outputs':{},'known_dependencies':['Voice generation/audition','Canonical seated presenter and rig','Real audio alignment','HyperFrames runtime setup and render'],
      'no_longer_dependencies':['Reference video','YouTube clips','App build or new online game session'],
      'last_note':'Preparation only. Next model reads START_HERE.md and starts after user says ابدأ.'})
(ROOT/'TREATMENT.md').write_text('''# Current treatment — إنت المافيا (v2)

This file supersedes the v1 treatment in archive/v1. Start with START_HERE.md.

Original reel, no reference video, no external gameplay montage. A seated Mafia skull character deals the viewer a card: «إنت المافيا. وهما لسه مايعرفوش.» The online label is visible from frame0 and the online promise is spoken within the first10s. Show night roles, day discussion, vote and a dry wrong-vote reaction. Show offline briefly. Switch decisively to the warm Stories identity through a card/folder match cut, using the verified public case قهوة المعلم. End with the host and the opening card: «ونشوف… هتتلقط من أول جولة؟»

Target59s/1770frames at30fps, 1080×1920. SCRIPT.ar.txt is authoritative speech; timeline.plan.json is the editorial target pending real audio. Details: STORYBOARD.md, VOICE_DIRECTION.md, VISUAL_DIRECTION.md, CHARACTER_BUILD.md, PRODUCTION_RUNBOOK.md and QA_CHECKLIST.md.

Frozen existing media are under references/, indexed and hashed in assets.manifest.json. Nothing generated or rendered yet. Production begins only after the user's start message. No app-code changes or publication.
''',encoding='utf-8')
print(json.dumps({'frozen_assets':len(manifest),'bytes':sum(a['bytes'] for a in manifest),'script_words':len(plain.split()),'cues':len(cues),'scenes':len(scenes),'frames':1770},ensure_ascii=False))
