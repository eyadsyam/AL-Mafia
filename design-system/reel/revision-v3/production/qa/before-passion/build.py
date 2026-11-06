from pathlib import Path
import json,html,shutil
R=Path(__file__).resolve().parent; P=R/'project'
D=json.loads((R/'timeline.locked.json').read_text(encoding='utf-8'))
H=[]; A=[]; seen=set(); native=False; DUR=D['duration']; anchors=D['old_time_mapping']
def T(t):
    if native:return t
    for (a,x),(b,y) in zip(anchors,anchors[1:]):
        if a<=t<=b:return x+(t-a)/(b-a)*(y-x) if b>a else y
    return t/57*DUR
def clip(i,s,e,body,cls='',track=2):
    H.append(f'<section id="{i}" class="clip {cls}" data-start="{T(s)}" data-duration="{T(e)-T(s)}" data-track-index="{track}">{body}</section>')
def pic(name,cls='',id='',style=''):
    return f'<img src="assets/art/{name}" class="{cls}" id="{id}" style="{style}" alt="">'
def vid(i,file,s,e,offset=0,style='',wrapstyle=''):
    H.append(f'<div id="{i}-wrap" class="film-wrap" style="{wrapstyle}"><video id="{i}" class="clip film" src="assets/video/{file}.mp4" muted playsinline data-start="{T(s)}" data-duration="{T(e)-T(s)}" data-media-start="{offset}" data-track-index="1" style="{style}"></video></div>')
def text(i,s,e,t,cls='headline',style=''):
    clip(i,s,e,f'<div id="{i}-ink" class="{cls}" style="{style}">{t}</div>',track=5)
def move(selector,frm,to,t):
    if 'duration' in to:to['duration']=max(.03,T(t+to['duration'])-T(t))
    to['immediateRender']=selector not in seen
    seen.add(selector)
    A.append(f'tl.fromTo({json.dumps(selector)},{json.dumps(frm)},{json.dumps(to)},{T(t)});')
def setv(selector,v,t):A.append(f'tl.set({json.dumps(selector)},{json.dumps(v)},{t});')
def enter(sel,t,x=0,y=90,d=.43):move(sel,{'opacity':0,'x':x,'y':y,'rotation':-3,'filter':'blur(8px)'},{'opacity':1,'x':0,'y':0,'rotation':0,'filter':'blur(0px)','duration':d,'ease':'power3.out'},t)
def phone(i,img):return f'<div id="{i}" class="phone"><div class="screen">{pic(img)}</div><div class="speaker"></div></div>'
def gamephone(i,file,s,e,offset=0):
    H.append(f'<div id="{i}" class="phone gamephone"><div class="screen"><video id="{i}-media" class="clip" src="assets/video/{file}.mp4" muted playsinline data-start="{T(s)}" data-duration="{T(e)-T(s)}" data-media-start="{offset}" data-track-index="3"></video></div><div class="speaker"></div></div>')
    move('#'+i,{'opacity':0,'y':130,'rotationY':-12,'scale':.92},{'opacity':1,'y':0,'rotationY':0,'scale':1,'duration':.35,'ease':'power3.out'},s)
    move('#'+i,{'opacity':1},{'opacity':0,'duration':.18},e-.18)
