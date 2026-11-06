/* All picture state derives solely from supplied composition time. */
window.REEL={
 bind(id,start,duration){
   document.fonts.ready.then(()=>{
     const root=document.querySelector('[data-composition-id="'+id+'"]');
     const clock={t:0};const tl=gsap.timeline({paused:true});
     tl.to(clock,{t:duration,duration:duration,ease:'none',onUpdate:()=>window.REEL.draw(root,id,clock.t,start)},0);
     window.REEL.draw(root,id,0,start);
     window.__timelines[id]=tl;
   });
 },
 draw(root,id,t,start){
   if(!root)return;const D=window.REEL_DATA;const global=t+start;
   const q=s=>root.querySelector(s),qa=s=>Array.from(root.querySelectorAll(s));
   const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));const ease=v=>1-Math.pow(1-clamp(v),3);
   const pose=(el,x=0,y=0,s=1,r=0,o=1)=>{if(el){el.style.transform=`translate(${x}px,${y}px) scale(${s}) rotate(${r}deg)`;el.style.opacity=o;}};
   const cue=n=>D.cues.find(c=>c.id===n);const rel=n=>cue(n).speech_start-start;
   const clean=s=>s.replace(/[\u064b-\u065f]/g,'').replace(/[؟.,،]/g,'').trim();
   const ws=(word,fallback,min=0,max=59)=>{const w=(D.words||[]).find(w=>clean(w.text)===word&&w.start>=min&&w.start<=max);return w?w.start:fallback;};
   const intro=ease(t/.35);pose(q('.headlines'),0,(1-intro)*25,1,0,intro);
   let energy=D.energy[Math.min(D.energy.length-1,Math.max(0,Math.floor(global/D.energy_hop)))]||0;
   const speaking=D.speech_regions.some(([a,b])=>global>=a&&global<b);
   if(!speaking)energy=0;
   const host=q('.host-stage');
   if(host){
     const wide=id==='S01'?ease((t-2.6)/.7):1;
     const scale=id==='S06'?1.1:1.02+(1-wide)*.06;
     pose(host,0,20,scale);
     const nod=id==='S06'?Math.sin(Math.PI*clamp((global-cue('C11').subphrases[1][0])/.6)):0;
     const hx=Math.sin(global*1.1)*1.2,hy=Math.sin(global*.8)*.8+nod*2,hr=Math.sin(global*.6)*.35+nod*.65;
     pose(q('.host-upper'),hx,hy,1,hr);
     pose(q('.host-jaw'),hx,hy+energy*5,1,hr+energy*.6);
     const contact=ease(t/.47);const release=ease((t-.8)/.45);
     const withdraw=id==='S08'?ease((t-1)/.5):0;
     pose(q('.host-hand'),id==='S01'?(1-contact)*45+release*12:-withdraw*18,id==='S01'?(1-contact)*25-release*15:-withdraw*12,1,id==='S01'?(1-contact)*2:0);
     pose(q('.deal-card'),id==='S01'?(1-contact)*45:0,id==='S01'?(1-contact)*25:0,1,-6);
   }
   if(id==='S01'){const phase=global<ws('وهما',cue('C01').subphrases[1][0])?0:global<cue('C02').speech_start?1:2;q('.hook').textContent=['إنت المافيا','وهما لسه مايعرفوش','من غير ما تتكشف؟'][phase];q('.hook').style.fontSize=[84,60,64][phase]+'px';}
   if(id==='S02'){
     qa('.online-portrait').forEach((e,i)=>pose(e,0,(1-ease((t-i*.1)/.45))*45,1,0,ease((t-i*.1)/.45)));
     qa('.connection-card').forEach((e,i)=>pose(e,(1-ease((t-1.3)/.5))*(i-1)*95,0,1,(i-1)*8,ease((t-1.3)/.4)));
     pose(q('.connect'),0,0,ease((t-.7)/.6),0,.55);
   }
   if(id==='S03'){pose(q('.role-main'),0,30*(1-intro),.96+.04*intro,0,intro);}
   if(id==='S04'){
     const doctor=ws('الدكتور',cue('C06').speech_start),detective=ws('والمحقق',cue('C07').speech_start);
     const which=global<doctor?0:global<detective?1:2;
     const phase=[rel('C05'),doctor-start,detective-start][which];const e=ease((t-phase)/.23);
     qa('.role-main').forEach((node,i)=>pose(node,0,20*(1-e),.98+.02*e,0,i===which?1:0));
     q('.role-name').textContent=['المافيا','الدكتور','المحقق'][which];
   }
   if(id==='S05'){
     const v=ease((t-rel('C10'))/.4);qa('.day-cast').forEach((e,i)=>pose(e,(i?1:-1)*v*80,0,1,0,1-v));
     pose(q('.vote-card'),0,(1-v)*60,.93+.07*v,0,v);
     q('.caption').textContent=global<cue('C10').speech_start?'مين بيكدب؟':'النقاش… وبعده التصويت';
   }
   if(id==='S06'){pose(q('.vote-card'),-ease(t/.65)*600,-ease(t/.65)*30,1,-ease(t/.65)*14,1-ease(t/.8));const e=ease((global-cue('C11').subphrases[1][0])/.18);pose(q('.badge'),0,0,1,0,e);}
   if(id==='S07'){pose(q('.offline-card'),(1-ease(t/1.4))*280-ease((t-1.5)/.7)*180,0,1,-6+ease(t/1.4)*10);}
   if(id==='S09'){const e=ease(t/.7);pose(q('.folder'),(1-e)*(-9),(1-e)*390.55,.5+.5*e,-6+6*e);pose(q('.case-meta'),0,0,1,0,ease((t-.75)/.25));}
   if(id==='S10'){
     qa('.photo').forEach((e,i)=>pose(e,0,(1-ease((t-i*.12)/.35))*30,1,(i-1)*1.5,ease((t-i*.12)/.3)));
     const action=ease((t-.9)/.35);pose(q('.action-paper'),-35*(1-action),0,1,0,action);
     const chosen=t>1.5;q('.meter b').textContent=chosen?'10 / 12':'12 / 12';
     const e=ease((t-2)/.4);pose(q('.evidence'),0,20*(1-e),.96+.04*e,0,e);
     q('.evidence-tag').textContent=global>=cue('C16').speech_start?'هتبدأ بمين؟':'إنت تختار تحقّق فين';
   }
   if(id==='S11'){
     const parts=cue('C17').subphrases;qa('.question-paper').forEach((el,i)=>{const begin=ws(['مين','ليه','وإزاي'][i],parts[i+1][0],cue('C17').speech_start,cue('C17').speech_end)-start;const e=ease((t-begin)/.25);pose(el,20*(1-e),0,.98+.02*e,0,e);});
   }
   if(id==='S12'){
     const e=ease(t/.3);pose(q('.brand-title'),0,20*(1-e),1,0,e);
     pose(q('.final-cta'),0,0,1,0,ease((t-.8)/.3));
   }
 }
};
