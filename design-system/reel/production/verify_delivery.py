from pathlib import Path
import subprocess,json,hashlib
R=Path(__file__).resolve().parent;video=R/'exports/MAFIA_ONLINE_REEL_AR_59s.mp4'
raw=subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','frame=best_effort_timestamp_time','-of','csv=p=0',str(video)],text=True)
times=[]
for line in raw.splitlines():
    try:times.append(float(line.split(',')[0]))
    except ValueError:pass
assert len(times)==1770,len(times)
deviation=max(abs(t-i/30) for i,t in enumerate(times))
assert deviation<.00001,deviation
(R/'qa/frame-timing.json').write_text(json.dumps({'frames':len(times),'fps':30,'start':times[0],'last':times[-1],'max_deviation_seconds':deviation,'CFR_verified_every_frame':True},indent=2))
meta=json.loads((R/'qa/final-probe.json').read_text())
audio=json.loads((R/'qa/loudness-final.json').read_text())
statepath=R.parent/'STATE.json';state=json.loads(statepath.read_text(encoding='utf-8'))
state['phase']='export_ready_listening_review_open'
state['outputs'].update(final_video=str(video),poster=str(R/'exports/MAFIA_ONLINE_REEL_POSTER.png'),srt=str(R/'exports/MAFIA_ONLINE_REEL_AR.srt'),project=str(R/'project'),qa_report=str(R/'qa/QA_REPORT.md'))
state['milestones'].update(render_gate=True,audio_mix_gate=True,picture_gate=True,character_gate=True,voice_gate=False)
state['voice'].update(provider_script_match=True,audition_listened=False,working_duration=56.50002083333333,full_sessions=json.loads((R/'qa/voice-run.json').read_text())['session_ids'])
state['character'].update(rig='production/project/scene-runtime.js',speech_test_passed=True)
state['timing'].update(aligned=True,locked='production/timeline.locked.json')
state['known_dependencies']=['Independent subjective voice/music and full-speed audiovisual listening review remains unverified.']
state['last_note']='Final MP4 exported and technically verified: 59s,1080x1920,1770 CFR frames, about -15LUFS. Subjective listening review remains open; no false complete-all-gates claim.'
statepath.write_text(json.dumps(state,ensure_ascii=False,indent=2),encoding='utf-8')
out={'video':str(video),'bytes':video.stat().st_size,'sha256':hashlib.sha256(video.read_bytes()).hexdigest(),'frames':1770,'duration':meta['format']['duration'],'LUFS':audio['input_i'],'true_peak':audio['input_tp'],'independent_listening_verified':False}
(R/'qa/delivery.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(out,ensure_ascii=False))
