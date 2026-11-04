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

def face_z(x,y):
    # Surface-following facial inlays avoid floating, protruding eyeballs.
    yy=(y-1.56)/.355
    width=.35*(1+.08*min(0,yy))
    return .02+.29*math.sqrt(max(.02,1-(x/width)**2-yy**2))

def face_patch(name,x,y,w,h,material,lift=.004):
    verts=[(x,y,face_z(x,y)+lift)]; faces=[]; n=40
    for j in range(1,5):
        for i in range(n):
            t=i*2*pi/n; xx=x+cos(t)*w*.5*j/4; yy=y+sin(t)*h*.5*j/4
            verts.append((xx,yy,face_z(xx,yy)+lift))
    for i in range(n): faces.append((0,1+i,1+(i+1)%n))
    for j in range(3):
        for i in range(n):
            a=1+j*n+i; b=1+j*n+(i+1)%n
            faces.append((a,b,b+n,a+n))
    return mesh(name,verts,faces,material)

def hair_cap(staff=False):
    verts=[]; faces=[]; rings=28; n=80
    for j in range(rings+1):
        u=j/rings
        for i in range(n):
            t=i*2*pi/n
            # A rounded bob at the back and sides, with a swept front fringe.
            end=(2.35-1.05*max(0,cos(t)) if staff else 1.9-.6*cos(t))
            end+=.13*sin(t*2+1)*max(0,cos(t))**3
            a=.012+u*end
            verts.append((sin(t)*sin(a)*.373,1.61+cos(a)*.365,cos(t)*sin(a)*.323-.024))
    for j in range(rings):
        for i in range(n): faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    mesh('Rounded bob' if staff else 'Soft swept hair',verts,faces,M['hair'])
    # Flow is carried by the asymmetrical fringe of the continuous cap, not
    # separate bead-like locks or etched surface lines.
    if staff:
        for side in [-1,1]:
            oval('Bob side volume',(side*.305,1.47,-.035),(.18,.38,.37),M['hair'])

def character(staff=False):
    clear()
    # Match the initial game palette in standalone Blender/glTF viewers too.
    for key,color in [('outfit','55aaa0' if staff else 'dca48c'),('hair','79513c' if staff else 'aaa09a')]:
        M[key].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=rgb(color)
    # 1.98 units high / .73-unit head = 2.7 heads, shared pose contract.
    head=oval('Face',(0,1.56,.02),(.7,.71,.58),M['skin'])
    for v in head.data.vertices:
        if v.co.z<0: v.co.x*=1+.08*v.co.z/.355
    before=set(scene.objects)
    cheek=mat('Soft peach cheeks','efbea9',.72)
    for side in [-1,1]:
        oval('Ear',(side*.342,1.52,.012),(.11,.16,.1),M['skin'])
        face_patch('Eye white',side*.126,1.572,.115,.136,M['white'])
        face_patch('Warm iris',side*.123,1.564,.068,.103,M['iris'],.006)
        face_patch('Eye glint',side*.123-.014,1.59,.019,.023,M['white'],.008)
        points=[(side*x,y,face_z(side*x,y)+.007) for x,y in [(.074,1.685),(.13,1.695),(.182,1.68)]]
        tube('Soft brow',points,.009,M['hair'])
        face_patch('Cheek tint',side*.222,1.458,.09,.042,cheek,.003)
    oval('Button nose',(0,1.505,.308),(.068,.073,.055),M['skin'])
    tube('Gentle smile',[(x,y,face_z(x,y)+.006) for x,y in [(-.05,1.408),(0,1.394),(.05,1.408)]],.009,M['lip'])
    hair_cap(staff)
    head_group=group('Head',set(scene.objects)-before|{head},(0,1.50,0))
    before=set(scene.objects)
    oval('Tailored shirt',(0,.92,0),(.56,.72,.4),M['outfit'],.7)
    oval('Neck',(0,1.265,0),(.2,.24,.2),M['skin'])
    # A defined V collar, pocket and fabric seams break up the plain torso silhouette.
    tube('Left collar',[(-.20,1.205,.11),(-.11,1.24,.17),(0,1.10,.205)],.025,M['ivory'])
    tube('Right collar',[(.20,1.205,.11),(.11,1.24,.17),(0,1.10,.205)],.025,M['ivory'])
    box('Shirt pocket',(.14,.95,.196),(.14,.14,.018),M['outfit'],.015)
    tube('Pocket seam',[(.075,1.0,.211),(.205,1.0,.211)],.008,M['ivory'])
    if staff:
        box('Name badge',(-.14,1.0,.207),(.13,.17,.018),M['ivory'],.015)
        box('Badge clip',(-.14,1.09,.21),(.06,.035,.02),M['gold'],.01)
    group('Torso',set(scene.objects)-before)
    for side,suffix in [(-1,'L'),(1,'R')]:
        before=set(scene.objects)
        sleeve=oval('Sleeve',(side*.30,1.08,0),(.23,.34,.26),M['outfit'],.7)
        sleeve.rotation_euler.y=side*.18
        oval('Forearm',(side*.34,.82,.02),(.15,.32,.16),M['skin'])
        oval('Hand',(side*.34,.64,.045),(.16,.17,.15),M['skin'])
        oval('Thumb',(side*.28,.655,.09),(.07,.095,.08),M['skin'])
        group('Arm_'+suffix,set(scene.objects)-before,(side*.27,1.17,0))
        before=set(scene.objects)
        oval('Trouser leg',(side*.14,.345,0),(.225,.55,.26),M['trousers'],.55)
        oval('Shoe',(side*.145,.09,.105),(.26,.19,.4),M['ivory'],.5)
        extrusion('Shoe sole',(side*.145,.035,.1),.27,.41,.045,.1,M['sole'])
        tube('Shoe stitching',[(side*.145-.08,.13,.2),(side*.145,.15,.23),(side*.145+.08,.13,.2)],.009,M['linen'])
        group('Leg_'+suffix,set(scene.objects)-before,(side*.14,.6,0))
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
        tube('Spectacle rim',[(side*.126+cos(t)*.087,1.572+sin(t)*.096,face_z(side*.126+cos(t)*.087,1.572+sin(t)*.096)+.024) for t in [i*2*pi/32 for i in range(32)]],.008,M['gold'],True)
        tube('Spectacle temple',[(side*.215,1.58,.27),(side*.32,1.59,.19),(side*.35,1.55,.01)],.011,M['gold'])
    tube('Spectacle bridge',[(-.04,1.58,.326),(0,1.6,.33),(.04,1.58,.326)],.01,M['gold'])
    glasses=group('Glasses',set(scene.objects)-before,(0,1.50,0))
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
    scene.render.bake.target='VERTEX_COLORS'; scene.cycles.samples=64
    bpy.ops.object.bake(type='AO')
    # glTF stores COLOR_0 as a multiplier; lift excessive crevice darkness.
    for o in meshes:
        attr=o.data.color_attributes['ContactShade']
        for c in attr.data:
            ao=.94+.06*max(0,min(1,c.color[0])); c.color=(ao,ao,ao,1)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.file.pack_all(); bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_vertex_color='ACTIVE',export_all_vertex_colors=False)
    print('CHARACTER_REPORT',name,sum(len(o.data.vertices) for o in meshes),flush=True)

character(False); export_character('patient')
character(True); export_character('nurse')
print('CHARACTERS COMPLETE',flush=True)