vid('hook','hook-long',0,5)
vid('night','mafia',10.7,13.53,.6)
vid('accuse','salma',18.47,22.97,1.1)
vid('wrong','omar',22.97,27.67,0)
vid('reveal','reveal',27.67,31.67,1)
vid('offline-friends','offline',31.67,34.4,1.6)
vid('end-k','hook-loop',50.43,57,0)
# One restrained top/bottom exposure mask, no tint on card art or app screenshots.
H.append('<div class="readability"></div>')
text('online-badge',0,10.7,'أونلاين','badge')
text('hook-question',0,1.4,'تعرف لعبة المافيا؟','question')
text('innocent',1.4,5,'أنا بريء.','headline')
enter('#innocent-ink',1.4,x=65,y=0,d=.2)
clip('online-bg',5,10.7,pic('stage_chair.webp','ground'))
text('online-title',5,9,'أونلاين مع صحابك.','headline compact')
gamephone('rooms-phone','online-discussion',5,9,.2)
# Role secrecy uses genuine delivery screen and a separate advertising card flip.
clip('private',9,10.7,phone('private-phone','app-reveal.png'))
move('#private-phone',{'rotationY':-85,'y':-70,'scale':.95},{'rotationY':0,'y':0,'scale':1,'duration':.26},9)
# No detached citizen card pasted over the actual card-delivery screenshot.
text('private-title',9,10.7,'دورك… ليك لوحدك.','headline')
text('night-title',10.7,13.53,'الليل نزل.','headline')
text('night-label',11.4,13.53,'المافيا تختار','small-note')
# Doctor -> detective: the same citizen card remains the action's anchor.
clip('roles',13.53,18.47,pic('night_ground.webp','ground')+pic('card_doctor.webp','role-card','doctor-card')+pic('card_detective.webp','role-card','detective-card')+pic('card_citizen.webp','target-card','target-card')+'<div id="save-ring" class="save-ring"></div><div id="scan" class="scan"></div>')
enter('#doctor-card',13.53,x=-680,y=20,d=.32)
enter('#target-card',13.68,x=550,y=70,d=.35)
move('#save-ring',{'scale':.45,'opacity':0},{'scale':1,'opacity':.75,'duration':.48,'ease':'power2.out'},14.05)
move('#save-ring',{'scale':1,'opacity':.75},{'scale':1.15,'opacity':0,'duration':.45},15.05)
move('#doctor-card',{'x':0,'rotation':0},{'x':-880,'rotation':-15,'duration':.28,'ease':'power2.in'},15.48)
enter('#detective-card',15.62,x=-720,y=0,d=.28)
move('#target-card',{'rotationY':0},{'rotationY':85,'duration':.16},16.12)
move('#target-card',{'rotationY':85},{'rotationY':0,'duration':.2},16.28)
move('#scan',{'y':0,'opacity':0},{'y':0,'opacity':.7,'duration':.08},16.0)
move('#scan',{'y':0},{'y':520,'duration':.67,'ease':'power1.inOut'},16.08)
move('#scan',{'opacity':.7},{'opacity':0,'duration':.1},16.75)
text('doctor-title',13.53,15.62,'الدكتور','headline')
text('detective-title',15.62,18.47,'المحقق','headline')
gamephone('mafia-ui','online-mafia',11.35,13.53,1.35)
gamephone('doctor-ui','online-doctor',13.7,15.62,1.3)
gamephone('detective-ui','online-detective',15.7,18.47,1.3)
text('day-title',18.47,20.53,'الصبح… كله بريء.','headline')
text('accuse-title',20.53,22.97,'تسألوا. تناقشوا. تصوّتوا.','headline compact')
gamephone('vote-ui','online-vote',22.0,24.9,1.5)
clip('vote-background',22.0,22.97,pic('day_ground.webp','ground'))
move('#accuse-wrap',{'opacity':1},{'opacity':0,'duration':.2},21.9)
move('#vote-ui',{'x':0,'y':0,'scale':1},{'x':360,'y':50,'scale':.65,'duration':.32,'ease':'power3.out'},22.97)
text('wrong-title',22.97,27.67,'طلّعتوا الشخص الغلط.','headline compact')
text('wrong-verdict',24.0,27.67,'عمر طلع بريء','verdict')
enter('#wrong-verdict-ink',24.0,y=-60,d=.17)
text('payoff-title',27.67,30.0,'فاكر الوش ده؟','headline')
text('payoff',30.0,31.67,'أهو المافيا.','headline')
clip('payoff-card',29.65,31.67,pic('card_mafia.webp','payoff-card','mafia-card'))
move('#mafia-card',{'x':700,'y':160,'rotation':20,'rotationY':85,'opacity':0},{'x':0,'y':0,'rotation':-8,'rotationY':0,'opacity':1,'duration':.4,'ease':'power3.out'},29.65)
# Offline is a prop sequence. Faces are not faked with a still-image jaw rig.
clip('offline',31.67,34.4,pic('card_back.webp','pass-card','pass-card'))
move('#pass-card',{'x':-640,'rotation':-35,'opacity':0},{'x':0,'rotation':-8,'opacity':1,'duration':.5,'ease':'power3.out'},32.9)
text('offline-title',31.67,34.4,'ومتجمعين؟ أوفلاين.','headline')
# The card stays in the same coordinates and becomes the manila folder.
clip('bridge',34.4,38.2,'<div id="warm-room" class="warm-room"></div>'+pic('card_back.webp','bridge-card','bridge-card')+'<div id="folder" class="folder"><div id="folder-cover" class="folder-cover"><p>قصص وتحقيقات</p><span>ملف القضية</span></div><div class="folder-page">'+pic('case_cover.webp','cover-art')+'<p>قهوة المعلم</p></div></div>')
move('#bridge-card',{'rotation':-8,'scale':1},{'rotation':0,'scale':1.12,'duration':.37,'ease':'power3.out'},34.4)
move('#bridge-card',{'rotationY':0},{'rotationY':90,'duration':.23},35.0)
move('#warm-room',{'opacity':0},{'opacity':1,'duration':.7},35.0)
move('#folder',{'rotationY':-90,'scale':.66,'opacity':0},{'rotationY':0,'scale':1,'opacity':1,'duration':.38,'ease':'power3.out'},35.22)
move('#folder-cover',{'rotationY':0},{'rotationY':-150,'duration':.72,'ease':'power2.inOut'},36.0)
move('#folder',{'scale':1,'y':0},{'scale':1.3,'y':-150,'duration':.5,'ease':'power2.in'},37.7)
text('bridge-title',34.4,36.17,'بالأدلة بقى؟','headline')
text('story-title',36.17,38.2,'قصص وتحقيقات','headline story-copy')
# One persistent investigation desk: the evidence builds, it does not reset every beat.
clip('investigation',38.2,50.43,'<div class="warm-room"></div>'+pic('story_desk.webp','ground desk-texture')+'<div id="case-world">'+pic('cafe.webp','cafe-art')+'</div><div id="case-file" class="case-file"><div class="case-header"><span>ملف تحقيق</span><h2>قهوة المعلم</h2></div><div id="suspect-photo" class="paper-photo">'+pic('suspect_reda.webp')+'<p>رضا المكوجي</p></div><div id="location-photo" class="paper-photo">'+pic('cafe.webp')+'<p>المكان</p></div><div id="evidence-photo" class="paper-photo">'+pic('evidence.webp')+'<p>الدليل</p></div><div id="question-slip" class="question-slip">مين عملها؟</div><div id="why-slip" class="question-slip">ليه؟</div><div id="how-slip" class="question-slip">إزاي؟</div><div id="moves" class="moves">تحرّكاتك محدودة</div></div>')
move('#case-world',{'scale':1.3,'opacity':1},{'scale':1,'opacity':1,'duration':1.0,'ease':'power2.out'},38.2)
move('#case-world',{'opacity':1},{'opacity':.25,'duration':.5},39.2)
move('#case-file',{'y':1350,'rotation':-8,'scale':.9},{'y':0,'rotation':0,'scale':1,'duration':.62,'ease':'power3.out'},41.0)
enter('#suspect-photo',41.0,x=-700,y=120,d=.42)
move('#suspect-photo',{'rotation':0},{'rotation':-5,'duration':.18},41.45)
enter('#location-photo',41.4,x=700,y=110,d=.45)
move('#location-photo',{'rotation':0},{'rotation':6,'duration':.2},41.85)
enter('#evidence-photo',43.0,x=650,y=20,d=.48)
enter('#moves',42.5,x=0,y=70,d=.3)
move('#case-file',{'scale':1,'y':0},{'scale':1.07,'y':-30,'duration':.4,'ease':'power2.out'},43.0)
move('#suspect-photo',{'x':0,'y':0},{'x':50,'y':-20,'rotation':-2,'duration':.35},44.0)
move('#evidence-photo',{'x':0,'y':0},{'x':-40,'y':-80,'rotation':-6,'duration':.45},44.25)
enter('#question-slip',46.45,x=-850,y=0,d=.3)
enter('#why-slip',47.6,x=850,y=0,d=.26)
enter('#how-slip',48.65,x=-850,y=0,d=.28)
move('#case-file',{'y':-30,'scale':1.07},{'y':-1450,'scale':.7,'rotation':8,'duration':.4,'ease':'power3.in'},50.03)
move('#case-file',{'opacity':1},{'opacity':0,'duration':.3},46.7)
text('case-title',38.2,40.05,'قهوة المعلم','headline story')
gamephone('story-ui','story-search',38.2,41.0,.25)
gamephone('accuse-ui','story-search',47.0,50.03,3.6)
text('case-verb',40.05,42.38,'اسأل. فتّش. اجمع الدليل.','headline story-copy compact')
text('case-moves',42.38,45.67,'هتبدأ بمين؟','headline story-copy')
text('case-questions',45.67,50.03,'والاتهام… عليك.','headline story-copy')
text('brand',50.43,57,'سيد المافيا','headline')
clip('end-product',50.43,57,phone('end-phone','app-home.png'))
move('#end-phone',{'x':640,'y':450,'rotation':14,'scale':.52,'opacity':0},{'x':280,'y':420,'rotation':-6,'scale':.52,'opacity':1,'duration':.45,'ease':'power3.out'},50.7)
text('cta',51.85,54.9,'ابعتها لصحابك.','cta')
enter('#cta-ink',51.85,y=70,d=.3)
text('loop',54.9,57,'أنا بريء.','headline loop')
enter('#loop-ink',54.9,x=40,y=0,d=.19)
# Phrase chunks preserve measured word timing and leave the entire bottom UI margin clear.
caption_id=0; native=True
for c in D['cues']:
    if c['id']==1:continue
    ws=[w for w in D['words'] if w['start']>=c['start']-.005 and w['end']<=c['end']+.005]
    # The final quoted phrase is already the large loop headline, like the
    # opening question; avoid a stranded one-word subtitle underneath it.
    if c['id']==20:ws=ws[:-2]
    chunks=[];batch=[]
    for w in ws:
        if batch and len(' '.join(x['text'] for x in batch+[w]))>27:chunks.append(batch);batch=[]
        batch.append(w)
    if batch:chunks.append(batch)
    for k,ch in enumerate(chunks):
        next_cue=D['cues'][c['id']]['start']-.025 if c['id']<len(D['cues']) else DUR-.35
        line_end=ws[-1]['end']+.08 if c['id']==20 else c['end']+.12
        caption_id+=1;s=ch[0]['start'];e=(chunks[k+1][0]['start']-.025 if k+1<len(chunks) else min(line_end,next_cue))
        text(f'cap{caption_id}',s,e,html.escape(' '.join(w['text'] for w in ch)),'caption')
        enter(f'#cap{caption_id}-ink',s,y=10,d=.1)
