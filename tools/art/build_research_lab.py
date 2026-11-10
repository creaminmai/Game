"""Editable, original laboratory kit using the existing Blender mesh/material helpers.
No render-card substitutes; Standard glTF PBR, bevels and weighted normals baked
into geometry. Run: blender -b --factory-startup -t 2 --python tools/art/build_research_lab.py
"""
import ast,sys,math,json
from pathlib import Path
import bpy,bmesh
from mathutils import Vector,Matrix
from math import sin,cos,pi
ROOT=Path(__file__).resolve().parents[2]
# Import the established authoring primitives without regenerating old assets.
source=ROOT/'tools/art/build_assets.py'
tree=ast.parse(source.read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),str(source),'exec'))
bpy.context.preferences.filepaths.save_version=0
clear()
M={key:mat(key,color,rough) for key,color,rough in [
 ('Lab cream','f4ece2',.42),('Lab teal','78aaa2',.37),('Lab pale mint','c7dcd5',.5),
 ('Lab honey wood','d9b48a',.48),('Lab window','a9d1ce',.24),('Lab paper','f9f4e9',.72),
 ('Lab screen','345e63',.34),('Lab leaves','99b877',.65),('Lab coral','e8a08b',.76),('Lab gold','ddbb74',.42)]}
a=lambda k:M['Lab '+k]
box('Foundation',(0,.07,0),(5.35,.18,4.7),a('cream'),.12)
box('Plinth',(0,.24,0),(5.05,.24,4.45),a('pale mint'),.08)
box('Floor',(0,.39,0),(4.9,.12,4.3),a('honey wood'),.06)
# Low front facade reveals the record desk; raised rear walls and a shallow roof.
box('Rear wall',(0,1.76,-1.97),(4.9,2.7,.22),a('cream'),.08)
for side in [-1,1]:
 box('Side wall',(side*2.35,1.42,0),(.2,2.1,4.0),a('cream'),.06)
 for z in [-1.1,.25,1.35]:
  box('Side glass',(side*2.47,1.65,z),(.035,1.25,.86),a('window'),.035)
  for zz in [z-.49,z+.49]: box('Window jamb',(side*2.49,1.65,zz),(.07,1.4,.055),a('honey wood'),.016)
  for yy in [.96,2.34]:box('Window sill',(side*2.49,yy,z),(.1,.06,1.05),a('cream'),.02)
box('Roof trim',(0,3.12,-.85),(5.3,.16,2.55),a('cream'),.08)
box('Teal roof',(0,3.25,-.85),(5.48,.19,2.7),a('teal'),.09)
for x in [-2,-1,0,1,2]:box('Shallow roof seam',(x,3.35,-.85),(.025,.018,2.52),a('pale mint'),.006)
# Lab sign: a rounded plaque and an actual mesh flask/record emblem.
box('Sign plaque',(0,2.67,.24),(2.6,.65,.13),a('paper'),.14)
lathe('Record emblem flask',(-.9,2.4,.35),[(0,.19),(.05,.22),(.25,.08),(.39,.08)],a('teal'),32)
box('Record emblem pages',(-.42,2.68,.35),(.23,.3,.04),a('honey wood'),.02)
for side in [-1,1]:
 box('Front post',(side*2.15,1.62,1.8),(.16,2.45,.16),a('honey wood'),.035)
box('Front low wall',(-1.25,.76,1.89),(1.95,.7,.18),a('cream'),.07)
box('Front glazing',(-1.25,1.43,1.92),(1.82,.68,.04),a('window'),.03)
for x in [-2.17,-1.25,-.33]:box('Front window frame',(x,1.43,1.96),(.055,.8,.06),a('honey wood'),.012)
box('Work desk',(-.4,1.3,.6),(2.75,.15,.86),a('honey wood'),.07)
for x in [-1.55,.73]:box('Desk support',(x,.85,.55),(.16,.85,.58),a('cream'),.035)
box('Monitor stand',(-.8,1.48,.32),(.2,.24,.17),a('teal'),.03)
box('Monitor rim',(-.8,1.81,.34),(.83,.58,.12),a('cream'),.055)
box('Monitor display',(-.8,1.81,.416),(.72,.47,.018),a('screen'),.025)
for i in range(3):box('Data bars',(-1.02+i*.19,1.75+i*.05,.431),(.1,.18+i*.08,.01),a('pale mint'),.009)
for n in range(3):box('Record folder',(.18+n*.15,1.42+n*.035,.58),(.49,.045,.53),a('coral') if n==1 else a('paper'),.02)
box('Record shelf',(1.58,1.45,-1.55),(.95,1.9,.43),a('honey wood'),.05)
for y in [.65,1.25,1.85,2.35]:box('Shelf ledge',(1.58,y,-1.26),(1.03,.07,.55),a('cream'),.02)
for row in range(3):
 for i in range(4):box('Record binder',(1.25+i*.2,.92+row*.57,-1.22),(.14,.43,.28),a('pale mint') if i%2 else a('paper'),.015)
for x,z in [(-2.05,1.15),(2.15,1.75)]:
 lathe('Planter',(x,.45,z),[(0,.2),(.4,.24),(.43,.25)],a('cream'))
 for i in range(6):
  angle=i*pi/3
  oval('Rounded leaf',(x+cos(angle)*.18,1.03+(i%2)*.15,z+sin(angle)*.16),(.27,.43,.19),a('leaves'))
box('Entrance step',(1.0,.16,2.48),(1.7,.24,.52),a('cream'),.07)
scene=bpy.context.scene;scene.view_settings.view_transform='Standard'
scene.view_settings.look='None';scene.view_settings.exposure=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/source/research-lab.blend'),compress=True)
# Batch static pieces by material for modest draw cost while source retains parts.
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active=next(o for o in scene.objects if o.type=='MESH')
bpy.ops.object.join();obj=bpy.context.object;obj.name='ResearchLab'
for p in obj.data.polygons:
 if p.area>.02 and max(abs(v) for v in p.normal)>.9995:p.use_smooth=False
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models/research-lab.glb'),export_format='GLB',export_yup=True,export_apply=True)
report={'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'materials':len({p.material_index for p in obj.data.polygons}),'textures':0,'model':'research-lab','source':'art/source/research-lab.blend'}
# Dedicated research employee, using the existing articulated character contract.
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/nurse.blend'))
for m in bpy.data.materials:
 if m.use_nodes and (m.name.lower().startswith('outfit') or m.name.lower().startswith('hair')):
  bs=m.node_tree.nodes.get('Principled BSDF')
  if bs:bs.inputs['Base Color'].default_value=rgb('eee6da' if m.name.lower().startswith('outfit') else '604c43')
# Preserve original character articulation, clean face, and contact colors.
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/source/researcher.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models/researcher.glb'),export_format='GLB',export_yup=True,export_apply=True,export_vertex_color='ACTIVE',export_all_vertex_colors=False)
(ROOT/'godot/assets/models/research-asset-report.json').write_text(json.dumps(report,indent=2)+'\n')
print('RESEARCH_ASSETS',report,flush=True)
