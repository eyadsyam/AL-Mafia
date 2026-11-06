from pathlib import Path
import subprocess,json,re,hashlib
R=Path(__file__).resolve().parent
timing=json.loads((R/'timeline.locked.json').read_text(encoding='utf-8'));seconds=str(timing['duration']);frames=str(timing['frames'])
src=R/'exports/MAFIA_V3_RENDER.mp4';dst=R/'exports/MAFIA_V3_صاحبك_اللي_بريء.mp4'
def run(cmd):return subprocess.run(cmd,capture_output=True,text=True,encoding='utf-8',errors='replace',check=True)
a=run(['ffmpeg','-hide_banner','-i',str(src),'-af','loudnorm=I=-15:TP=-1.5:LRA=11:print_format=json','-f','null','NUL'])
m=json.loads(re.search(r'\{\s*"input_i".*?\}',a.stderr,re.S).group())
af=f"loudnorm=I=-15:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true"
run(['ffmpeg','-hide_banner','-y','-i',str(src),'-map','0:v:0','-map','0:a:0','-c:v','copy','-af',af,'-c:a','aac','-b:a','192k','-ar','48000','-ac','2','-t',seconds,'-movflags','+faststart','-metadata','title=سيد المافيا — صاحبك اللي بريء — V3',str(dst)])
probe=json.loads(run(['ffprobe','-v','error','-count_frames','-show_entries','stream=codec_name,codec_type,width,height,r_frame_rate,nb_read_frames,sample_rate,channels:format=duration','-of','json',str(dst)]).stdout)
v=next(s for s in probe['streams'] if s['codec_type']=='video');au=next(s for s in probe['streams'] if s['codec_type']=='audio')
assert (v['width'],v['height'],v['r_frame_rate'],v['nb_read_frames'])==(1080,1920,'30/1',frames),probe
assert float(probe['format']['duration'])<60
l=run(['ffmpeg','-hide_banner','-i',str(dst),'-af','loudnorm=I=-15:TP=-1.5:LRA=11:print_format=json','-f','null','NUL'])
lm=json.loads(re.search(r'\{\s*"input_i".*?\}',l.stderr,re.S).group())
assert -16<=float(lm['input_i'])<=-14
assert float(lm['input_tp'])<=-1
b=run(['ffmpeg','-hide_banner','-i',str(dst),'-vf','blackdetect=d=0.02:pix_th=0.05:pic_th=0.99','-an','-f','null','NUL'])
assert 'black_start:' not in b.stderr
run(['ffmpeg','-v','error','-y','-ss','1.8','-i',str(dst),'-frames:v','1',str(R/'exports/POSTER.png')])
run(['ffmpeg','-v','error','-y','-i',str(dst),'-vf','fps=1/3,scale=216:-1,tile=5x4','-frames:v','1',str(R/'qa/render-contact-sheet.jpg')])
report={'probe':probe,'loudness':lm,'black_intervals':False,'sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'file':str(dst),'subjective_voice_listening':'not independently verified; new acted take/hook surfaced for owner','generated_acting_clips':6,'gameplay_clips':6,'voice':'Fekry Egyptian eleven_v3 passion1, protected pause edit, native pitch/speed','pause_edit':'passion-pause-edit.json','source_capture':'Real release widgets rendered at30fps with seeded backend; not a live multi-user online match','sfx_palette':'14 original game sounds peak balanced;21 timed events','offline':'new continuous group acting','stories':'real interactive Flutter footage plus paper/camera motion'}
(R/'qa/final.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
s=json.loads((R.parent.parent/'STATE.json').read_text(encoding='utf-8'))
s['phase']='revision_v3_final_export_verified';s['character']['performance_clips_ready']=True;s['character']['performance_clip_count']=6
s['milestones'].update(character_gate=True,picture_gate=True,audio_mix_gate=True,render_gate=True)
s['revision_v3'].update(image_gate=True,gameplay_gate=True,sound_gate=True,voice_gate=True,render_gate=True)
s['voice'].update(name='Fekry Egyptian passion performance',model='eleven_v3',selected_take='passion1',word_aligned=True,pitch_speed_changed=False)
s['outputs'].update(video=str(dst),poster=str(R/'exports/POSTER.png'),subtitles=str(R/'exports/MAFIA_V3_AR.srt'),editable_project=str(R/'project/index.html'),qa_report=str(R/'qa/final.json'),preview='http://127.0.0.1:3033/review.html',studio='http://localhost:3035/#project/project')
s['known_dependencies']=[]
s['known_limits']=['Gameplay captured from genuine release widgets with seeded backend, not a real connected multiplayer match.','Subjective voice preference remains for owner; no numerical aesthetic/listening score claimed.'];s['active_runs']={}
(R.parent.parent/'STATE.json').write_text(json.dumps(s,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'video':str(dst),'duration':probe['format']['duration'],'frames':v['nb_read_frames'],'LUFS':lm['input_i'],'peak':lm['input_tp']}))
