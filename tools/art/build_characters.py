"""Build original articulated chibi assets, retaining named parts for game poses."""
import sys, math, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_assets import *

def group(name,objects,pivot=(0,0,0)):
    node=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(node); node.location=C(pivot)
    bpy.context.view_layer.update()
    for o in objects:
        world=o.matrix_world.copy(); o.parent=node; o.matrix_world=world
    bpy.context.view_layer.update()
    return node

def hair_cap(staff=False):
    verts=[];faces=[]; rings=18; n=64
    for j in range(rings+1):
        u=j/rings
        for i in range(n):
            t=i*2*pi/n; end=((1.65-.55*cos(t)) if not staff else (1.85-.75*cos(t)))+.14*sin(t*2.4+1.2)*max(0,cos(t))**3
            p=.015+u*end
            verts.append((sin(t)*sin(p)*.455,1.47+cos(p)*.49,cos(t)*sin(p)*.39-.025))
    for j in range(rings):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    mesh('Shaped hair cap',verts,faces,M['hair'])
    highlight=mat('hair highlight','89624c',.75)
    for i in range(11):
        t=-1.4+i*.28
        end=((1.65-.55*cos(t)) if not staff else (1.85-.75*cos(t)))+.14*sin(t*2.4+1.2)*max(0,cos(t))**3
        points=[]
        for j in range(7):
            p=.3+(end-.35)*j/6
            points.append((sin(t)*sin(p)*.46,1.47+cos(p)*.495,cos(t)*sin(p)*.395-.025))
        tube('Combed hair strand',points,.004,highlight)
    if staff:
        oval('Tucked hair bun',(.31,1.55,-.35),(.34,.4,.32),M['hair'])

