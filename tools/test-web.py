#!/usr/bin/env python3
"""Open the exported Godot build, perform actual canvas input, and verify its saved simulation state."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json, threading, argparse, time
from playwright.sync_api import sync_playwright
parser=argparse.ArgumentParser()
parser.add_argument('--dpr',type=float,default=1,help='Emulated device pixel ratio; 3 checks Retina-sized UI')
parser.add_argument('--mobile-preflight',action='store_true',help='Resize/inset, background and real page reload checks in a private context')
parser.add_argument('--url',help='Actual accessible export URL; defaults to isolated localhost test server')
parser.add_argument('--touch',action='store_true')
parser.add_argument('--debug-captures',action='store_true',help='Also capture each intermediate UI state')
parser.add_argument('--save-timeout',type=float,default=300,help='Wall-clock allowance per saved-state wait; software WebGL may render far below real time')
args=parser.parse_args()
if args.save_timeout <= 0: parser.error('--save-timeout must be positive')
repo = Path(__file__).resolve().parents[1]
output = repo / ('artifacts/browser-touch' if args.touch else 'artifacts/browser')
output.mkdir(parents=True, exist_ok=True)
(output/'results.json').unlink(missing_ok=True)
class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
server = ThreadingHTTPServer(('127.0.0.1',0),partial(QuietHandler,directory=str(repo/'artifacts/web')))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
        width,height=(844,390) if args.touch else (1280,720)
        page = browser.new_page(viewport={'width':width,'height':height},has_touch=args.touch,is_mobile=args.touch,device_scale_factor=args.dpr)
        page.set_default_timeout(120000)
        messages=[]
        (output/'console.log').write_text('')
        def record_message(message):
            messages.append(message)
            with (output/'console.log').open('a') as log: log.write(message+'\n')
        page.on('console',lambda m: record_message(m.type+': '+m.text))
        page.on('pageerror',lambda e: record_message('pageerror: '+str(e)))
        read_saves = '''async () => {
          const results=[];
          for (const info of await indexedDB.databases()) {
            const db=await new Promise((resolve,reject)=>{const r=indexedDB.open(info.name);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
            for(const store of db.objectStoreNames){
              const values=await new Promise((resolve,reject)=>{const r=db.transaction(store).objectStore(store).getAll();r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
              for(const value of values){try{const parsed=JSON.parse(new TextDecoder().decode(value.contents));if(parsed.implementation==='sunshine-rebuild-2026-11')results.push(parsed)}catch{}}
            }
            db.close();
          }
          return results;
        }'''
        def wait_saved(predicate, timeout=None):
            # Await each IndexedDB read explicitly. A resolved undefined JS
            # handle is not evidence that the requested saved state exists.
            deadline=time.monotonic()+(args.save_timeout if timeout is None else timeout)
            while time.monotonic()<deadline:
                states=page.evaluate(read_saves)
                (output/'live-controls.json').write_text(json.dumps(page.evaluate('({controls:window.sunshineControls,visibility:document.visibilityState,canvas:[document.querySelector("#canvas").width,document.querySelector("#canvas").height],css:[innerWidth,innerHeight]})'),indent=2))
                (output/'last-save-state.json').write_text(json.dumps(states,indent=2))
                for state in states:
                    if predicate(state): return state
                page.wait_for_timeout(1000)
            (output/'failed-save-state.json').write_text(json.dumps(page.evaluate(read_saves),indent=2))
            raise AssertionError('Expected simulation state was not persisted to IndexedDB; see console.log and failed-save-state.json')
        started=time.monotonic()
        base=args.url or f'http://127.0.0.1:{server.server_port}/index.html'
        page.goto(base+('\u0026' if '?' in base else '?')+'playtest=1')
        page.wait_for_function("!document.querySelector('#status') || document.querySelector('#status').style.display === 'none'",timeout=60000)
        loader_done_seconds=time.monotonic()-started
        # Software WebGL startup varies; require an arrived patient in this
        # fresh browser's persisted simulation before attempting admission.
        wait_saved(lambda state: state.get('patients') and state['patients'][0]['state']=='waiting')
        initial_seconds=time.monotonic()-started
        print('WEB: first patient arrived and saved',flush=True)
        if args.debug_captures: page.screenshot(timeout=120000,scale='css',path=str(output/'before-admission.png'))
        canvas=page.evaluate('''() => {
            const canvas=document.querySelector('#canvas');
            if (!canvas) return null;
            const r=canvas.getBoundingClientRect();
            return {x:r.x,y:r.y,width:r.width,height:r.height};
        }''')
        assert canvas, 'Game canvas missing'
        assert abs(canvas['width']-width)<1 and abs(canvas['height']-height)<1, 'Game does not fill browser viewport'
        def click(x,y):
            if args.touch: page.touchscreen.tap(x,y)
            else: page.mouse.click(x,y,delay=100)
            # Wait for real browser frames, not a fixed delay that can expire
            # before the software renderer has processed the previous click.
            page.evaluate('async () => { for (let i=0;i<12;i++) await new Promise(requestAnimationFrame); }')
        def press(name):
            control=page.evaluate('(name) => window.sunshineControls?.[name]',name)
            assert control and control['visible'], f'Missing visible control {name}'
            with (output/'inputs.jsonl').open('a') as log: log.write(json.dumps({'name':name,'control':control})+'\n')
            click(control['x'],control['y'])
            print('WEB input: '+name,flush=True)
        press('patients')
        if args.debug_captures: page.screenshot(timeout=120000,scale='css',path=str(output/'patient-roster.png'))
        press('first_patient')
        if args.debug_captures: page.screenshot(timeout=120000,scale='css',path=str(output/'patient-selected.png'))
        press('action')
        # Inspect this fresh test browser's own IndexedDB filesystem, never the user's profile.
        # IDBFS synchronizes asynchronously. Wait for evidence of the action in persistent storage.
        state=wait_saved(lambda state: state.get('patients') and state['patients'][0]['state'] not in ['waiting','entering'])
        story=state.get('first_day_story',{})
        ledger=state.get('daily_ledger',{})
        assert ledger=={'version':1,'opening_money':900,'income':0,'expansion_expense':0,'new_annex':False}, 'Actual opening/day receipts were not saved correctly'
        assert story.get('version')==1 and story.get('seen',{}).get('admission'), 'State-driven tutorial was not saved after actual admission'
        page.screenshot(timeout=120000,scale='css',path=str(output/'after-admission.png'))
        preflight={}
        if args.mobile_preflight:
            # Pause through the real button, then resize this same live game.
            press('pause')
            page.wait_for_function('window.sunshineControls?._state.paused')
            live=page.evaluate('window.sunshineControls._state')
            before=wait_saved(lambda s:abs(s.get('time',-1)-live['time'])<.001)
            layouts=[]
            for w,h in [(844,390),(915,412),(1280,720),(844,350)]:
                page.set_viewport_size({'width':w,'height':h})
                insets=[47,0,47,21] if w<1000 else [0,0,0,0]
                page.evaluate('(v)=>document.querySelector("#safe-area").style.padding=`${v[1]}px ${v[2]}px ${v[3]}px ${v[0]}px`',insets)
                page.evaluate('async()=>{for(let i=0;i<5;i++)await new Promise(requestAnimationFrame)}')
                controls=page.evaluate('window.sunshineControls')
                for name in ['patients','pause','zoom_in','zoom_out','action']:
                    c=controls[name]
                    assert c['visible'] and c['width']>=43.9 and c['height']>=43.9,(w,h,name,c)
                    assert c['x']-c['width']/2>=insets[0] and c['x']+c['width']/2<=w-insets[2]+.1,(w,h,name,c)
                    assert c['y']+c['height']/2<=h-insets[3]+.1,(w,h,name,c)
                press('zoom_in');press('zoom_out');press('settings')
                page.screenshot(timeout=120000,scale='css',path=str(output/f'{w}x{h}-safe-settings.png'))
                press('guide_close')
                page.screenshot(timeout=120000,scale='css',path=str(output/f'{w}x{h}-safe-card.png'))
                layouts.append({'viewport':[w,h],'synthetic_insets':insets,'controls':controls})
            # Chromium lifecycle freezing is not an iOS app switch. Exercise the
            # real visibility listener before freezing the browser page.
            cdp=page.context.new_cdp_session(page)
            cdp.send('Page.setWebLifecycleState',{'state':'frozen'})
            time.sleep(2)
            cdp.send('Page.setWebLifecycleState',{'state':'active'})
            page.evaluate('async()=>{for(let i=0;i<4;i++)await new Promise(requestAnimationFrame)}')
            after=wait_saved(lambda s:abs(s.get('time',-1)-before['time'])<.001)
            assert before['money']==after['money'] and before['patients']==after['patients'],'Pause/background advanced patient or paid twice'
            page.reload()
            page.wait_for_function('window.sunshineControls?.pause',timeout=int(args.save_timeout*1000))
            restored=wait_saved(lambda s:abs(s.get('time',-1)-after['time'])<.001)
            assert page.evaluate('window.sunshineControls._state.paused'),'Reload automatically unpaused user'
            assert restored['money']==after['money'] and restored['daily_ledger']==after['daily_ledger'] and restored['patients']==after['patients'],'Real browser reload changed saved operations'
            preflight={'layouts':layouts,'freeze_resume_while_user_paused':True,'actual_page_reload':True,'indexeddb_restored':True,'physical_phone':False}
        (output/'console.log').write_text('\n'.join(messages))
        assert not any('SCRIPT ERROR' in m or m.startswith('pageerror:') for m in messages), 'Browser runtime error'
        report={'passed':True,'browser':'Chromium touch emulation' if args.touch else 'Chromium desktop / SwiftShader','fullscreen_canvas':True,'actual_canvas_admission':True,'patient_state':state['patients'][0]['state'],'indexeddb_save':True,'first_day_story_saved':True,'daily_ledger_saved':True,'story_stage':story['stage'],'mobile_tested':False,'wasm_engine_start_wall_seconds':loader_done_seconds,'first_arrived_and_persisted_wall_seconds':initial_seconds,'viewport':[width,height],'device_pixel_ratio':args.dpr,'url_kind':'provided URL' if args.url else 'loopback only','godot':'4.6.3','renderer':'Chromium SwiftShader WebGL2'}
        report['preflight']=preflight
        (output/'results.json').write_text(json.dumps(report,indent=2))
        print(json.dumps(report))
        browser.close()
finally:
    server.shutdown(); server.server_close()