# All audio remains at native speech speed. Music ducks hard before the reveal.
native=False
H.append(f'<audio id="fekry-voice" src="assets/audio/voice-master.wav" data-start="0" data-duration="{D["voice_duration"]}" data-track-index="6" data-volume="1"></audio>')
automation={'version':1,'lanes':[{'target':'volume','points':[{'t':0,'v':.015},{'t':.3,'v':.027},{'t':26.55,'v':.027},{'t':26.7,'v':0},{'t':27.6,'v':0},{'t':28.0,'v':.025},{'t':34.4,'v':.025},{'t':35.2,'v':.014},{'t':50.43,'v':.025},{'t':55.7,'v':.025},{'t':57,'v':0}]}]}
for pt in automation['lanes'][0]['points']:pt['t']=T(pt['t']);pt['v']*=1.5
H.append(f'<audio id="score" src="assets/audio/score.ogg" data-start="0" data-duration="{DUR}" data-media-start="75" data-track-index="7" data-automation="{html.escape(json.dumps(automation),quote=True)}"></audio>')
sound_events=[('lobby_ready_tick',.8,.10),('join_chime',5.35,.42),('card_flip',9.43,.53),('night_falls',10.7,2.0),('morning',18.47,1.0),('elimination_reveal',24.0,.9),('brand_motif',30.0,.95),('chapter_envelope_open',35.22,.6),('casebook_paper_slide',36.0,.34),('casebook_paper_slide',41.0,.34),('casebook_paper_slide',41.4,.34),('casebook_wax_press',43.0,.42),('casebook_string_pluck',42.5,.6),('casebook_paper_slide',46.45,.34),('casebook_paper_slide',47.0,.34),('share_paper_eject',51.85,.45)]
for i,(name,t,dur) in enumerate(sound_events):
    H.append(f'<audio id="sfx-{i}" src="assets/audio/fx-{name}.wav" data-start="{T(t)}" data-duration="{dur}" data-track-index="8" data-volume="1"></audio>')
