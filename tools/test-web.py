#!/usr/bin/env python3
"""Open the exported Godot build, perform actual canvas input, and verify its saved simulation state."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json, threading, argparse, time
from playwright.sync_api import sync_playwright
parser=argparse.ArgumentParser()
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
        page = browser.new_page(viewport={'width':width,'height':height},has_touch=args.touch,is_mobile=args.touch)
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
                (output/'last-save-state.json').write_text(json.dumps(states,indent=2))
                for state in states:
                    if predicate(state): return state
                page.wait_for_timeout(1000)
            (output/'failed-save-state.json').write_text(json.dumps(page.evaluate(read_saves),indent=2))
            raise AssertionError('Expected simulation state was not persisted to IndexedDB; see console.log and failed-save-state.json')
        page.goto(f'http://127.0.0.1:{server.server_port}/index.html')
        page.wait_for_function("!document.querySelector('#status') || document.querySelector('#status').style.display === 'none'",timeout=60000)
        # Software WebGL startup varies; require an arrived patient in this
        # fresh browser's persisted simulation before attempting admission.
        wait_saved(lambda state: state.get('patients') and state['patients'][0]['state']=='waiting')
        print('WEB: first patient arrived and saved',flush=True)
        if args.debug_captures: page.screenshot(timeout=120000,path=str(output/'before-admission.png'))
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
            page.evaluate('async () => { for (let i=0;i<3;i++) await new Promise(requestAnimationFrame); }')
        # Godot expands the logical viewport instead of adding portrait letterboxing.
        scale=min(canvas['width']/960,canvas['height']/540)
        logical_w,logical_h=canvas['width']/scale,canvas['height']/scale
        ox,oy=canvas['x'],canvas['y']
        click(ox+(logical_w*.5-55)*scale,oy+(logical_h-59)*scale) # Patient roster in the centered dock.
        if args.debug_captures: page.screenshot(timeout=120000,path=str(output/'patient-roster.png'))
        click(ox+(logical_w-190)*scale,oy+190*scale) # First arrived patient in the roster.
        if args.debug_captures: page.screenshot(timeout=120000,path=str(output/'patient-selected.png'))
        click(ox+(logical_w-133)*scale,oy+371*scale) # Contextual admission action, verified in native UI QA.
        # Inspect this fresh test browser's own IndexedDB filesystem, never the user's profile.
        # IDBFS synchronizes asynchronously. Wait for evidence of the action in persistent storage.
        state=wait_saved(lambda state: state.get('patients') and state['patients'][0]['state'] not in ['waiting','entering'])
        story=state.get('first_day_story',{})
        ledger=state.get('daily_ledger',{})
        assert ledger=={'version':1,'opening_money':900,'income':0,'expansion_expense':0,'new_annex':False}, 'Actual opening/day receipts were not saved correctly'
        assert story.get('version')==1 and story.get('seen',{}).get('admission'), 'State-driven tutorial was not saved after actual admission'
        page.screenshot(timeout=120000,path=str(output/'after-admission.png'))
        (output/'console.log').write_text('\n'.join(messages))
        assert not any('SCRIPT ERROR' in m or m.startswith('pageerror:') for m in messages), 'Browser runtime error'
        report={'passed':True,'browser':'Chromium touch emulation' if args.touch else 'Chromium desktop / SwiftShader','fullscreen_canvas':True,'actual_canvas_admission':True,'patient_state':state['patients'][0]['state'],'indexeddb_save':True,'first_day_story_saved':True,'daily_ledger_saved':True,'story_stage':story['stage'],'mobile_tested':False}
        (output/'results.json').write_text(json.dumps(report,indent=2))
        print(json.dumps(report))
        browser.close()
finally:
    server.shutdown(); server.server_close()
