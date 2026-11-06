from pathlib import Path
import json,html,shutil
R=Path(__file__).resolve().parent;P=R/'project'
D=json.loads((R/'timeline.locked.json').read_text(encoding='utf-8'))
A=json.loads((P/'data.js').read_text(encoding='utf-8').removeprefix('window.REEL_DATA=').rstrip(';'))['assets']
def art(a,cls,style='',alt=''):
    return f'<img class="art {cls}" src="../{A[a]}" style="{style}" alt="{html.escape(alt)}">'
def header(title,kicker='سيد المافيا'):
    return f'<div class="headlines"><p class="eyebrow">{kicker}</p><h1 class="headline">{title}</h1></div>'
def host(card=True):
    z='<div class="host-stage">'
    z+='<img class="host-base" src="../assets/character/base-clean.webp" alt="">'
    if card:z+='<img class="deal-card" src="../assets/art/card_mafia.webp" alt="كارت المافيا">'
    for name in ('upper','jaw','hand'):z+=f'<img class="host-{name}" src="../assets/character/canonical.webp" alt="">'
    return z+'</div>'
def bg(a):return art(a,'backdrop')+'<div class="shade"></div>'
scene_html={
'S01':host()+'<div class="badge">مافيا أونلاين</div><h1 class="hook">إنت المافيا</h1>',
'S02':header('كل واحد من مكانه','مافيا أونلاين')+''.join(art('avatar_female' if i==1 else 'avatar_male','online-portrait',f'left:{70+i*290}px') for i in range(3))+'<svg class="connect" viewBox="0 0 760 170"><path d="M90 0V70H380V165 M380 0V165 M670 0V70H380" fill="none" stroke="#908C83" stroke-width="2"/></svg>'+''.join(art('card_back','connection-card',f'left:{95+i*275}px') for i in range(3))+'<p class="caption online-caption">سيد المافيا</p>',
'S03':header('دورك في السر')+art('card_mafia','role-main'),
'S04':bg('night_ground')+header('بالليل')+''.join(art(a,'role-main') for a in ('card_mafia','card_doctor','card_detective'))+'<h2 class="role-name">المافيا</h2>',
'S05':bg('day_ground')+header('مين بيغيّر كلامه؟','الصبح')+art('avatar_male','day-cast','left:155px')+art('avatar_female','day-cast','left:545px')+art('card_citizen','vote-card')+'<p class="caption">مين بيكدب؟</p>',
'S06':host(False)+art('card_citizen','vote-card')+'<div class="badge">المافيا بتشكركم</div>',
'S07':bg('offline_table')+header('أوفلاين كمان','متجمعين في قعدة؟')+art('card_back','offline-card')+'<p class="caption">العبوا مع بعض</p>',
'S08':host()+'<div class="headlines"><h1 class="headline">كفاية تخبّي</h1></div><p class="caption pivot-caption">تعالى اكشف مين عملها</p>',
'S09':bg('story_desk')+header('قصص وتحقيقات','دلوقتي إنت المحقق')+'<div class="folder"><img src="../assets/art/case_cover.webp" alt=""><h2 class="folder-title">قهوة المعلم</h2></div><p class="case-meta">قضية، شخصيات، وأدلة</p>',
'S10':bg('story_desk')+header('تفتّش وتقارن','قهوة المعلم')+''.join(f'<div class="photo" style="left:{100+i*265}px"><img src="../{A[a]}" alt="{name}"><p>{name}</p></div>' for i,(a,name) in enumerate([('suspect_reda','رضا المكوجي'),('suspect_sameh','سامح صابر'),('suspect_ezza','عزة بائعة الورد')]))+'<div class="action-paper"><small>تحرّك تحقيق · تكلفة ٢</small><p>استجواب اللي كانوا في الصالة</p></div><div class="meter">تحرّكاتك <b>12 / 12</b></div>'+art('case_evidence','evidence')+'<p class="evidence-tag">إنت تختار تحقّق فين</p>',
'S11':bg('story_desk')+header('وجّه الاتهام','وفي الآخر')+''.join(f'<div class="question-paper" style="top:{520+i*300}px">{s}</div>' for i,s in enumerate(['مين عملها؟','ليه؟','إزاي؟'])),
'S12':host()+'<h1 class="brand-title">سيد المافيا</h1><p class="final-cta">ابعت لصحابك</p>',
}
(P/'compositions').mkdir(exist_ok=True)
fonts=''.join(f"@font-face{{font-family:{family};src:url('../assets/fonts/{file}');font-weight:{weight};}}" for family,file,weight in [('Cairo','Cairo-Variable.ttf','200 1000'),('Plex','IBMPlexSansArabic-Medium.ttf','500'),('Plex','IBMPlexSansArabic-SemiBold.ttf','600'),('Ruqaa','ArefRuqaa-Bold.ttf','700'),('Mono','IBMPlexMono-Medium.ttf','500')])
hosts=[]
for s in D['scenes']:
    id=s['id'];start=s['start_frame']/30;dur=(s['end_frame']-s['start_frame'])/30
    ink='stories' if s['identity']=='stories' else 'mafia'
    document=f'''<!doctype html><html lang="ar"><head><meta charset="utf-8"></head><body><template>
<style>{fonts} #root{{position:absolute;inset:0;width:100%;height:100%;overflow:hidden;}}</style>
<div id="root" data-composition-id="{id}" data-width="1080" data-height="1920" data-duration="{dur:.9f}"><div class="world {ink}">{scene_html[id]}</div></div>
<script>window.REEL.bind('{id}',{start:.9f},{dur:.9f});</script>
</template></body></html>'''
    (P/f'compositions/{id}.html').write_text(document,encoding='utf-8')
    hosts.append(f'<div id="slot-{id}" class="clip" data-composition-id="{id}" data-composition-src="compositions/{id}.html" data-start="{start:.9f}" data-duration="{dur:.9f}" data-track-index="1" data-width="1080" data-height="1920"></div>')