# Selection clicks are timed to the recorded Flutter interactions, not a visual guess.
for i,(slot,offset) in enumerate([(11.35,1.35),(13.7,1.3),(15.7,1.3),(22.0,1.5)]):
    click=T(slot)+65/30-offset
    H.append(f'<audio id="ui-click-{i}" src="assets/audio/fx-vote_tick.wav" data-start="{click}" data-duration="0.07" data-track-index="8" data-volume="1"></audio>')
H.append(f'<audio id="vote-commit" src="assets/audio/fx-lobby_ready_tick.wav" data-start="{T(22.0)+105/30-1.5}" data-duration="0.1" data-track-index="8" data-volume="1"></audio>')
css=(R/'style.css').read_text(encoding='utf-8')
page='<!doctype html><html lang="ar"><head><meta charset="utf-8"><meta name="viewport" content="width=1080,height=1920"><title>صاحبك اللي بريء — V3</title><script src="assets/vendor/gsap.min.js"></script><style>'+css+'</style></head><body><div id="root" data-composition-id="main" data-width="1080" data-height="1920" data-duration="'+str(DUR)+'">'+''.join(H)+'</div><script>document.fonts.ready.then(()=>{const tl=gsap.timeline({paused:true});'+''.join(A)+'window.__timelines.main=tl;});</script></body></html>'
(P/'index.html').write_text(page,encoding='utf-8')
(R/'research/animation-map.json').write_text(json.dumps({'tweens':len(A),'caption_chunks':caption_id,'generated_acting_sources':6,'gameplay_sources':6,'reused_shots':['loop from hook'],'offline':'new generated group acting clip','stories':'real Flutter interactive search/accusation video + independent paper choreography','voice':'natural Fekry Egyptian take2','sfx_events':len(sound_events)+4},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'tweens':len(A),'captions':caption_id,'duration':DUR,'project':str(P)}))
