import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { stat, readFile, writeFile, mkdtemp } from 'node:fs/promises';
import { resolve, join, extname, sep } from 'node:path';
import { spawn } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';
import assert from 'node:assert/strict';

const root = resolve('build/web');
const server = createServer(async (req, res) => {
  let path = resolve(root, '.' + new URL(req.url, 'http://localhost').pathname);
  if (path !== root && !path.startsWith(root + sep)) { res.writeHead(403).end(); return; }
  try {
    if ((await stat(path)).isDirectory()) path = join(path, 'index.html');
  } catch { path = join(root, 'index.html'); }
  const size = (await stat(path)).size;
  const headers = { 'Content-Type': ({'.js':'text/javascript','.wasm':'application/wasm','.html':'text/html','.json':'application/json','.mp4':'video/mp4','.webp':'image/webp','.png':'image/png','.woff2':'font/woff2'})[extname(path)] ?? 'application/octet-stream', 'Accept-Ranges':'bytes' };
  const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range ?? '');
  if (range) {
    const start = +range[1], end = range[2] ? Math.min(+range[2],size-1) : size-1;
    if (start > end) { res.writeHead(416,{'Content-Range':`bytes */${size}`}).end(); return; }
    res.writeHead(206,{...headers,'Content-Range':`bytes ${start}-${end}/${size}`,'Content-Length':end-start+1});
    createReadStream(path,{start,end}).pipe(res);
  } else {
    res.writeHead(200,{...headers,'Content-Length':size}); createReadStream(path).pipe(res);
  }
});
await new Promise(ok => server.listen(0,'127.0.0.1',ok));
const profile = await mkdtemp(resolve('build/web-smoke-profile-'));
const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',[
  '--headless=new',`--user-data-dir=${profile}`,'--remote-debugging-port=0','--no-first-run','--no-default-browser-check','about:blank',
],{windowsHide:true,stdio:'ignore'});
let ws;
try {
  let port;
  for(let i=0;i<80&&!port;i++) {
    try {port=(await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];}catch {await delay(250);}
  }
  assert(port,'Chrome did not start');
  const tabs=await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  ws=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
  await new Promise((ok,fail)=>{ws.onopen=ok;ws.onerror=fail;});
  let id=0; const calls=new Map(); const externalStartupAssets=[];
  ws.onmessage=e=>{const r=JSON.parse(e.data);if(r.method==='Network.requestWillBeSent'){const u=new URL(r.params.request.url);if(u.hostname.endsWith('gstatic.com'))externalStartupAssets.push(u.pathname);}if(r.method==='Network.loadingFailed')console.log('browser request failed',r.params.errorText);if(r.method==='Runtime.exceptionThrown')console.log('browser exception',r.params.exceptionDetails.text); if(calls.has(r.id)){calls.get(r.id)(r);calls.delete(r.id);}};
  async function cmd(method,params={}) {
    const seq=++id;
    const result=await Promise.race([new Promise(ok=>{calls.set(seq,ok);ws.send(JSON.stringify({id:seq,method,params}));}),delay(15000).then(()=>{throw Error('CDP timeout');})]);
    if(result.error)throw Error(result.error.message);return result.result;
  }
  async function evaluate(expression){return (await cmd('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true})).result.value;}
  await cmd('Page.enable');await cmd('Network.enable');await cmd('Runtime.enable');
  await cmd('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});
  await cmd('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/`});
  const videoExpr=`(()=>{function find(r){const v=r.querySelector('video');if(v)return v;for(const e of r.querySelectorAll('*')){if(e.shadowRoot){const x=find(e.shadowRoot);if(x)return x;}}}const v=find(document);if(!v)return null;const b=v.getBoundingClientRect();return {ready:v.readyState,w:v.videoWidth,h:v.videoHeight,x:b.x,y:b.y,width:b.width,height:b.height,paused:v.paused,time:v.currentTime,frames:v.getVideoPlaybackQuality?.().totalVideoFrames??v.webkitDecodedFrameCount??0};})()`;
  let video;
  for(let i=0;i<100;i++){video=await evaluate(videoExpr);if(video?.ready>=2)break;await delay(500);}
  if (!video || video.ready<2) {
    const failureShot=await cmd('Page.captureScreenshot',{format:'png',clip:{x:0,y:0,width:390,height:844,scale:420/844}});
    await writeFile('build/web-video-failure.png',Buffer.from(failureShot.data,'base64'));
    console.log('readiness',video,'page',await evaluate('document.body.innerText'));
  }
  assert(video?.ready>=2,'intro never reached a decodable frame');
  assert.deepEqual(externalStartupAssets, [], 'startup depends on external renderer/font assets');
  console.log('PASS startup uses bundled renderer and fonts');
  const sizes=[[360,800],[390,844],[768,1024],[1280,800],[1920,1080]];
  for(const [width,height] of sizes){
    await cmd('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:width<768});await delay(500);
    const v=await evaluate(videoExpr);assert(v.width>0&&v.height>0,'invisible video');
    assert(v.x>=-1&&v.y>=-1&&v.x+v.width<=width+1&&v.y+v.height<=height+1,`video overflow at ${width}x${height}`);
    assert(Math.abs(v.width/v.height-v.w/v.h)<0.02,'video aspect ratio changed');
    console.log(`PASS video bounds ${width}x${height}`);
  }
  await cmd('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});await delay(500);
  video=await evaluate(videoExpr);
  for(const type of ['mousePressed','mouseReleased'])await cmd('Input.dispatchMouseEvent',{type,x:video.x+video.width/2,y:video.y+video.height/2,button:'left',clickCount:1});
  await delay(2500);
  const playing=await evaluate(videoExpr);assert(!playing.paused&&playing.time>0&&playing.frames>1,'gesture did not start decoded playback');
  const shot=await cmd('Page.captureScreenshot',{format:'png',clip:{x:0,y:0,width:390,height:844,scale:420/844}});
  await writeFile('build/web-video-smoke.png',Buffer.from(shot.data,'base64'));
  console.log('PASS real browser gesture starts video frames; human audio sync NOT VERIFIED');
}finally{ws?.close();chrome.kill();server.close();}