vendor=P/'assets/vendor';vendor.mkdir(exist_ok=True);shutil.copy2(P/'node_modules/gsap/dist/gsap.min.js',vendor/'gsap.min.js')
cm={c['id']:c for c in D['cues']}
points=[{'t':0,'v':0},{'t':.5,'v':.035}]
for cid in ('C11','C13'):
    start=cm[cid]['speech_start'];end=cm[cid]['speech_end'];points.extend([{'t':start-.2,'v':.035},{'t':start,'v':.017},{'t':end,'v':.017},{'t':end+.2,'v':.035}])
points.extend([{'t':56.5,'v':.035},{'t':58.7,'v':0}]);points.sort(key=lambda p:p['t'])
automation=html.escape(json.dumps({'version':1,'lanes':[{'target':'volume','points':points}]}),quote=True)
css=(P/'style.css').read_text(encoding='utf-8')
doc=f'''<!doctype html><html lang="ar" data-resolution="portrait"><head><meta charset="UTF-8"><meta name="viewport" content="width=1080,height=1920"><title>سيد المافيا — إنت المافيا</title>
<style>{css}</style><script src="assets/vendor/gsap.min.js"></script><script src="data.js"></script><script src="scene-runtime.js"></script></head><body>
<div id="root" data-composition-id="main" data-start="0" data-duration="59" data-width="1080" data-height="1920" data-fps="30">{''.join(hosts)}
<audio id="voice" src="assets/audio/voice-master.wav" data-start="0" data-duration="{D['voice_duration']:.9f}" data-track-index="2" data-volume="1"></audio>
<audio id="score" src="assets/audio/score.ogg" data-start="0" data-duration="59" data-media-start="75" data-track-index="3" data-automation="{automation}"></audio>
<audio id="card-foley" src="assets/audio/card.ogg" data-start="0.43" data-duration="0.533333" data-volume="0.15" data-track-index="4"></audio>
<audio id="paper-foley" src="assets/audio/card.ogg" data-start="{cm['C14']['speech_start']+.23:.9f}" data-duration="0.533333" data-volume="0.1" data-track-index="4"></audio>
</div><script>document.fonts.ready.then(()=>{{const tl=gsap.timeline({{paused:true}});tl.set(document.body,{{backgroundColor:'#0F0F0F'}},0);window.__timelines.main=tl;}});</script></body></html>'''
(P/'index.html').write_text(doc,encoding='utf-8')
(P/'BRIEF.md').write_text('''---
workflow: general-video
flow: automation
storyboard: no
---
# Approved brief
Execute the user's original Egyptian Arabic Mafia reel. Direction and script are approved in the parent handoff. 1080×1920 at30fps,59s. Animated seated skull-faced host, online emphasis in first10s, core roles/discussion/vote, offline beat, independent Stories identity for قهوة المعلم, final callback. No reference video, no new approvals needed for normal local production; no publishing or app changes. Use parent documents and actual measured voice alignment.
''',encoding='utf-8')
print('Wrote root + 12 mounted compositions with local assets')
