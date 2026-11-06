from pathlib import Path
import subprocess,json,re,hashlib
R=Path(__file__).resolve().parent
src=R/'exports/MAFIA_V2_RENDER.mp4';dst=R/'exports/MAFIA_V2_صاحبك_اللي_بريء.mp4'
def run(cmd):return subprocess.run(cmd,capture_output=True,text=True,encoding='utf-8',errors='replace',check=True)
a=run(['ffmpeg','-hide_banner','-i',str(src),'-af','loudnorm=I=-15:TP=-1.5:LRA=11:print_format=json','-f','null','NUL'])
m=json.loads(re.search(r'\{\s*"input_i".*?\}',a.stderr,re.S).group())
af=f"loudnorm=I=-15:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true"
run(['ffmpeg','-hide_banner','-y','-i',str(src),'-map','0:v:0','-map','0:a:0','-c:v','copy','-af',af,'-c:a','aac','-b:a','192k','-ar','48000','-ac','2','-t','57','-movflags','+faststart','-metadata','title=سيد المافيا — صاحبك اللي بريء',str(dst)])
probe=json.loads(run(['ffprobe','-v','error','-count_frames','-show_entries','stream=codec_name,codec_type,width,height,r_frame_rate,nb_read_frames,sample_rate,channels:format=duration','-of','json',str(dst)]).stdout)
v=next(s for s in probe['streams'] if s['codec_type']=='video');au=next(s for s in probe['streams'] if s['codec_type']=='audio')
assert (v['width'],v['height'],v['r_frame_rate'],v['nb_read_frames'])==(1080,1920,'30/1','1710'),probe
assert float(probe['format']['duration'])<60
l=run(['ffmpeg','-hide_banner','-i',str(dst),'-af','loudnorm=I=-15:TP=-1.5:LRA=11:print_format=json','-f','null','NUL'])
lm=json.loads(re.search(r'\{\s*"input_i".*?\}',l.stderr,re.S).group())
assert -16<=float(lm['input_i'])<=-14
assert float(lm['input_tp'])<=-1
b=run(['ffmpeg','-hide_banner','-i',str(dst),'-vf','blackdetect=d=0.02:pix_th=0.05:pic_th=0.99','-an','-f','null','NUL'])
assert 'black_start:' not in b.stderr
run(['ffmpeg','-v','error','-y','-ss','1.8','-i',str(dst),'-frames:v','1',str(R/'exports/POSTER.png')])
run(['ffmpeg','-v','error','-y','-i',str(dst),'-vf','fps=1/3,scale=216:-1,tile=5x4','-frames:v','1',str(R/'qa/render-contact-sheet.jpg')])
report={'probe':probe,'loudness':lm,'black_intervals':False,'sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'file':str(dst),'subjective_voice_listening':'not independently verified','generated_acting_clips':5,'additional_video_quota_block':'237 remaining vs3394 requested; LTX estimate1454 not run','offline':'animated phone/card props, no generated group acting','stories':'persistent paper/camera motion, real artwork, no generated cafe video'}
(R/'qa/final.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
s=json.loads((R.parent.parent/'STATE.json').read_text(encoding='utf-8'))
s['phase']='revision_v2_full_cut_delivered_with_recorded_limits';s['character']['performance_clips_ready']=True;s['character']['performance_clip_count']=5
s['milestones'].update(character_gate=True,picture_gate=True,audio_mix_gate=True,render_gate=True)
s['revision_v2'].update(full_video_rendered=True,character_animation_completed=True)
s['outputs'].update(video=str(dst),poster=str(R/'exports/POSTER.png'),subtitles=str(R/'exports/MAFIA_V2_AR.srt'),editable_project=str(R/'project/index.html'),qa_report=str(R/'qa/final.json'),preview='http://localhost:3034/#project/project')
s['known_dependencies']=[]
s['known_limits']=['Full second B film not produced; owner allowed one A film first.','Additional generated offline/cafe acting blocked by provider credits; current cut uses independent prop/paper motion there.','Adam tone preference remains subjective; technical transcript and audio mix checks do not substitute for listening.']
(R.parent.parent/'STATE.json').write_text(json.dumps(s,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'video':str(dst),'duration':probe['format']['duration'],'frames':v['nb_read_frames'],'LUFS':lm['input_i'],'peak':lm['input_tp']}))
