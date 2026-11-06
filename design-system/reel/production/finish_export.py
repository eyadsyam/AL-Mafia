from pathlib import Path
import subprocess,json,re,argparse,shutil
parser=argparse.ArgumentParser();parser.add_argument('--input',required=True);parser.add_argument('--output',required=True);args=parser.parse_args()
src=Path(args.input).resolve();dst=Path(args.output).resolve();R=Path(__file__).resolve().parent
analysis=subprocess.run(['ffmpeg','-hide_banner','-i',str(src),'-af','loudnorm=I=-15:TP=-1.5:LRA=11:print_format=json','-f','null','NUL'],capture_output=True,text=True,encoding='utf-8',errors='replace',check=True)
m=json.loads(re.search(r'\{\s*"input_i".*?\}',analysis.stderr,re.S).group())
(R/'qa/loudness-input.json').write_text(json.dumps(m,indent=2))
audio=f"loudnorm=I=-15:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true:print_format=json"
encode=subprocess.run(['ffmpeg','-hide_banner','-y','-i',str(src),'-map','0:v:0','-map','0:a:0','-c:v','copy','-af',audio,'-c:a','aac','-b:a','192k','-ar','48000','-t','59','-movflags','+faststart','-metadata','title=سيد المافيا — إنت المافيا',str(dst)],capture_output=True,text=True,encoding='utf-8',errors='replace',check=True)
(R/'qa/audio-master.log').write_text(encode.stderr,encoding='utf-8')
verify=subprocess.run(['ffmpeg','-hide_banner','-i',str(dst),'-af','loudnorm=I=-15:TP=-1.5:LRA=11:print_format=json','-f','null','NUL'],capture_output=True,text=True,encoding='utf-8',errors='replace',check=True)
final_loudness=json.loads(re.search(r'\{\s*"input_i".*?\}',verify.stderr,re.S).group())
(R/'qa/loudness-final.json').write_text(json.dumps(final_loudness,indent=2))
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=codec_name,codec_type,width,height,r_frame_rate,nb_read_frames,sample_rate,channels:format=duration','-of','json',str(dst)]))
vs=next(s for s in probe['streams'] if s['codec_type']=='video')
assert (vs['width'],vs['height'],vs['r_frame_rate'],vs['nb_read_frames'])==(1080,1920,'30/1','1770')
assert float(probe['format']['duration'])<60
assert -16<=float(final_loudness['input_i'])<=-14,final_loudness
assert float(final_loudness['input_tp'])<=-1,final_loudness
(R/'qa/final-probe.json').write_text(json.dumps(probe,indent=2))
black=subprocess.run(['ffmpeg','-hide_banner','-i',str(dst),'-vf','blackdetect=d=0.02:pix_th=0.05:pic_th=0.99','-an','-f','null','NUL'],capture_output=True,text=True,encoding='utf-8',errors='replace',check=True)
(R/'qa/black-frame-check.log').write_text(black.stderr,encoding='utf-8')
assert 'black_start:' not in black.stderr,'Unexpected nearly-all-black frame interval'
subprocess.run(['ffmpeg','-v','error','-i',str(dst),'-frames:v','1','-y',str(dst.parent/'MAFIA_ONLINE_REEL_POSTER.png')],check=True)
shutil.copy2(R/'transcripts/transcript.srt',dst.parent/'MAFIA_ONLINE_REEL_AR.srt')
print(json.dumps({'output':str(dst),'seconds':probe['format']['duration'],'frames':vs['nb_read_frames'],'LUFS':final_loudness['input_i'],'true_peak_dBTP':final_loudness['input_tp'],'black_frames':False},ensure_ascii=False))
