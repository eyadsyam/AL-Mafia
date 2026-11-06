from pathlib import Path
import json,html,shutil
R=Path(__file__).resolve().parent; P=R/'project'
D=json.loads((R/'timeline.locked.json').read_text(encoding='utf-8'))
H=[]; A=[]; seen=set()
def clip(i,s,e,body,cls='',track=2):
    H.append(f'<section id="{i}" class="clip {cls}" data-start="{s}" data-duration="{e-s}" data-track-index="{track}">{body}</section>')
def pic(name,cls='',id='',style=''):
    return f'<img src="assets/art/{name}" class="{cls}" id="{id}" style="{style}" alt="">'
def vid(i,file,s,e,offset=0,style='',wrapstyle=''):
    H.append(f'<div id="{i}-wrap" class="film-wrap" style="{wrapstyle}"><video id="{i}" class="clip film" src="assets/video/{file}.mp4" muted playsinline data-start="{s}" data-duration="{e-s}" data-media-start="{offset}" data-track-index="1" style="{style}"></video></div>')
def text(i,s,e,t,cls='headline',style=''):
    clip(i,s,e,f'<div id="{i}-ink" class="{cls}" style="{style}">{t}</div>',track=5)
def move(selector,frm,to,t):
    to['immediateRender']=selector not in seen
    seen.add(selector)
    A.append(f'tl.fromTo({json.dumps(selector)},{json.dumps(frm)},{json.dumps(to)},{t});')
def setv(selector,v,t):A.append(f'tl.set({json.dumps(selector)},{json.dumps(v)},{t});')
def enter(sel,t,x=0,y=90,d=.43):move(sel,{'opacity':0,'x':x,'y':y,'rotation':-3,'filter':'blur(8px)'},{'opacity':1,'x':0,'y':0,'rotation':0,'filter':'blur(0px)','duration':d,'ease':'power3.out'},t)
def phone(i,img):return f'<div id="{i}" class="phone"><div class="screen">{pic(img)}</div><div class="speaker"></div></div>'
vid('hook','hook',0,5)
vid('online-k','hook',5,9,1,wrapstyle='left:0;width:360px;height:880px;top:440px;')
vid('online-s','salma',5,9,0,wrapstyle='left:360px;width:360px;height:880px;top:440px;')
vid('online-o','omar',5,9,0,wrapstyle='left:720px;width:360px;height:880px;top:440px;')
vid('night','mafia',10.7,13.53,.6)
vid('accuse','salma',18.47,22.97,1.5)
vid('wrong','omar',22.97,27.67,0)
vid('reveal','reveal',27.67,31.67,1)
vid('end-k','hook',50.43,55.43,0)
vid('end-rest','hook',55.43,57,3.43)
# One restrained top/bottom exposure mask, no tint on card art or app screenshots.
H.append('<div class="readability"></div>')
text('online-badge',0,10.7,'أونلاين','badge')
text('hook-question',0,1.4,'تعرف لعبة المافيا؟','question')
text('innocent',1.4,5,'أنا بريء.','headline')
enter('#innocent-ink',1.4,x=65,y=0,d=.2)
text('online-title',5,9,'كل واحد من مكانه.','headline')
clip('online-product',5,9,phone('rooms-phone','app-rooms.png'))
move('#rooms-phone',{'y':700,'rotationY':-18,'scale':.55,'opacity':0},{'y':0,'rotationY':0,'scale':1,'opacity':1,'duration':.52,'ease':'power4.out'},5.15)
move('#rooms-phone',{'y':0,'scale':1},{'y':-35,'scale':1.06,'duration':2.5,'ease':'none'},5.7)
move('#rooms-phone',{'y':-35,'scale':1.06},{'y':-70,'rotationY':85,'scale':.95,'duration':.27,'ease':'power2.in'},8.73)
# Role secrecy uses genuine delivery screen and a separate advertising card flip.
clip('private',9,10.7,phone('private-phone','app-reveal.png')+pic('card_citizen.webp','private-card','private-card'))
move('#private-phone',{'rotationY':-85,'y':-70,'scale':.95},{'rotationY':0,'y':0,'scale':1,'duration':.26},9)
move('#private-card',{'rotationY':90,'opacity':0,'scale':.72},{'rotationY':0,'opacity':1,'scale':1,'duration':.32,'ease':'power2.out'},9.43)
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
text('doctor-title',13.53,15.62,'الدكتور يحاول ينقذ.','headline')
text('detective-title',15.62,18.47,'المحقق يكشف دور.','headline')
text('day-title',18.47,20.53,'الصبح… كله بريء.','headline')
text('accuse-title',20.53,22.97,'تسألوا. تناقشوا. تصوّتوا.','headline compact')
text('wrong-title',22.97,27.67,'طلّعتوا الشخص الغلط.','headline compact')
text('wrong-verdict',24.0,27.67,'عمر طلع بريء','verdict')
enter('#wrong-verdict-ink',24.0,y=-60,d=.17)
text('payoff-title',27.67,30.0,'فاكر الوش ده؟','headline')
text('payoff',30.0,31.67,'أهو المافيا.','headline')
clip('payoff-card',29.65,31.67,pic('card_mafia.webp','payoff-card','mafia-card'))
move('#mafia-card',{'x':700,'y':160,'rotation':20,'rotationY':85,'opacity':0},{'x':0,'y':0,'rotation':-8,'rotationY':0,'opacity':1,'duration':.4,'ease':'power3.out'},29.65)
# Offline is a prop sequence. Faces are not faked with a still-image jaw rig.
clip('offline',31.67,34.4,pic('offline_table.webp','ground')+'<div class="table-vignette"></div>'+phone('pass-phone','app-home.png')+pic('card_back.webp','pass-card','pass-card'))
move('#pass-phone',{'x':-290,'y':70,'rotation':-18,'rotationY':-18,'scale':.62},{'x':270,'y':-50,'rotation':14,'rotationY':16,'scale':.62,'duration':1.25,'ease':'power2.inOut'},31.67)
move('#pass-phone',{'x':270,'y':-50,'rotation':14,'rotationY':16,'scale':.62},{'x':0,'y':0,'rotation':0,'rotationY':0,'scale':.72,'duration':.48,'ease':'power3.out'},32.97)
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
move('#case-file',{'y':1350,'rotation':-8,'scale':.9},{'y':0,'rotation':0,'scale':1,'duration':.72,'ease':'power3.out'},39.1)
enter('#suspect-photo',40.0,x=-700,y=120,d=.42)
move('#suspect-photo',{'rotation':0},{'rotation':-5,'duration':.18},40.45)
enter('#location-photo',41.0,x=700,y=110,d=.45)
move('#location-photo',{'rotation':0},{'rotation':6,'duration':.2},41.45)
enter('#evidence-photo',41.85,x=650,y=20,d=.48)
enter('#moves',42.5,x=0,y=70,d=.3)
move('#case-file',{'scale':1,'y':0},{'scale':1.07,'y':-30,'duration':.4,'ease':'power2.out'},43.0)
move('#suspect-photo',{'x':0,'y':0},{'x':50,'y':-20,'rotation':-2,'duration':.35},44.0)
move('#evidence-photo',{'x':0,'y':0},{'x':-40,'y':-80,'rotation':-6,'duration':.45},44.25)
enter('#question-slip',46.45,x=-850,y=0,d=.3)
enter('#why-slip',47.6,x=850,y=0,d=.26)
enter('#how-slip',48.65,x=-850,y=0,d=.28)
move('#case-file',{'y':-30,'scale':1.07},{'y':-1450,'scale':.7,'rotation':8,'duration':.4,'ease':'power3.in'},50.03)
text('case-title',38.2,40.05,'قهوة المعلم','headline story')
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
caption_id=0
for c in D['cues']:
    ws=[w for w in D['words'] if w['start']>=c['start']-.005 and w['end']<=c['end']+.005]
    chunks=[];batch=[]
    for w in ws:
        if batch and len(' '.join(x['text'] for x in batch+[w]))>27:chunks.append(batch);batch=[]
        batch.append(w)
    if batch:chunks.append(batch)
    for k,ch in enumerate(chunks):
        next_cue=D['cues'][c['id']]['start']-.025 if c['id']<len(D['cues']) else 56.5
        caption_id+=1;s=ch[0]['start'];e=(chunks[k+1][0]['start']-.025 if k+1<len(chunks) else min(c['end']+.12,next_cue))
        text(f'cap{caption_id}',s,e,html.escape(' '.join(w['text'] for w in ch)),'caption')
        enter(f'#cap{caption_id}-ink',s,y=10,d=.1)
