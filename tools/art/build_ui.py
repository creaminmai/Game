"""Original vector UI skin: warm ceramic frames and rounded miniature symbols.
These are UI assets, not rendered game-world replacement images.
"""
from pathlib import Path
out=Path(__file__).resolve().parents[2]/'godot/assets/ui'
out.mkdir(exist_ok=True)
def svg(name,body,size=96):
    defs='''<defs>
<linearGradient id="cream" x2="0" y2="1"><stop stop-color="#fffdf1"/><stop offset="1" stop-color="#f6e4c5"/></linearGradient>
<linearGradient id="teal" x2="0" y2="1"><stop stop-color="#73d2b4"/><stop offset="1" stop-color="#299b89"/></linearGradient>
<linearGradient id="gold" x2="0" y2="1"><stop stop-color="#ffe988"/><stop offset="1" stop-color="#edac3c"/></linearGradient>
<linearGradient id="coral" x2="0" y2="1"><stop stop-color="#ffb49a"/><stop offset="1" stop-color="#e58068"/></linearGradient>
</defs>'''
    (out/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 96 96">{defs}{body}</svg>')
for name,fill,stroke in [('panel','cream','#d5b790'),('primary','teal','#3d9886'),('gold-button','gold','#d5a044')]:
    svg(name,f'''<rect x="3" y="7" width="90" height="87" rx="22" fill="#6d5847" opacity=".18"/>
<rect x="2" y="2" width="92" height="88" rx="22" fill="url(#{fill})" stroke="{stroke}" stroke-width="1.5"/>
<rect x="6" y="6" width="84" height="80" rx="18" fill="none" stroke="#fffdf0" stroke-width="1.8" opacity=".72"/>''')
icons={
'outside':'''<rect x="16" y="31" width="64" height="52" rx="8" fill="url(#cream)" stroke="#bc9c76" stroke-width="2"/><path d="M9 35L48 13L87 35Z" fill="url(#teal)" stroke="#448e81" stroke-width="2"/><rect x="41" y="61" width="15" height="22" rx="3" fill="#70bab2"/><path d="M27 45h12v11H27zm30 0h12v11H57z" fill="#9dcfd1"/><circle cx="48" cy="36" r="9" fill="url(#gold)"/><path d="M43 36h10m-5-5v10" stroke="#fff8dc" stroke-width="3"/><circle cx="15" cy="73" r="12" fill="#8fb369"/><circle cx="82" cy="73" r="11" fill="#a3c879"/>''',
'people':'''<rect x="21" y="13" width="57" height="72" rx="10" fill="#b58856"/><rect x="24" y="16" width="51" height="65" rx="8" fill="url(#cream)" stroke="#fff9e9" stroke-width="2"/><rect x="37" y="9" width="25" height="14" rx="5" fill="url(#gold)" stroke="#b88343" stroke-width="2"/><path d="M33 71q0-20 17-20t17 20" fill="url(#teal)"/><circle cx="50" cy="43" r="15" fill="#f5c8a9"/><path d="M35 43q-3-22 16-20q19 3 13 22l-5-12q-13 9-23 0" fill="#79513c"/><path d="M44 47q6 6 12 0" fill="none" stroke="#b26b58" stroke-width="2"/>''',
'build':'''<rect x="18" y="37" width="59" height="46" rx="7" fill="url(#cream)" stroke="#c1a078" stroke-width="2"/><path d="M12 41L46 20l38 21" fill="url(#teal)" stroke="#448e81" stroke-width="3"/><path d="M47 49v23M35 61h24" stroke="#e6ad46" stroke-width="8" stroke-linecap="round"/><circle cx="78" cy="22" r="15" fill="url(#gold)" stroke="#d49b35" stroke-width="2"/><path d="M78 14v16m-8-8h16" stroke="#fff9e1" stroke-width="4" stroke-linecap="round"/>''',
'attention':'''<path d="M29 69q5-8 5-27q0-22 16-22t16 22q0 19 7 27Z" fill="url(#gold)" stroke="#bc893f" stroke-width="2"/><rect x="24" y="66" width="54" height="10" rx="5" fill="url(#gold)" stroke="#bc893f" stroke-width="2"/><circle cx="50" cy="81" r="6" fill="#bc893f"/><path d="M21 27l-6-6m64 6l6-6M50 11V5" stroke="#edb638" stroke-width="5" stroke-linecap="round"/>''',
'coin':'''<path d="M30 15q17 9 36 0l-6 20q30 34 15 47q-27 14-51-1Q9 65 37 35Z" fill="url(#gold)" stroke="#b98236" stroke-width="2"/><path d="M32 35q18 5 33 0" stroke="#9f743b" stroke-width="4" fill="none"/><path d="M42 54q19-9 18 3t-17 7q-2 12 18 5M51 48v29" fill="none" stroke="#fff4c3" stroke-width="4" stroke-linecap="round"/>''',
'sun':'''<circle cx="48" cy="48" r="25" fill="url(#gold)" stroke="#dc9d37" stroke-width="2"/><path d="M48 7v9m0 64v9M7 48h9m64 0h9M19 19l7 7m44 44l7 7M19 77l7-7m44-44l7-7" stroke="#edb03c" stroke-width="6" stroke-linecap="round"/><path d="M37 47h2m18 0h2m-21 9q10 13 20 0" fill="none" stroke="#a77738" stroke-width="3" stroke-linecap="round"/>''',
'ct':'''<rect x="11" y="69" width="74" height="13" rx="6" fill="#b4c5be"/><circle cx="48" cy="43" r="31" fill="url(#cream)" stroke="#c0c9c1" stroke-width="3"/><circle cx="48" cy="43" r="17" fill="#83b8b0" stroke="#d7e4dc" stroke-width="4"/><rect x="38" y="49" width="24" height="36" rx="6" fill="url(#teal)" stroke="#f9f6e8" stroke-width="4"/><rect x="42" y="16" width="12" height="5" rx="2" fill="#7bb5ad"/>''',
'plan':'''<rect x="12" y="14" width="72" height="53" rx="8" fill="#738b88" stroke="#a8bcb2" stroke-width="3"/><rect x="18" y="20" width="60" height="40" rx="4" fill="#284e57"/><ellipse cx="48" cy="40" rx="18" ry="17" fill="#9fbfc0"/><ellipse cx="41" cy="40" rx="6" ry="11" fill="#42676d"/><ellipse cx="56" cy="40" rx="6" ry="11" fill="#42676d"/><path d="M47 68v13m-17 3h36" stroke="#82968e" stroke-width="7" stroke-linecap="round"/>''',
 'treatment':'''<path d="M23 76V44Q23 14 48 14q25 0 25 31v5" fill="none" stroke="#c2ccc4" stroke-width="24" stroke-linecap="round"/><path d="M23 75V43q0-25 25-25q20 0 20 25" fill="none" stroke="#f5eee0" stroke-width="18" stroke-linecap="round"/><rect x="53" y="40" width="27" height="17" rx="6" fill="url(#cream)" stroke="#acc4b6" stroke-width="2"/><rect x="28" y="67" width="55" height="12" rx="6" fill="url(#teal)" stroke="#f7f3e4" stroke-width="3"/><path d="M53 80v8" stroke="#b4c1b6" stroke-width="10"/>'''
}
icons['overview']=icons['outside']
for name,body in icons.items():svg(name,body)
