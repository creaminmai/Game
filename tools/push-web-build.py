#!/usr/bin/env python3
"""Store a built site in gh-pages without switching branches or creating a worktree.
This does NOT enable GitHub Pages. Access to repo Pages settings is a separate prerequisite.
"""
import json, os, subprocess, tempfile
from pathlib import Path
repo = Path(__file__).resolve().parents[1]
site = repo / 'artifacts/web'
if not (site/'index.wasm').is_file(): raise SystemExit('Run export-game.py Web first')
def git(*args, **kwargs):
    return subprocess.check_output(['git','-C',str(repo),*args],text=True,**kwargs).strip()
source = git('rev-parse','HEAD')
(site/'.nojekyll').touch()
(site/'build.json').write_text(json.dumps({'source_commit':source,'engine':'Godot 4.6.3','target':'Web single-threaded','mobile_safari_verified':False},indent=2))
existing = git('ls-remote','origin','refs/heads/gh-pages')
parent=[]
if existing:
    git('fetch','origin','refs/heads/gh-pages')
    parent=['-p',git('rev-parse','FETCH_HEAD')]
with tempfile.TemporaryDirectory(prefix='web-index-',dir=repo/'.runtime') as folder:
    env=os.environ.copy()
    env['GIT_INDEX_FILE']=str(Path(folder)/'index')
    args=['git','--git-dir',str(repo/'.git'),'--work-tree',str(site)]
    subprocess.run(args+['read-tree','--empty'],env=env,check=True)
    subprocess.run(args+['add','-A','.'],cwd=site,env=env,check=True)
    tree=subprocess.check_output(args+['write-tree'],env=env,text=True).strip()
    commit=git('commit-tree',tree,*parent,'-m',f'Prepare playable web build from {source[:7]}')
    git('push','origin',f'{commit}:refs/heads/gh-pages')
    remote=git('ls-remote','origin','refs/heads/gh-pages').split()[0]
    assert remote==commit, 'Remote web branch does not match'
    print(json.dumps({'web_branch_commit':commit,'source_commit':source,'pages_publication_verified':False}))
