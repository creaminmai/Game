#!/usr/bin/env python3
"""Open the exported Godot build, perform actual canvas input, and verify its saved simulation state."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json, threading, argparse
from playwright.sync_api import sync_playwright
parser=argparse.ArgumentParser()
parser.add_argument('--touch',action='store_true')
args=parser.parse_args()
repo = Path(__file__).resolve().parents[1]
output = repo / ('artifacts/browser-touch' if args.touch else 'artifacts/browser')
output.mkdir(parents=True, exist_ok=True)
class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
server = ThreadingHTTPServer(('127.0.0.1',0),partial(QuietHandler,directory=str(repo/'artifacts/web')))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
        width,height=(844,390) if args.touch else (1280,720)
        page = browser.new_page(viewport={'width':width,'height':height},has_touch=args.touch,is_mobile=args.touch)
        messages=[]
        page.on('console',lambda m: messages.append(m.type+': '+m.text))
        page.on('pageerror',lambda e: messages.append('pageerror: '+str(e)))
        page.goto(f'http://127.0.0.1:{server.server_port}/index.html')
        page.wait_for_function("!document.querySelector('#status') || document.querySelector('#status').style.display === 'none'",timeout=60000)
        page.wait_for_timeout(22000)
        page.screenshot(path=str(output/'before-admission.png'))
        canvas=page.locator('#canvas').bounding_box()
        assert canvas, 'Game canvas missing'
        assert abs(canvas['width']-width)<1 and abs(canvas['height']-height)<1, 'Game does not fill browser viewport'
        def click(x,y):
            if args.touch: page.touchscreen.tap(x,y)
            else: page.mouse.click(x,y,delay=100)
            # Software WebGL may render slowly; let the new UI receive a frame before the next action.
            page.wait_for_timeout(2000)
        # Godot expands the logical viewport instead of adding portrait letterboxing.
        scale=min(canvas['width']/960,canvas['height']/540)
        logical_w,logical_h=canvas['width']/scale,canvas['height']/scale
        ox,oy=canvas['x'],canvas['y']
        click(ox+(logical_w-291)*scale,oy+(logical_h-71)*scale) # Patient roster HUD icon.
        page.screenshot(path=str(output/'patient-roster.png'))
        click(ox+(logical_w-254)*scale,oy+(logical_h-356)*scale)
        page.screenshot(path=str(output/'patient-selected.png'))
        click(ox+(logical_w-252)*scale,oy+(logical_h-161)*scale) # Contextual admission action.
        page.wait_for_timeout(3000)
        page.screenshot(path=str(output/'after-admission.png'))
        # Inspect this fresh test browser's own IndexedDB filesystem, never the user's profile.
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
        (output/'console.log').write_text('\n'.join(messages))
        # IDBFS synchronizes asynchronously. Wait for evidence of the action in persistent storage.
        saved=page.wait_for_function('async () => (await ('+read_saves+')()).find(s => s.patients?.[0] && !["waiting","entering"].includes(s.patients[0].state))',timeout=60000,polling=1000)
        state=saved.json_value()
        assert not any('SCRIPT ERROR' in m or m.startswith('pageerror:') for m in messages), 'Browser runtime error'
        report={'passed':True,'browser':'Chromium touch emulation' if args.touch else 'Chromium desktop / SwiftShader','fullscreen_canvas':True,'actual_canvas_admission':True,'patient_state':state['patients'][0]['state'],'indexeddb_save':True,'mobile_tested':False}
        (output/'results.json').write_text(json.dumps(report,indent=2))
        print(json.dumps(report))
        browser.close()
finally:
    server.shutdown(); server.server_close()
