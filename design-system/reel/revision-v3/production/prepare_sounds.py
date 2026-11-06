from pathlib import Path
import subprocess,re,json
R=Path(__file__).resolve().parent; A=R/'project/assets/audio'
names=['night_falls','morning','card_flip','vote_tick','elimination_reveal','lobby_ready_tick','join_chime','speaker_change','casebook_paper_slide','casebook_wax_press','casebook_string_pluck','share_paper_eject','chapter_envelope_open','brand_motif']
report=[]
for n in names:
    p=A/(n+'.ogg')
    r=subprocess.run(['ffmpeg','-hide_banner','-i',str(p),'-af','volumedetect','-f','null','NUL'],capture_output=True,text=True,encoding='utf-8',errors='replace',check=True)
    peak=float(re.search(r'max_volume: ([\-\d.]+)',r.stderr)[1])
    dur=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',str(p)]))
    target=-17 if n in ['night_falls','morning'] else -11 if n=='elimination_reveal' else -13
    used=2.0 if n=='night_falls' else 1.0 if n=='morning' else dur
    f=f'volume={target-peak}dB,afade=t=in:d=0.003,afade=t=out:st={max(0,used-.035)}:d=0.035'
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(p),'-t',str(used),'-af',f,'-ar','48000','-ac','2',str(A/('fx-'+n+'.wav'))],check=True)
    report.append({'name':n,'source':str(p),'seconds':dur,'source_peak':peak,'target_peak':target,'gain_db':target-peak})
(R/'research/sound-palette.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('Prepared',len(report),'original game sounds, balanced peaks, native speed.')