# All audio remains at native speech speed. Music ducks hard before the reveal.
H.append('<audio id="adam-voice" src="assets/audio/voice-master.wav" data-start="0" data-duration="55.68" data-track-index="6" data-volume="1"></audio>')
automation={'version':1,'lanes':[{'target':'volume','points':[{'t':0,'v':.015},{'t':.3,'v':.027},{'t':26.55,'v':.027},{'t':26.7,'v':0},{'t':27.6,'v':0},{'t':28.0,'v':.025},{'t':34.4,'v':.025},{'t':35.2,'v':.014},{'t':50.43,'v':.025},{'t':55.7,'v':.025},{'t':57,'v':0}]}]}
H.append(f'<audio id="score" src="assets/audio/score.ogg" data-start="0" data-duration="57" data-media-start="75" data-track-index="7" data-automation="{html.escape(json.dumps(automation),quote=True)}"></audio>')
for i,t in enumerate([9.43,13.53,15.62,24.0,29.65,32.9,35.22,36.0,40.0,41.0,41.85,46.45,47.6,48.65]):
    H.append(f'<audio id="foley-{i}" src="assets/audio/card.ogg" data-start="{t}" data-duration="0.53" data-track-index="8" data-volume="{.07 if t>35 else .1}"></audio>')
css=(R/'style.css').read_text(encoding='utf-8')
page='<!doctype html><html lang="ar"><head><meta charset="utf-8"><meta name="viewport" content="width=1080,height=1920"><title>صاحبك اللي بريء — سيد المافيا</title><script src="assets/vendor/gsap.min.js"></script><style>'+css+'</style></head><body><div id="root" data-composition-id="main" data-width="1080" data-height="1920" data-duration="57">'+''.join(H)+'</div><script>document.fonts.ready.then(()=>{const tl=gsap.timeline({paused:true});'+''.join(A)+'window.__timelines.main=tl;});</script></body></html>'
(P/'index.html').write_text(page,encoding='utf-8')
(R/'research/animation-map.json').write_text(json.dumps({'tweens':len(A),'caption_chunks':caption_id,'generated_acting_sources':5,'reused_shots':['online montage from hook/salma/omar','loop from hook'],'offline':'physical phone/card sequence, no animated group clip','stories':'independent paper/camera choreography; cafe still art, not generated video'},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'tweens':len(A),'captions':caption_id,'duration':57,'project':str(P)}))
