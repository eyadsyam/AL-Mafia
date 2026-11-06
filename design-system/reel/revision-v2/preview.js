// Concept review only. __seek(t) derives every pose from t; browser playback drives it.
// No character face rig: these are development stills, explicitly labelled in the page.
const $=id=>document.getElementById(id);
const directions={
A:{image:'assets/concept-a-human.png',label:'01 / الموصى به',title:'صاحبك اللي «بريء»',hook:'«تعرف لعبة المافيا؟»<br>«شايف اللي بيقول أنا بريء؟»',idea:'صاحبك بيخبي شاشة موبايله، بس ابتسامته مش مطمّنة. نتابع جولته ونشوف في الآخر كان بيضحك على مين.',firstFive:'الوش → الشك → موبايله → أونلاين. مفيش انتظار لتعريف اللعبة.',retention:'نعرف هو بريء فعلًا ولا بيشتغلنا. الإجابة عند كشف الكارت بعد التصويت.',signature:'الإصبع يسحب الكارت من الموبايل، الكاميرا تلحقه، وندخل من بابه لليل.',head:'أنا بريء.',beat:'الوش اللي بيحاول يبان بريء',action:'لقطة قريبة، عين جانبية، ابتسامة واثقة زيادة. آدم يسأل: تعرف لعبة المافيا؟'},
B:{image:'assets/concept-b-host.png',label:'02 / شخصية اللعبة',title:'أنا المافيا. تعالى أوريك.',hook:'«أهلاً، أنا المافيا.»<br>«وصاحبك ده شغال معايا.»',idea:'المافيا يطلع من شاشة الموبايل، يمد إيده، ويشدّنا لجوه الجولة. مرشد ساخر عنده مصلحة إننا نثق في الشخص الغلط.',firstFive:'تحية خاطفة مع إيد طالعة من الشاشة، كارت يتسحب، وأوضة أونلاين تظهر في الموبايل.',retention:'هو بيشرح اللعبة وبيورّينا في نفس الوقت إزاي ممكن يخدعنا. البشر يتخانقوا وهو يستمتع.',signature:'المافيا يمسك حافة الكارت ويحوّلها لباب؛ الكاميرا تتبعه من غير تبديل شرائح.',head:'أنا المافيا.',beat:'المافيا يكسر حدود الموبايل',action:'مدّ إيد، تقديم الكارت، انحناءة ساخرة صغيرة. الأداء المستهدف تمثيل جسم كامل، لسه مش منفّذ في الاختبار.'},
C:{image:'assets/cafe.webp',label:'03 / رحلة في عالمين',title:'الكارت يفتح عالم',hook:'«تعرف لعبة المافيا؟»<br>«هنطلع منها وندخل قضية.»',idea:'نبدأ بكارت على طاولة. الكاميرا تدخل الكارت، تخرج من الموبايل، وبعدين نفس الكارت يفتح ملف التحقيق. خيط واحد رابط الرحلة.',firstFive:'الكارت يقلب، الشاشة تظهر، وإصبع يختار اللعب أونلاين. حركة واحدة توصلنا للمنتج.',retention:'نشوف الكارت هيودّينا فين: من الجولة لقضية فيها شخصيات وأماكن وأدلة.',signature:'حافة كارت اللعب تصبح حافة ملف مانيلا، والكاميرا تكمل فوق مكتب المحقق.',head:'من كارت… لقضية.',beat:'الكارت هو بوابة الرحلة',action:'افتتاح مقترح: كارت اللعبة فوق الطاولة؛ نغوص في رسمه. خلفية القضية هنا اختبار للجزء الثاني من الرحلة.'}
};
const script=['تعرف لعبة المافيا؟','شايف اللي بيقول «أنا بريء»؟','ده ممكن يطلّعك إنت.','في سيد المافيا، تلعبوا أونلاين، كل واحد من مكانه.','كل واحد يعرف دوره لوحده.','الليل ينزل، والمافيا تختار ضحيتها.','الدكتور يحاول ينقذ حد.','والمحقق يكشف دور لاعب.','الصبح، كله عامل بريء.','تسألوا، تناقشوا، وتصوّتوا.','بس لو طلّعتوا الشخص الغلط، المافيا كسبانة منكم.','فاكر الوش اللي في الأول؟ أهو ده المافيا.','ومتجمعين؟ العبوا أوفلاين.','عايز بقى تمسك حد بالأدلة؟','افتح قصص وتحقيقات.','قضية زي قهوة المعلم: شخصيات تسألها، وأماكن تفتّشها.','وتحرّكاتك محدودة، فاختار هتبدأ بمين.','وفي الآخر تقول: مين عملها؟ وليه؟ وإزاي؟','سيد المافيا. ابعتها لصحابك.','وشوف مين فيهم هيقول «أنا بريء».'];
$('scriptLines').innerHTML=script.map((s,i)=>`<div class="script-line"><span>${String(i+1).padStart(2,'0')}</span><div>${s}</div></div>`).join('');
const clamp=x=>Math.max(0,Math.min(1,x)),out=x=>1-Math.pow(1-clamp(x),3),lerp=(a,b,k)=>a+(b-a)*k;
let concept='A',time=0,playing=false,origin=0,base=0;
function draw(t){time=Math.max(0,Math.min(18,t));$('stage').style.transform=`scale(${$('stage').parentElement.clientWidth/1080})`;const d=directions[concept],enter=out((time-1.8)/1.1),close=out((time-5)/1.3),paper=out((time-12)/1.2),depart=out((time-16)/1.2),p=enter*(1-depart),r=concept==='C'&&time<1.8?.85:out((time-7.2)/.7)*(1-out((time-11.7)/.6));
$('world').style.transform=`scale(${1.02+.11*out(time/1.8)-.04*enter}) translate(${12*enter}px,${-25*out(time/1.8)}px)`;
$('world').style.opacity=1-.75*enter;
$('phone').style.transform=`translate(${lerp(-65,0,enter)}px,${lerp(520,-80,enter)+120*depart}px) scale(${lerp(.45,1,enter)+.65*close}) rotate(${lerp(-12,0,enter)}deg)`;
$('phone').style.opacity=p;
$('appHome').style.opacity=1;
$('appRooms').style.opacity=out((time-3)/.4)*(1-out((time-5.5)/.4));
$('appReveal').style.opacity=out((time-5.5)/.4);
$('touch').style.opacity=clamp(1-Math.abs(time-3.05)/.22);
$('touch').style.transform=`scale(${.8+.3*clamp((time-2.8)/.4)})`;
$('role').style.opacity=r;
$('role').style.transform=`translateY(${120*(1-out((time-7.2)/.7))}px) scale(${.9+.8*out((time-8)/1.2)}) rotateY(${75*(1-out((time-7.2)/.7))}deg)`;
$('dossier').style.opacity=paper*(1-depart);
$('dossier').style.transform=`translateY(${390*(1-paper)}px) scale(${.35+.65*paper}) rotate(${-6*(1-paper)}deg)`;
$('dossier').querySelector('.evidence').style.transform=`translate(${180*(1-out((time-14)/.6))}px,${240*(1-out((time-14)/.6))}px) rotate(9deg)`;
$('online').style.opacity=time<6?1:0;
$('headline').style.fontSize=time<2&&concept!=='C'?'92px':'65px';
$('headline').textContent=time<2?d.head:time<6?'تلعبوا أونلاين.':time<10?'دورك ليك لوحدك.':time<12?'أهو ده المافيا.':time<16?'هتبدأ بمين؟':d.head;
$('sceneMark').textContent=time<2?'01 / الهوك':time<6?'02 / المنتج':time<10?'03 / السر':time<12?'04 / الكشف':time<16?'05 / عالم القصص':'06 / رجوع للهوك';
$('frameCount').textContent=`00:${String(Math.floor(time)).padStart(2,'0')} / 18`;
$('seek').value=time;$('time').textContent=time.toFixed(1)+'s';
const beats=time<2?['0–2 ثانية',d.beat,d.action]:time<6?['2–6 ثانية','الكاميرا تتبع الموبايل','الموبايل يكبر، واجهة الأوض الأونلاين الفعلية تظهر. دائرة الضغط مؤشر توضيحي؛ الإصبع المصوّر يُضاف في الإنتاج.']:time<10?['6–10 ثانية','من شاشة الدور للكارت','نقرّب على الشاشة ثم الكارت يتقدّم. ده اختبار انتقال، مش تسجيل جلسة تطبيق متصلة.']:time<12?['10–12 ثانية','لحظة الكشف','ثبات قصير بعد الحركة. في النسخة الكاملة يحصل الكشف بعد النقاش والتصويت، مش هنا.']:time<16?['12–16 ثانية','نفس الكارت يفتح قضية','ورق المانيلا يفتح ويحتل الكادر، ثم الشخصية والدليل. هوية القصص لها بيئة وإضاءة مختلفة.']:['16–18 ثانية','رجوع لنفس الوش','نرجع لتركيب الهوك. القفلة المستهدفة: وشوف مين فيهم هيقول أنا بريء.'];
[$('beatTime').textContent,$('beatTitle').textContent,$('beatAction').textContent]=beats;
}
window.__seek=draw;
function select(key){playing=false;$('play').textContent='شغّل الفكرة ▶';concept=key;const d=directions[key];$('world').src=d.image;$('world').alt=d.title;for(const [id,value]of Object.entries({conceptLabel:d.label,conceptTitle:d.title,idea:d.idea,firstFive:d.firstFive,retention:d.retention,signature:d.signature}))$(id).textContent=value;$('hook').innerHTML=d.hook;document.querySelectorAll('[data-concept]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.concept===key)));draw(0);}
document.querySelectorAll('[data-concept]').forEach(b=>b.addEventListener('click',()=>select(b.dataset.concept)));
$('seek').addEventListener('input',e=>{playing=false;$('play').textContent='شغّل الفكرة ▶';draw(Number(e.target.value));});
$('reset').addEventListener('click',()=>{playing=false;$('play').textContent='شغّل الفكرة ▶';draw(0);});
$('play').addEventListener('click',()=>{playing=!playing;if(playing){if(time>=18)draw(0);base=time;origin=performance.now();}$('play').textContent=playing?'إيقاف مؤقت ❚❚':'شغّل الفكرة ▶';});
function tick(now){if(playing){draw(base+(now-origin)/1000);if(time>=18){playing=false;$('play').textContent='إعادة الفكرة ▶';}}requestAnimationFrame(tick);}requestAnimationFrame(tick);
function fitCanvas(){draw(time);}fitCanvas();window.addEventListener('resize',fitCanvas);
// Not autoplayed; reduced-motion users can inspect all poses with the range control.