def character(staff=False):
    clear()
    # Face shape: a fuller cheek region and a gently narrowed chin.
    head=oval('Face',(0,1.39,.02),(.85,.91,.69),M['skin'])
    for v in head.data.vertices:
        height=v.co.z
        if height<0:v.co.x*=1+.12*height/.455
    before=set(scene.objects)
    for side in [-1,1]:
        oval('Ear',(side*.415,1.39,.015),(.13,.21,.12),M['skin'])
        oval('Eye white',(side*.151,1.44,.335),(.175,.2,.043),M['white'])
        oval('Warm iris',(side*.151,1.435,.361),(.099,.139,.031),M['iris'])
        oval('Eye glint',(side*.151-.023,1.47,.38),(.038,.042,.014),M['white'])
        tube('Brow',[(side*.08,1.595,.32),(side*.15,1.62,.325),(side*.22,1.595,.30)],.018,M['hair'])
        blush=oval('Soft cheek',(side*.267,1.31,.279),(.12,.06,.016),M['lip'])
        blush.data.materials[0]=mat('blush '+str(side),'e5af9d',.88)
    oval('Button nose',(0,1.345,.373),(.104,.101,.09),M['skin'])
    tube('Gentle smile',[(-.063,1.25,.338),(0,1.23,.353),(.063,1.25,.338)],.012,M['lip'])
    hair_cap(staff)
    head_group=group('Head',set(scene.objects)-before|{head},(0,1.38,0))
    before=set(scene.objects)
    oval('Tailored shirt',(0,.81,0),(.61,.67,.43),M['outfit'],.7)
    # A defined V collar, pocket and fabric seams break up the plain torso silhouette.
    tube('Left collar',[(-.22,1.045,.13),(-.12,1.08,.21),(0,.94,.224)],.037,M['ivory'])
    tube('Right collar',[(.22,1.045,.13),(.12,1.08,.21),(0,.94,.224)],.037,M['ivory'])
    box('Shirt pocket',(.15,.83,.21),(.14,.14,.018),M['outfit'],.015)
    tube('Pocket seam',[(.085,.88,.225),(.215,.88,.225)],.008,M['ivory'])
    if staff:
        box('Name badge',(-.15,.87,.22),(.13,.17,.018),M['ivory'],.015)
        box('Badge clip',(-.15,.96,.224),(.06,.035,.02),M['gold'],.01)
    group('Torso',set(scene.objects)-before)
    for side,suffix in [(-1,'L'),(1,'R')]:
        before=set(scene.objects)
        sleeve=oval('Sleeve',(side*.33,.91,0),(.24,.34,.28),M['outfit'],.7)
        sleeve.rotation_euler.y=side*.18
        oval('Forearm',(side*.38,.65,.02),(.16,.31,.17),M['skin'])
        oval('Hand',(side*.38,.48,.045),(.17,.17,.15),M['skin'])
        oval('Thumb',(side*.31,.495,.09),(.07,.095,.08),M['skin'])
        group('Arm_'+suffix,set(scene.objects)-before,(side*.28,1.02,0))
        before=set(scene.objects)
        oval('Trouser leg',(side*.145,.31,0),(.235,.49,.27),M['trousers'],.55)
        oval('Shoe',(side*.145,.09,.105),(.26,.19,.4),M['ivory'],.5)
        extrusion('Shoe sole',(side*.145,.035,.1),.27,.41,.045,.1,M['sole'])
        tube('Shoe stitching',[(side*.145-.08,.13,.2),(side*.145,.15,.23),(side*.145+.08,.13,.2)],.009,M['linen'])
        group('Leg_'+suffix,set(scene.objects)-before,(side*.145,.53,0))
    before=set(scene.objects)
    for side in [-1,1]:
        oval('Seated thigh',(side*.145,.57,.17),(.24,.23,.5),M['trousers'],.55)
        oval('Seated shin',(side*.145,.32,.37),(.22,.41,.24),M['trousers'],.55)
        oval('Seated shoe',(side*.145,.1,.47),(.26,.19,.4),M['ivory'],.5)
        extrusion('Seated sole',(side*.145,.035,.47),.27,.41,.045,.1,M['sole'])
    group('SeatedLegs',set(scene.objects)-before)
    before=set(scene.objects)
    for side in [-1,1]:
        box('Book cover',(side*.125,.685,.49),(.25,.035,.29),M['book'],.008)
        page=box('Open pages',(side*.125,.71,.49),(.235,.025,.27),M['ivory'],.005)
        page.rotation_euler.y=side*.13
        for row in range(4): box('Printed text',(side*.125,.727,.41+row*.045),(.15,.002,.007),M['cream'],0)
    group('Book',set(scene.objects)-before)
    before=set(scene.objects)
    for side in [-1,1]:
        tube('Spectacle rim',[(side*.153+cos(t)*.115,1.435+sin(t)*.124,.389) for t in [i*2*pi/32 for i in range(32)]],.012,M['gold'],True)
        tube('Spectacle temple',[(side*.27,1.45,.38),(side*.39,1.46,.2),(side*.41,1.43,.01)],.011,M['gold'])
    tube('Spectacle bridge',[(-.04,1.45,.39),(0,1.47,.397),(.04,1.45,.39)],.01,M['gold'])
    glasses=group('Glasses',set(scene.objects)-before,(0,1.38,0))
    world=glasses.matrix_world.copy(); glasses.parent=head_group; glasses.matrix_world=world
    bpy.context.view_layer.update()

def export_character(name):
    # Preserve pivots and disconnected parts. AO is baked per vertex to avoid
    # overlapping UVs on parts that need to remain independently animated.
    # Merge the many sculpted details per movable part, keeping independent
    # poses/accessories while avoiding a draw submission for every eye or key.
    for o in scene.objects:
        if o.type=='MESH': simple_uv(o)
    for parent in [o for o in scene.objects if o.type=='EMPTY']:
        parts=[o for o in parent.children if o.type=='MESH']
        if not parts: continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts: o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join()
        bpy.context.object.name=parent.name+' mesh'
    meshes=[o for o in scene.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        simple_uv(o)
        o.data.color_attributes.new(name='ContactShade',type='FLOAT_COLOR',domain='CORNER')
        o.data.color_attributes.active_color=o.data.color_attributes['ContactShade']
        o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    scene.render.bake.target='VERTEX_COLORS'; scene.cycles.samples=16
    bpy.ops.object.bake(type='AO')
    # glTF stores COLOR_0 as a multiplier; lift excessive crevice darkness.
    for o in meshes:
        attr=o.data.color_attributes['ContactShade']
        for c in attr.data:
            ao=.52+.48*max(0,min(1,c.color[0])); c.color=(ao,ao,ao,1)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.file.pack_all(); bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_vertex_color='ACTIVE',export_all_vertex_colors=False)
    print('CHARACTER_REPORT',name,sum(len(o.data.vertices) for o in meshes),flush=True)

character(False); export_character('patient')
character(True); export_character('nurse')
print('CHARACTERS COMPLETE',flush=True)
