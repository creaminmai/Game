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
parser.add_argument('--staff',action='store_true',help='Load a normally operated day-two fixture into this private profile, then test actual delegation input/reload')
parser.add_argument('--research',action='store_true',help='Lab transaction, operating-day application and reload from normal checkpoints')
parser.add_argument('--operations',action='store_true',help='Training purchase, explicit duties, real delegated command and saved provenance')
parser.add_argument('--chapter',action='store_true',help='Actual 11-to-12 departure, chapter journal and browser reload from a normal simulation checkpoint')
parser.add_argument('--debug-captures',action='store_true',help='Also capture each intermediate UI state')
parser.add_argument('--save-timeout',type=float,default=300,help='Wall-clock allowance per saved-state wait; software WebGL may render far below real time')
args=parser.parse_args()
if sum([args.staff,args.chapter,args.operations,args.research]) > 1: parser.error('Choose one progression scenario')
if args.save_timeout <= 0: parser.error('--save-timeout must be positive')
repo = Path(__file__).resolve().parents[1]
output = repo / ('artifacts/browser-staff-touch' if args.staff and args.touch else ('artifacts/browser-touch' if args.touch else 'artifacts/browser'))
if args.chapter: output=repo/('artifacts/browser-chapter-touch' if args.touch else 'artifacts/browser-chapter')
if args.research: output=repo/('artifacts/browser-research-touch' if args.touch else 'artifacts/browser-research')
if args.operations: output=repo/('artifacts/browser-operations-touch' if args.touch else 'artifacts/browser-operations')
output.mkdir(parents=True, exist_ok=True)
(output/'results.json').unlink(missing_ok=True)
class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
server = ThreadingHTTPServer(('127.0.0.1',0),partial(QuietHandler,directory=str(repo/'artifacts/web')))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader'])
        width,height=(844,350) if (args.staff or args.chapter or args.operations or args.research) and args.touch else ((844,390) if args.touch else (1280,720))
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
        assert ledger=={'version':2,'opening_money':900,'income':0,'expansion_expense':0,'new_annex':False,'training_expense':0}, 'Actual opening/day receipts were not saved correctly'
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
        staff={}
        chapter={}
        operations={}
        research={}
        if args.staff or args.chapter or args.operations or args.research:
            # This is a fresh test-only browser profile, never player storage.
            # Leave the running engine before replacing the fixture so it cannot
            # race the write. Operational state comes from normal day-one commands.
            fixture_path='artifacts/chapter-rehearsal-completion/checkpoint.json' if args.chapter else 'artifacts/staff-video-offer/checkpoint.json'
            if args.operations: fixture_path='artifacts/operations-web-checkpoints/education.json'
            if args.research: fixture_path='artifacts/research-web-checkpoints/construction.json'
            fixture=json.loads((repo/fixture_path).read_text())
            if args.staff:
                fixture['staff_admission']['offer_seen']=False
                fixture['first_day_story']=state['first_day_story']
            from urllib.parse import urljoin
            def load_checkpoint(data):
                page.goto(urljoin(base,'LICENSE-Godot.txt'))
                replaced=page.evaluate('''async data => {
                  let replaced=0;
                  for(const info of await indexedDB.databases()) {
                    const db=await new Promise((ok,no)=>{const r=indexedDB.open(info.name);r.onsuccess=()=>ok(r.result);r.onerror=()=>no(r.error)});
                    for(const name of db.objectStoreNames) {
                      const rows=await new Promise((ok,no)=>{const t=db.transaction(name),s=t.objectStore(name),k=s.getAllKeys(),v=s.getAll();t.oncomplete=()=>ok([k.result,v.result]);t.onerror=()=>no(t.error)});
                      for(let i=0;i<rows[0].length;i++) {
                        let parsed;try{parsed=JSON.parse(new TextDecoder().decode(rows[1][i].contents))}catch{continue}
                        if(parsed.implementation!=='sunshine-rebuild-2026-11')continue;
                        const value=rows[1][i];value.contents=new TextEncoder().encode(JSON.stringify(data));value.timestamp=new Date();
                        await new Promise((ok,no)=>{const t=db.transaction(name,'readwrite');t.objectStore(name).put(value,rows[0][i]);t.oncomplete=ok;t.onerror=()=>no(t.error)});replaced++;
                      }
                    }db.close();
                  }return replaced;
                }''',data)
                assert replaced==1, replaced
                page.goto(base+('&' if '?' in base else '?')+'playtest=1')
                page.wait_for_function('window.sunshineControls?.pause',timeout=int(args.save_timeout*1000))
            load_checkpoint(fixture)
            if args.research:
                assert page.evaluate('window.sunshineControls._state.day')==5
                press('research');press('lab_build')
                page.screenshot(timeout=120000,scale='css',path=str(output/'844x350-lab-offer.png'))
                press('research_cancel')
                cancelled=wait_saved(lambda s:s['day']==5)
                assert cancelled['money']==3000 and cancelled['research_lab']['built_day']==0
                press('lab_build');press('research_confirm')
                built=wait_saved(lambda s:s['research_lab']['built_day']==5)
                assert built['money']==1200 and built['research_lab']['points']==6
                # Real native-browser touch gesture on the Godot scroll area.
                scroll=page.evaluate('window.sunshineControls.research_scroll')
                session=page.context.new_cdp_session(page)
                x=scroll['x'];y=scroll['y']+scroll['height']*.3
                session.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':x,'y':y}]})
                for n in range(1,9):
                    session.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'x':x,'y':y-scroll['height']*.6*n/8}]})
                    page.wait_for_timeout(50)
                session.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
                page.evaluate('async()=>{for(let i=0;i<12;i++)await new Promise(requestAnimationFrame)}')
                press('research_ct')
                page.screenshot(timeout=120000,scale='css',path=str(output/'844x350-research-start.png'))
                press('research_confirm')
                started_project=wait_saved(lambda s:'ct' in s['research_lab']['projects'])
                assert started_project['money']==700 and started_project['research_lab']['points']==0
                assert started_project['daily_ledger']['lab_expense']==1800 and started_project['daily_ledger']['research_expense']==500
                press('research_return')
                assert page.evaluate('window.sunshineControls._state.paused'), 'Exterior return must retain restore pause'
                load_checkpoint(json.loads((repo/'artifacts/research-web-checkpoints/pending.json').read_text()))
                pending=wait_saved(lambda s:s['day']==6)
                assert pending['research_lab']['projects']['ct']['completed_day']==6 and pending['research_lab']['chapter_four_day']==0
                press('journal_next')
                applied=wait_saved(lambda s:s['day']==7)
                assert applied['research_lab']['projects']['ct']['applied_day']==7 and applied['research_lab']['chapter_four_day']==7
                assert applied['money']==2300 and applied['research_lab']['points']==8
                load_checkpoint(json.loads((repo/'artifacts/research-web-checkpoints/active.json').read_text()))
                press('patients');press('first_patient')
                active=wait_saved(lambda s:s['day']==7 and s['patients'][0]['state']=='ct_scan')
                assert active['patients'][0]['service_duration']==4
                page.screenshot(timeout=120000,scale='css',path=str(output/'844x350-applied-ct.png'))
                page.reload();page.wait_for_function('window.sunshineControls?.pause',timeout=int(args.save_timeout*1000))
                restored=wait_saved(lambda s:s['day']==7 and s['patients'][0]['state']=='ct_scan')
                for key in ['patients','research_lab','operations_training','chapter_progress','daily_ledger','staff_admission','money']:
                    assert restored[key]==active[key],key
                assert page.evaluate('window.sunshineControls._state.paused')
                press('research')
                page.screenshot(timeout=120000,scale='css',path=str(output/'844x350-restored-research.png'))
                research={'passed':True,'normal_checkpoint_count':3,'normal_simulation_checkpoints':True,'touch_scroll_and_canvas_buttons':True,'construction_cancelled':True,'actual_construction_once':True,'six_point_initial_grant_once':True,'actual_project_cost_once':True,'actual_next_day_application':True,'active_ct_duration_four':True,'actual_page_reload':True,'no_duplicate_receipts':True,'continuous_web_playthrough':False,'physical_phone':False}
            elif args.operations:
                page.wait_for_function('window.sunshineControls?.pause',timeout=int(args.save_timeout*1000))
                assert page.evaluate('window.sunshineControls._state.day')==4
                assert page.evaluate('window.sunshineControls._state.paused')
                # User pause stays in force while reading and buying education.
                press('settings');press('training')
                page.screenshot(timeout=120000,scale='css',path=str(output/'844x350-training-offer.png'))
                press('training_cancel')
                cancelled=wait_saved(lambda s:s['day']==4)
                assert cancelled['money']==2700 and not cancelled['operations_training']['trained']
                press('training');press('training_buy')
                purchased=wait_saved(lambda s:s['operations_training']['trained'])
                assert purchased['money']==2200 and purchased['daily_ledger']['training_expense']==500
                assert not purchased['operations_training']['enabled']
                press('planning_toggle');press('admission_toggle')
                page.screenshot(timeout=120000,scale='css',path=str(output/'844x350-work-management.png'))
                press('guide_close');press('pause')
                admitted=wait_saved(lambda s:s['patients'][0].get('admission_source')=='minji')
                assert admitted['patients'][0]['history'].count('ct_queue')==1
                assert admitted['money']==2200 and admitted['daily_ledger']['training_expense']==500
                # A second explicitly documented checkpoint starts at 2.5/3 s
                # of real preparation. It was produced by normal native commands,
                # not by editing work status or attributing manual work to staff.
                planning_fixture=json.loads((repo/'artifacts/operations-web-checkpoints/planning.json').read_text())
                load_checkpoint(planning_fixture)
                assert page.evaluate('window.sunshineControls._state.paused')
                press('pause')
                assigned=wait_saved(lambda s:any(p.get('plan_source')=='staff' for p in s['patients']))
                first=assigned['patients'][0]
                assert first['admission_source']=='minji' and first['plan_source']=='staff'
                assert first['history'].count('plan_queue')==1 and first['history'].count('ct_queue')==1
                press('patients');press('first_patient');press('pause')
                live=page.evaluate('window.sunshineControls._state')
                saved=wait_saved(lambda s:abs(s['time']-live['time'])<.001)
                page.screenshot(timeout=120000,scale='css',path=str(output/'844x350-automatic-plan.png'))
                page.reload()
                page.wait_for_function('window.sunshineControls?.pause',timeout=int(args.save_timeout*1000))
                restored=wait_saved(lambda s:s['day']==4 and abs(s['time']-saved['time'])<.001)
                for key in ['patients','operations_training','chapter_progress','daily_ledger','staff_admission','money']:
                    assert restored[key]==saved[key],key
                assert page.evaluate('window.sunshineControls._state.paused')
                press('settings')
                page.screenshot(timeout=120000,scale='css',path=str(output/'844x350-restored-duties.png'))
                operations={'passed':True,'normal_simulation_checkpoint':True,'isolated_indexeddb_fixture':True,'purchase_cancelled':True,'actual_purchase_once':True,'purchase_does_not_enable':True,'explicit_duty_toggles':True,'actual_automatic_admission_and_plan':True,'command_provenance_saved':True,'actual_page_reload':True,'normal_checkpoint_count':2,'continuous_web_playthrough':False,'physical_phone':False}
            elif args.chapter:
                page.wait_for_function('window.sunshineControls?.pause',timeout=int(args.save_timeout*1000))
                assert page.evaluate('window.sunshineControls._state.visits')==11
                assert page.evaluate('window.sunshineControls._state.chapter_two_day')==0
                assert page.evaluate('window.sunshineControls._state.paused')
                press('pause')
                complete=wait_saved(lambda s:s['chapter_progress']['chapter_two_day']==3 and 2 in s['chapter_progress']['presented'])
                assert complete['chapter_progress']['archived_visits']==8 and len(complete['chapter_progress']['visits'])==4
                assert complete['money']==2700 and complete['daily_ledger']['income']==800 and complete['daily_ledger']['expansion_expense']==0
                page.screenshot(timeout=120000,scale='css',path=str(output/'chapter-completed-journal.png'))
                press('journal_close');press('chapter_goal')
                page.screenshot(timeout=120000,scale='css',path=str(output/'chapter-completed-goals.png'))
                press('chapter_close');press('journal_open');press('journal_next')
                day4=wait_saved(lambda s:s['day']==4)
                assert day4['money']==2700 and day4['daily_ledger']['income']==0 and day4['daily_ledger']['expansion_expense']==0
                assert day4['chapter_progress']['archived_visits']==12 and not day4['chapter_progress']['visits']
                press('pause')
                live=page.evaluate('window.sunshineControls._state')
                saved=wait_saved(lambda s:s['day']==4 and abs(s['time']-live['time'])<.001)
                page.reload()
                page.wait_for_function('window.sunshineControls?.pause',timeout=int(args.save_timeout*1000))
                restored=wait_saved(lambda s:s['day']==4 and abs(s['time']-saved['time'])<.001)
                for key in ['patients','chapter_progress','daily_ledger','staff_admission','money']:
                    assert restored[key]==saved[key],key
                assert page.evaluate('window.sunshineControls._state.paused')
                press('chapter_goal')
                page.screenshot(timeout=120000,scale='css',path=str(output/'chapter-day-four-restored.png'))
                chapter={'passed':True,'normal_simulation_checkpoint':True,'isolated_indexeddb_fixture':True,'actual_departure_11_to_12':True,'journal_stamp':True,'next_day_retains_cumulative':True,'real_page_reload':True,'no_duplicate_receipts':True,'physical_phone':False}
            else:
                page.wait_for_function('window.sunshineControls?.admission_accept.visible',timeout=int(args.save_timeout*1000))
                assert page.evaluate('window.sunshineControls._state.day')==2
                page.screenshot(timeout=120000,scale='css',path=str(output/'844x350-offer.png'))
                press('admission_accept');press('pause')
                admitted_state=wait_saved(lambda s:s['day']==2 and s['staff_admission']['enabled'] and s['patients'][0]['state'] not in ['waiting','entering'])
                assert admitted_state['patients'][0]['history'].count('ct_queue')==1
                press('settings')
                page.screenshot(timeout=120000,scale='css',path=str(output/'844x350-settings.png'))
                press('admission_toggle');press('guide_close');press('pause')
                page.wait_for_function('window.sunshineControls._state.paused')
                live=page.evaluate('window.sunshineControls._state')
                saved=wait_saved(lambda s:not s['staff_admission']['enabled'] and abs(s['time']-live['time'])<.001)
                page.reload()
                page.wait_for_function('window.sunshineControls?.pause',timeout=int(args.save_timeout*1000))
                restored=wait_saved(lambda s:s['day']==2 and not s['staff_admission']['enabled'] and abs(s['time']-saved['time'])<.001)
                assert page.evaluate('window.sunshineControls._state.paused')
                assert restored['patients']==saved['patients'] and restored['daily_ledger']==saved['daily_ledger'] and restored['money']==saved['money']
                assert not page.evaluate('window.sunshineControls.admission_accept.visible')
                page.screenshot(timeout=120000,scale='css',path=str(output/'844x350-restored.png'))
                staff={'passed':True,'normal_simulation_checkpoint':True,'isolated_indexeddb_fixture':True,'accepted_via_canvas':True,'automatic_admission_once':True,'disabled_via_canvas':True,'real_page_reload':True,'disabled_setting_and_patients_restored':True,'physical_phone':False}
        (output/'console.log').write_text('\n'.join(messages))
        assert not any('SCRIPT ERROR' in m or m.startswith('pageerror:') for m in messages), 'Browser runtime error'
        report={'passed':True,'browser':'Chromium touch emulation' if args.touch else 'Chromium desktop / SwiftShader','fullscreen_canvas':True,'actual_canvas_admission':True,'patient_state':state['patients'][0]['state'],'indexeddb_save':True,'first_day_story_saved':True,'daily_ledger_saved':True,'story_stage':story['stage'],'mobile_tested':False,'wasm_engine_start_wall_seconds':loader_done_seconds,'first_arrived_and_persisted_wall_seconds':initial_seconds,'viewport':[width,height],'device_pixel_ratio':args.dpr,'url_kind':'provided URL' if args.url else 'loopback only','godot':'4.6.3','renderer':'Chromium SwiftShader WebGL2'}
        report['preflight']=preflight
        report['staff']=staff
        report['chapter']=chapter
        report['operations']=operations
        report['research']=research
        (output/'results.json').write_text(json.dumps(report,indent=2))
        print(json.dumps(report))
        browser.close()
finally:
    server.shutdown(); server.server_close()
