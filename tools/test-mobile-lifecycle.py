#!/usr/bin/env python3
"""Separate process relaunches and isolated saves; never reset player progress."""
import json, os, subprocess, tempfile
from pathlib import Path
repo = Path(__file__).resolve().parents[1]
output = repo/'artifacts/mobile-lifecycle'
output.mkdir(parents=True,exist_ok=True)
isolated = Path(tempfile.mkdtemp(prefix='mobile-lifecycle-',dir=repo/'.runtime'))
reports=[]
for case in ['moving','ct','therapy','user-paused','purchase','journal','day-two','dual','staff-on','staff-off','chapter-before','chapter-after','chapter-day-four','training-purchase','training-preparing','training-assigned','training-departure','training-journal','training-next','research-build','research-progress','research-before-close','research-before-apply','research-applied','research-active-ct','research-next']:
    env=os.environ.copy()
    env.update(XDG_DATA_HOME=str(isolated/case),XDG_CACHE_HOME=str(repo/'.runtime/cache'),XDG_CONFIG_HOME=str(repo/'.runtime/config'))
    for mode in ['prepare','restore']:
        cmd=['godot','--headless','--path',str(repo/'godot'),'--script','tests/test_mobile_lifecycle.gd','--',f'--case={case}',f'--mode={mode}',f'--output-dir={output}']
        result=subprocess.run(cmd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=60)
        (output/f'{case}-{mode}.log').write_text(result.stdout)
        if result.returncode or 'ERROR:' in result.stdout:
            raise SystemExit(result.stdout)
        report=json.loads((output/f'{case}-{mode}.json').read_text())
        assert report['passed'], report
        reports.append(report)
report={'passed':True,'checks':sum(x['checks'] for x in reports),'process_launches':len(reports),'isolated_save_directory':str(isolated),'cases':reports,'physical_mobile_tested':False}
(output/'results.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='cases'},indent=2))
