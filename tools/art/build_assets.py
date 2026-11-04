"""Author Sunshine Hospital's original Blender meshes and bake their contact shading.

Run: blender -b --factory-startup -t 8 --python tools/art/build_assets.py
Coordinates in this script are the game's X/right, Y/up, Z/front convention.
The exported GLBs are the assets used by the game, not background illustrations.
"""
import bpy, bmesh, math, random, json, sys
from pathlib import Path
from mathutils import Vector, Matrix
from math import sin, cos, pi
sys.path.insert(0,str(Path(__file__).resolve().parent))
from export_models import export_static, soften_contact_atlas

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'godot/assets/models'
SRC = ROOT / 'art/source'
TEX = ROOT / 'godot/assets/textures'
for path in [OUT, SRC, TEX]: path.mkdir(parents=True, exist_ok=True)
random.seed(73)
bpy.context.preferences.filepaths.save_version=0

def C(p): return Vector((p[0], -p[2], p[1]))
def rgb(value):
    v = tuple(int(value[i:i+2],16)/255 for i in (0,2,4))
    return tuple(x/12.92 if x <= .04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
def mat(name, color, rough=.65, metal=0, emit=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=rgb(color)
    bs.inputs['Roughness'].default_value=rough
    bs.inputs['Metallic'].default_value=metal
    if emit:
        bs.inputs['Emission Color'].default_value=rgb(color)
        bs.inputs['Emission Strength'].default_value=emit
    m.diffuse_color=rgb(color)
    return m

def clear():
    for obj in list(bpy.context.scene.objects): bpy.data.objects.remove(obj,do_unlink=True)

def mesh(name, verts, faces, material, smooth=True):
    data=bpy.data.meshes.new(name); data.from_pydata([C(v) for v in verts],[],faces); data.update()
    bm=bmesh.new(); bm.from_mesh(data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(data); bm.free()
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o)
    if material: data.materials.append(material)
    for p in data.polygons: p.use_smooth=smooth
    return o

def bevel(o, amount=.04, segments=4):
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    mod=o.modifiers.new('Soft manufactured edges','BEVEL'); mod.width=amount; mod.segments=segments
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons: p.use_smooth=True
    norm=o.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL'); norm.keep_sharp=True; norm.weight=40
    bpy.ops.object.modifier_apply(modifier=norm.name)
    o.select_set(False)
    return o

def box(name, p, size, material, radius=.035):
    bpy.ops.mesh.primitive_cube_add(size=1,location=C(p)); o=bpy.context.object; o.name=name
    o.dimensions=(size[0],size[2],size[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    if radius: bevel(o,min(radius,min(size)*.45))
    return o

def oval(name,p,size,material,exponent=1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,radius=1,location=C(p))
    o=bpy.context.object; o.name=name
    axes=(size[0]/2,size[2]/2,size[1]/2)
    for v in o.data.vertices:
        for k in range(3): v.co[k]=math.copysign(abs(v.co[k])**exponent,v.co[k])*axes[k]
    o.data.materials.append(material)
    for f in o.data.polygons: f.use_smooth=True
    return o

def lathe(name,p,profile,material,n=40):
    verts=[]; faces=[]
    for y,r in profile:
        for i in range(n):
            a=i*2*pi/n; verts.append((p[0]+cos(a)*r,p[1]+y,p[2]+sin(a)*r))
    for j in range(len(profile)-1):
        for i in range(n):
            a=j*n+i; b=j*n+(i+1)%n; faces.append((a,b,b+n,a+n))
    return mesh(name,verts,faces,material)

def tube(name,points,radius,material,closed=False):
    d=bpy.data.curves.new(name,'CURVE'); d.dimensions='3D'; d.resolution_u=3
    d.bevel_depth=radius; d.bevel_resolution=2; d.use_fill_caps=True
    s=d.splines.new('BEZIER'); s.bezier_points.add(len(points)-1); s.use_cyclic_u=closed
    for bp,p in zip(s.bezier_points,points): bp.co=C(p); bp.handle_left_type='AUTO'; bp.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.convert(target='MESH'); o.data.materials.append(material)
    return o

def outline(width,depth,radius):
    pts=[]
    for x,z,a in [(width/2-radius,depth/2-radius,0),(-width/2+radius,depth/2-radius,pi/2),(-width/2+radius,-depth/2+radius,pi),(width/2-radius,-depth/2+radius,3*pi/2)]:
        for i in range(9):
            t=a+i*pi/16; pts.append((x+radius*cos(t),z+radius*sin(t)))
    return pts

def extrusion(name,p,width,depth,height,radius,material):
    pts=outline(width,depth,radius); n=len(pts)
    verts=[(p[0]+x,p[1]+y,p[2]+z) for y in [-height/2,height/2] for x,z in pts]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return bevel(mesh(name,verts,faces,material,False),.018,3)

def move_group(before,at=(0,0,0),yaw=0):
    bpy.context.view_layer.update()
    trans=Matrix.Translation(C(at)) @ Matrix.Rotation(yaw,4,'Z')
    for o in set(bpy.context.scene.objects)-before: o.matrix_world=trans @ o.matrix_world

def texture_material(name,color1,color2,kind='wood'):
    """Bake original procedural surface color to a normal glTF image material."""
    m=mat(name,color1); nodes=m.node_tree.nodes; links=m.node_tree.links
    bs=nodes.get('Principled BSDF'); out=nodes.get('Material Output')
    tc=nodes.new('ShaderNodeTexCoord'); mapping=nodes.new('ShaderNodeVectorMath'); mapping.operation='MULTIPLY'
    mapping.inputs[1].default_value=(8,.55,1) if kind=='wood' else (110,110,110)
    links.new(tc.outputs['UV'],mapping.inputs[0])
    noise=nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=6 if kind=='wood' else 2
    noise.inputs['Detail'].default_value=3; noise.inputs['Roughness'].default_value=.65
    links.new(mapping.outputs[0],noise.inputs['Vector'])
    ramp=nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].position=.15; ramp.color_ramp.elements[1].position=.85
    ramp.color_ramp.elements[0].color=rgb(color1); ramp.color_ramp.elements[1].color=rgb(color2)
    links.new(noise.outputs['Fac'],ramp.inputs[0])
    emission=nodes.new('ShaderNodeEmission'); links.new(ramp.outputs['Color'],emission.inputs[0]); links.new(emission.outputs[0],out.inputs[0])
    image=bpy.data.images.new(name+' surface',width=512,height=512)
    image.colorspace_settings.name='sRGB'
    dest=nodes.new('ShaderNodeTexImage'); dest.image=image; nodes.active=dest
    bpy.ops.mesh.primitive_plane_add(size=2); plane=bpy.context.object; plane.data.materials.append(m)
    bpy.ops.object.bake(type='EMIT')
    image.filepath_raw=str(TEX/(name+'.png')); image.file_format='PNG'; image.save()
    bpy.data.objects.remove(plane,do_unlink=True)
    for node in [tc,mapping,noise,ramp,emission]: nodes.remove(node)
    links.new(dest.outputs['Color'],bs.inputs['Base Color']); links.new(bs.outputs[0],out.inputs[0])
    bs.inputs['Roughness'].default_value=.48 if kind=='wood' else .76
    return m

clear()
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.cycles.device='CPU'; scene.render.bake.margin=8
scene.world.color=(.8,.8,.8)
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
scene.view_settings.exposure=0
scene.view_settings.gamma=1
M={}
M['oak']=texture_material('Honey oak','d4ad82','ddba90')
M['fabric']=texture_material('Coral woven upholstery','ec9e89','eea38f','cloth')
M['linen']=texture_material('Warm linen','ede6d6','f0eada','cloth')
for name,color,rough,metal,emit in [
 ('ivory','f4ece2',.42,0,0),('white','f6f1e9',.29,0,0),('cream','e9dece',.65,0,0),
 ('mint','c7dcd5',.55,0,0),('darkmint','5c9e95',.37,0,0),('teal','86c5bb',.36,0,0),
 ('gold','bca071',.34,.45,0),('metal','b7c5c3',.3,.6,0),('dark','465558',.48,.1,0),
 ('screen','1f3945',.4,0,.1),('screenblue','80b9c3',.5,0,.25),('scan','b7d0d0',.6,0,.15),
 ('lamp','ffe7b4',.45,0,.4),('grout','ddd8cd',.65,0,0),('floor','eee6d9',.38,0,0),
 ('green','85ac68',.62,0,0),('leaf','a7c77e',.64,0,0),('leafdark','6b9b64',.68,0,0),
 ('garden','b7c9aa',.85,0,0),
 ('rose','e9a6b8',.85,0,0),('yellow','efc85f',.7,0,0),('soil','746346',1,0,0),
 ('pot','f0e4d2',.3,0,0),('blue','aac8d2',.48,0,0),('book','a7b09b',.9,0,0),
 ('skin','f6cfb5',.62,0,0),('hair','78503b',.48,0,0),('iris','48332b',.32,0,0),
 ('lip','b76e66',.85,0,0),('outfit','ffffff',.9,0,0),('trousers','d4d7ce',.85,0,0),
 ('sole','ae9b7d',.85,0,0),('bark','9c7a55',.9,0,0)]: M[name]=mat(name,color,rough,metal,emit)

def leaf(start,end,width,material):
    a=Vector(start); b=Vector(end); along=b-a
    right=along.cross(Vector((0,1,0))).normalized()
    verts=[]; faces=[]
    for i in range(9):
        u=i/8; c=a+along*u+Vector((0,.12*sin(pi*u),0))
        for j in range(5):
            v=j/2-1; p=c+right*(width*sin(pi*u)**.7*v)
            p.y += .04*(1-v*v)*sin(pi*u); verts.append(tuple(p))
    for i in range(8):
        for j in range(4):
            k=i*5+j; faces.append((k,k+1,k+6,k+5))
    return mesh('Curved leaf',verts,faces,material)

def plant(at,scale=1,flowers=False):
    before=set(scene.objects)
    lathe('Glazed planter',(0,0,0),[(0,0),(.02,.19),(.07,.22),(.43,.28),(.48,.29),(.49,.24),(.44,.24)],M['pot'])
    lathe('Potting soil',(0,.44,0),[(0,0),(.01,.235)],M['soil'])
    for i in range(9 if not flowers else 7):
        t=i*2.399; h=.7+(i%3)*.19
        tip=(cos(t)*.38,h,sin(t)*.38)
        tube('Stem',[(0,.46,0),(cos(t)*.1,.65,sin(t)*.1),tip],.012,M['leafdark'])
        if not flowers:
            leaf((cos(t)*.08,.58,sin(t)*.08),tip,.15,M[['green','leaf','leafdark'][i%3]])
        else:
            for j in range(5):
                a=j*2*pi/5
                oval('Flower petal',(tip[0]+cos(a)*.065,tip[1],tip[2]+sin(a)*.065),(.12,.055,.12),M['yellow'])
            oval('Flower center',(tip[0],tip[1]+.025,tip[2]),(.06,.04,.06),M['gold'])
            leaf((0,.5,0),(cos(t)*.22,.68,sin(t)*.22),.09,M['leaf'])
    for o in set(scene.objects)-before: o.matrix_world=Matrix.Diagonal((scale,scale,scale,1))@o.matrix_world
    move_group(before,at)

def chair(at):
    before=set(scene.objects)
    for x in [-.4,.4]:
        for z in [-.33,.33]:
            lathe('Tapered oak leg',(x,0,z),[(.02,.045),(.31,.065)],M['oak'],16)
    oval('Upholstered seat',(0,.49,0),(1.06,.34,.98),M['fabric'],.4)
    oval('Soft seat cushion',(0,.64,.06),(.82,.2,.79),M['fabric'],.45)
    back=oval('Curved padded back',(0,1.02,-.35),(1.08,1.0,.34),M['fabric'],.45)
    back.rotation_euler.x=math.radians(-7)
    for x in [-.49,.49]: oval('Rolled armrest',(x,.76,0),(.26,.56,1.02),M['fabric'],.45)
    # The silhouette and padded overlap describe the fabric, without dark piping.
    move_group(before,at)

def monitor(at,yaw=0):
    before=set(scene.objects)
    extrusion('Monitor foot',(0,.035,0),.48,.32,.06,.09,M['dark'])
    box('Monitor riser',(0,.24,0),(.06,.4,.07),M['metal'])
    box('Thin display casing',(0,.6,0),(1.04,.68,.09),M['dark'],.035)
    box('Glass display',(0,.6,.051),(.94,.56,.012),M['screen'],.014)
    for x in [-.2,.21]:
        oval('CT slice',(x,.62,.065),(.3,.38,.012),M['scan'])
        for side in [-1,1]: oval('CT lung',(x+side*.063,.63,.075),(.09,.21,.012),M['screen'])
    for i in range(3): box('Screen interface',(-.32,.39+i*.04,.07),(.2,.012,.008),M['screenblue'],0)
    box('Keyboard',(0,.035,.42),(.83,.045,.27),M['ivory'],.02)
    for row in range(3):
        for col in range(10): box('Key',(-.34+col*.074,.064,.34+row*.065),(.054,.012,.045),M['cream'],.004)
    oval('Mouse',(.58,.04,.4),(.13,.065,.21),M['ivory'])
    move_group(before,at,yaw)

def cabinet(at,width=1.5,height=1.1):
    x,y,z=at
    box('Cabinet carcass',(x,y+height/2,z),(width,height,.7),M['ivory'],.04)
    box('Oak worktop',(x,y+height+.045,z),(width+.1,.09,.78),M['oak'],.035)
    for side in [-1,1]:
        box('Inset door',(x+side*width*.25,y+height*.49,z+.365),(width*.47,height*.82,.035),M['cream'],.025)
        tube('Brass cabinet pull',[(x+side*.08,y+height*.6,z+.4),(x+side*.08,y+height*.6,z+.43),(x+side*.08,y+height*.76,z+.43)],.014,M['gold'])

def picture(at):
    x,y,z=at
    box('Oak picture frame',at,(.95,.76,.07),M['oak'],.035)
    box('Paper mount',(x,y,z+.04),(.84,.65,.012),M['white'],.008)
    box('Landscape sky',(x,y+.02,z+.05),(.7,.49,.008),M['blue'],.005)
    oval('Painted hill',(x-.14,y-.12,z+.06),(.45,.22,.009),M['leaf'])
    oval('Painted hill',(x+.17,y-.14,z+.065),(.35,.18,.009),M['green'])
    oval('Painted sun',(x+.2,y+.15,z+.06),(.12,.12,.008),M['yellow'])

def wall_lamp(at):
    x,y,z=at
    box('Brass sconce',at,(.56,.2,.15),M['gold'],.04)
    box('Diffused wall light',(x,y-.025,z+.085),(.46,.12,.055),M['lamp'],.04)

def emblem(at,scale=1):
    x,y,z=at
    oval('Sun emblem',(x,y+.1*scale,z),(.4*scale,.4*scale,.05),M['yellow'])
    for i in range(5):
        a=pi*.15+i*pi*.175
        tube('Sun ray',[(x+cos(a)*.29*scale,y+(.1+sin(a)*.29)*scale,z),(x+cos(a)*.4*scale,y+(.1+sin(a)*.4)*scale,z)],.023*scale,M['gold'])
    for side in [-1,1]:
        leaf((x,y-.2*scale,z+.03),(x+side*.29*scale,y+.02*scale,z+.03),.09*scale,M['green'])

def bed(at):
    x,y,z=at
    extrusion('Bed footing',(x,y+.13,z),1.05,1.9,.23,.25,M['darkmint'])
    box('Lift pedestal',(x,y+.52,z-.17),(.52,.76,.7),M['white'],.13)
    for h in [.42,.61]: box('Lift seam',(x,y+h,z-.17),(.525,.012,.705),M['cream'],.004)
    extrusion('Floating couch',(x,y+.9,z),1.02,2.72,.18,.23,M['white'])
    oval('Mattress',(x,y+1.015,z),(.89,.14,2.54),M['teal'],.35)
    oval('Linen pillow',(x,y+1.12,z-.91),(.72,.18,.49),M['linen'],.45)
    for side in [-1,1]: tube('Bed side rail',[(x+side*.55,y+.87,z-.6),(x+side*.55,y+.93,z-.4),(x+side*.55,y+.93,z+.8)],.024,M['metal'])

def scanner(at):
    x,y,z=at; bed(at)
    extrusion('CT floor pedestal',(x,y+.3,z-.9),2.67,1.15,.55,.35,M['ivory'])
    # Lathed front and rear profiles form a thick, softly rounded enclosure.
    profile=[(.66,.34),(.66,.43),(.68,.48),(.74,.51),(.82,.515),(1.15,.515),
             (1.23,.5),(1.31,.46),(1.38,.38),(1.42,.27),(1.43,.15),(1.43,-.23),
             (1.41,-.32),(1.35,-.41),(1.26,-.46),(.78,-.46),(.69,-.4),(.66,-.32)]
    verts=[]; faces=[]; n=96
    for radius,depth in profile:
        for i in range(n):
            a=i*2*pi/n; verts.append((x+cos(a)*radius,y+1.62+sin(a)*radius,z-.9+depth))
    for j in range(len(profile)):
        for i in range(n): faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(profile))*n+(i+1)%n,((j+1)%len(profile))*n+i))
    mesh('Sculpted CT shell',verts,faces,M['white'])
    tube('Mint bore gasket',[(x+cos(a)*.7,y+1.62+sin(a)*.7,z-.43) for a in [i*2*pi/80 for i in range(80)]],.045,M['teal'],True)
    tube('Outer shell seam',[(x+cos(a)*1.432,y+1.62+sin(a)*1.432,z-1.03) for a in [i*2*pi/96 for i in range(96)]],.006,M['cream'],True)
    box('CT control display',(x,y+2.69,z-.39),(.42,.22,.03),M['screenblue'],.025)
    for side in [-1,1]:
        box('Scanner control bank',(x+side*1.02,y+1.48,z-.41),(.25,.38,.055),M['cream'],.045)
        for j in range(3): oval('Control key',(x+side*1.02,y+1.38+j*.08,z-.37),(.06,.045,.025),M['teal'])

def linac(at):
    before=set(scene.objects)
    x,y,z=at; bed(at)
    extrusion('Treatment base',(x,y+.3,z-1.5),2.2,1.55,.56,.5,M['ivory'])
    box('Treatment column',(x,y+1.35,z-1.75),(1.15,2.1,.83),M['white'],.32)
    # A broad rotational shoulder, curved arm and separate downward treatment
    # head make the linac read differently from the circular CT bore.
    for side in [-1,1]:
        oval('Gantry rotation bearing',(x+side*.6,y+1.4,z-1.72),(.15,1.08,1.08),M['darkmint'])
        oval('Bearing cover',(x+side*.68,y+1.4,z-1.72),(.08,.8,.8),M['ivory'])
    path=[]
    for i in range(25):
        a=pi-i*pi/24
        path.append((y+1.75+sin(a)*.95,z-.94+cos(a)*.85,.34+.08*i/24))
    verts=[];faces=[];n=32
    for j,(h,d,r) in enumerate(path):
        prev=path[max(0,j-1)]; nxt=path[min(len(path)-1,j+1)]
        dh,dd=nxt[0]-prev[0],nxt[1]-prev[1]; length=math.hypot(dh,dd)
        for i in range(n):
            a=i*2*pi/n; verts.append((x+cos(a)*r,h+sin(a)*r*(-dd/length),d+sin(a)*r*(dh/length)))
    for j in range(len(path)-1):
        for i in range(n): faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    mesh('Continuous treatment gantry',verts,faces,M['white'])
    extrusion('Collimator housing',(x,y+2.03,z-.09),1.03,.97,.57,.29,M['ivory'])
    extrusion('Collimator aperture',(x,y+1.72,z-.09),.72,.62,.065,.18,M['darkmint'])
    bpy.context.view_layer.update()
    turn=Matrix.Translation(C(at)) @ Matrix.Rotation(math.radians(-35),4,'Z') @ Matrix.Translation(-C(at))
    for part in set(scene.objects)-before: part.matrix_world=turn @ part.matrix_world

def floor_room(x,z,tile='floor',back_height=2.6):
    box('Room foundation',(x,-.16,z),(6,.32,5.5),M['cream'],.08)
    # A continuous surface and hairline, flush grout do not cast black slot
    # shadows. Joints are color boundaries, not gaps between separate slabs.
    box('Continuous satin floor',(x,.025,z),(5.99,.05,5.49),M[tile],.008)
    for i in range(6):
        if i: box('Shallow floor joint',(x-3+i,.051,z),(.009,.001,5.48),M['grout'],0)
        if i: box('Shallow floor joint',(x,.051,z-2.75+i*.916),(5.98,.001,.009),M['grout'],0)
    # Full height rear walls and lower cutaway partitions keep the characters readable.
    box('Painted rear wall',(x,back_height/2,z-2.75),(6.06,back_height,.19),M['mint'] if z<0 else M['ivory'],.035)
    box('Oak wainscot',(x,.55,z-2.63),(5.96,1.05,.055),M['oak'],.012)
    for i in range(20): box('Fine wall flute',(x-2.86+i*.30,.55,z-2.598),(.014,1.03,.012),M['oak'],.004)
    box('Wall cap',(x,back_height+.04,z-2.75),(6.16,.14,.28),M['white'],.04)
    box('Chair rail',(x,1.1,z-2.59),(6,.07,.09),M['oak'],.02)
    box('Floor skirting',(x,.12,z-2.6),(5.95,.15,.08),M['white'],.025)
    for dx in [-2.15,2.15]: wall_lamp((x+dx,back_height-.4,z-2.6))

def bookshelf(at):
    x,y,z=at
    box('Bookcase back',(x,y+1.15,z),(1.65,2.3,.12),M['oak'])
    for dx in [-.84,.84]: box('Bookcase side',(x+dx,y+1.15,z+.24),(.1,2.4,.62),M['oak'])
    for h in [.05,.62,1.2,1.78,2.35]: box('Bookcase shelf',(x,y+h,z+.24),(1.75,.07,.63),M['oak'])
    for row in range(4):
        for col in range(6):
            h=.35+random.random()*.12
            box('Archive binder',(x-.65+col*.25,y+.1+row*.57+h/2,z+.25),(.17,h,.34),M[['book','blue','linen'][col%3]],.012)
            box('Binder label',(x-.65+col*.25,y+.28+row*.57,z+.426),(.095,.09,.008),M['white'],.006)

def reception():
    x,z=-4.8,5.05
    extrusion('Reception plinth',(x,.14,z),3.42,1.03,.22,.48,M['darkmint'])
    extrusion('Curved oak reception',(x,.7,z),3.35,1.0,1.05,.46,M['oak'])
    # Flutes follow the actual rounded rectangle, not an unrelated ellipse.
    for i in range(23):
        px=x-1.12+i*.102
        box('Reception subtle flute',(px,.7,z+.502),(.014,.9,.012),M['oak'],.004)
    extrusion('Quartz counter',(x,1.26,z),3.58,1.17,.14,.51,M['white'])
    emblem((x,.72,z+.54),.72)
    monitor((-5.75,1.34,5.0),pi)
    plant((-3.55,1.34,5),.47,True)
    box('Welcome card',(-4.2,1.48,5.42),(.32,.25,.035),M['cream'],.02)
    for i in range(4):
        chair((-4.5+(i%2)*1.3,0,1.85+(i//2)*1.5))
    lathe('Round coffee table',(-5.95,0,3.05),[(0,.15),(.08,.18),(.61,.07),(.65,.58),(.73,.58),(.75,.54)],M['oak'])
    plant((-5.95,.75,3.05),.36,True)
    box('Waiting room magazine',(-5.7,.79,3.22),(.32,.035,.38),M['blue'],.012)
    lathe('Standing lamp',(-6.35,0,1.2),[(0,.23),(.08,.24),(.1,.035),(1.72,.035)],M['gold'])
    lathe('Linen lampshade',(-6.35,1.69,1.2),[(0,.4),(.06,.4),(.5,.26),(.54,.25)],M['linen'])
    for dx in [-5.5,-2.6]: picture((dx,1.66,.43))
    emblem((-4,1.66,.43),.8)

def corridor_partition(x,z):
    # A two metre clear opening follows the existing patient route into each
    # room. Cutaway-height walls make the rooms read as a connected building.
    door_z=-1.2 if x==1 and z<0 else z
    half_width=.85 if x==1 and z<0 else 1.05
    for start,end in [(z-2.75,door_z-half_width),(door_z+half_width,z+2.75)]:
        length=end-start
        if length>.15:
            at=(start+end)/2
            box('Corridor partition',(x,.85,at),(.19,1.7,length),M['ivory'],.035)
            box('Partition oak panel',(x,.52,at),(.22,.95,length-.1),M['oak'],.018)
            box('Partition coping',(x,1.74,at),(.29,.14,length+.08),M['white'],.04)
    for side in [-1,1]:
        box('Open doorway jamb',(x,1.16,door_z+side*half_width),(.27,2.32,.15),M['oak'],.025)
    box('Open doorway lintel',(x,2.34,door_z),(.28,.18,half_width*2+.16),M['oak'],.035)

def garden_shrub(at):
    before=set(scene.objects)
    for i in range(22):
        t=i*2.399; r=.15+(i%4)*.14; h=.3+(i%5)*.11
        leaf((0,.02,0),(cos(t)*(r+.35),h,sin(t)*(r+.35)),.2,M['leaf' if i%3 else 'leafdark'])
    for i in range(11):
        t=i*2.399; r=.15+(i%3)*.23; x,z=cos(t)*r,sin(t)*r; y=.38+(i%4)*.14
        # A sculpted five-lobed blossom, not a textured card.
        verts=[(x,y-.035,z)]; faces=[]
        for j in range(40):
            a=j*2*pi/40; radius=.115*(1+.22*cos(a*5))
            verts.append((x+cos(a)*radius,y+cos(a*5)*.014,z+sin(a)*radius))
        for j in range(40): faces.append((0,j+1,(j+1)%40+1))
        mesh('Garden blossom',verts,faces,M['rose' if i%3 else 'ivory'])
        oval('Flower pollen',(x,y+.015,z),(.045,.035,.045),M['yellow'])
    move_group(before,at)

def interior():
    box('Hospital foundation',(0,-.36,.15),(14.4,.42,12.55),M['cream'],.18)
    box('Continuous hall floor',(0,.025,0),(2,.05,12),M['floor'],.008)
    for z in range(11):
        box('Hall shallow joint',(0,.051,-5+z),(2,.001,.009),M['grout'],0)
    floor_room(-4,3,'floor',2.15); floor_room(-4,-3,'mint',3.05)
    floor_room(4,-3,'floor',3.05); floor_room(4,3,'mint',2.15)
    for x in [-1,1]:
        for z in [-3,3]: corridor_partition(x,z)
    for x in [-4,4]:
        box('Low front cutaway wall',(x,.16,5.85),(6,.32,.2),M['ivory'],.05)
        box('Low wall coping',(x,.35,5.85),(6.08,.1,.28),M['white'],.035)
    reception(); scanner((-4,0,-2.8)); linac((4,0,3))
    cabinet((-2.15,0,-5.15),1.4); monitor((-2.15,1.2,-5.15))
    cabinet((4.75,0,-4.7),3.3); bookshelf((2,0,-5.25))
    for x in [4,5.3]: monitor((x,1.2,-4.7))
    plant((6.1,1.2,-4.7),.7); plant((-6.25,0,-4.5),1.2)
    cabinet((6.15,0,1),1.35); plant((6.25,0,-2.2),1.1)
    # Tall daylight glazing, wooden mullions, sill and a safe clear central corridor.
    for z in [-5.5,-3.8,-2.1,-.4,1.3,3,4.7,6]:
        box('Window mullion',(-7.05,1.55,z),(.16,3.1,.11),M['oak'],.025)
    for y in [.25,1.5,3.1]: box('Window rail',(-7.05,y,.2),(.17,.11,11.8),M['oak'],.025)
    for x in [-.48,.48]:
        box('Rear glazed door',(x,1.3,-5.75),(.9,2.6,.15),M['oak'],.035)
        box('Door glass',(x,1.7,-5.65),(.65,1.26,.04),M['blue'],.035)
        tube('Door handle',[(x*.4,.95,-5.58),(x*.4,1.22,-5.58)],.025,M['gold'])
    for side in [-1,1]:
        for z in [-4.9,-1.1,1.1,4.9]: tube('Hall handrail',[(side*.82,.86,z-.55),(side*.82,.86,z+.55)],.035,M['oak'])
    for at in [(-6.3,0,.85),(-2.1,0,4.9),(6.4,0,4.8)]: plant(at,.8)
    # Low garden edge frames the playable rooms without covering the walking paths.
    box('Garden soil',(0,-.67,.4),(18.5,.25,16),M['garden'],.25)
    for x,z in [(-7.7,-4.5),(-7.7,-1.5),(-7.7,2),(-7.7,5),(-6,7),(-4.3,7),(5,7),(6.7,7)]:
        plant((x,-.5,z),.85,True)
    for at in [(-7.7,-.5,5.8),(-6.8,-.5,6.6),(-5.4,-.5,6.6),(6.9,-.5,6.5),(7.6,-.5,5.7)]: garden_shrub(at)

def simple_uv(o):
    if o.data.uv_layers:
        # Every joined part must share UV0; otherwise Blender preserves a third
        # UV layer that Godot cannot use for the occlusion texture.
        o.data.uv_layers[0].name='Surface'
        return
    uv=o.data.uv_layers.new(name='Surface')
    for poly in o.data.polygons:
        axis=max(range(3),key=lambda k:abs(poly.normal[k])); a,b=[k for k in range(3) if k!=axis]
        for li in poly.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co; uv.data[li].uv=(v[a]*.7,v[b]*.7)

def bake_export(name,ao_size=2048):
    """Bake shared UV2 ambient occlusion and export a small set of material surfaces."""
    objs=[o for o in scene.objects if o.type=='MESH']
    for o in objs: simple_uv(o)
    # Preserve separately editable furniture; only the joined mesh is exported.
    authoring=bpy.data.collections.new(name+' — editable parts')
    scene.collection.children.link(authoring)
    source_materials={}
    for o in objs:
        copy=o.copy(); copy.data=o.data.copy(); authoring.objects.link(copy)
        copy.name='Source · '+o.name
        for i,m in enumerate(copy.data.materials):
            if m not in source_materials: source_materials[m]=m.copy()
            copy.data.materials[i]=source_materials[m]
        copy.hide_set(True); copy.hide_render=True
    authoring.hide_viewport=True
    authoring.hide_render=True
    for source in authoring.objects:
        source.hide_set(False); source.hide_render=False
    # Spend triangles on the silhouettes the player actually reads. Reduce
    # tiny repeated parts BEFORE UV baking instead of collapsing the finished
    # CT, cushions and AO charts together after baking.
    protected=('Sculpted CT','Mint bore','Upholstered','Soft seat','Curved padded',
               'Rolled armrest','Quartz counter','Curved oak reception',
               'Continuous treatment','Collimator','Mattress','Linen pillow')
    counts={o:sum(len(p.vertices)-2 for p in o.data.polygons) for o in objs}
    keep=sum(n for o,n in counts.items() if o.name.startswith(protected) or n<150)
    reducible=sum(counts.values())-keep
    ratio=min(1,max(.05,(265000-keep)/max(1,reducible)))
    reduced=[]
    for o,n in counts.items():
        if o.name.startswith(protected) or n<150: continue
        mod=o.modifiers.new('Secondary detail budget','DECIMATE'); mod.ratio=ratio
        reduced.append(o)
    # Evaluate once. Applying thousands of operators individually rebuilds
    # the whole dependency graph for every small key/leaf.
    depsgraph=bpy.context.evaluated_depsgraph_get()
    evaluated={o:bpy.data.meshes.new_from_object(o.evaluated_get(depsgraph),preserve_all_data_layers=True,depsgraph=depsgraph) for o in reduced}
    for o,data in evaluated.items():
        o.modifiers.clear(); o.data=data
    print('DETAIL_BUDGET',name,'source',sum(counts.values()),'protected',keep,flush=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]; bpy.ops.object.join()
    obj=bpy.context.object; obj.name=name
    obj['authoring_triangles']=sum(counts.values())
    obj['couch_yaw_degrees']=-35
    assert len(obj.data.uv_layers)==1, 'Exactly one surface UV layer is required before AO'
    uv=obj.data.uv_layers.new(name='ContactAO'); obj.data.uv_layers.active=uv; uv.active_render=True
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(72),island_margin=.003,area_weight=.4)
    bpy.ops.object.mode_set(mode='OBJECT')
    image=bpy.data.images.new(name+' AO',width=ao_size,height=ao_size); image.colorspace_settings.name='Non-Color'
    used=set(obj.data.materials)
    for m in used:
        tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.name='Baked contact AO'; tex.image=image; m.node_tree.nodes.active=tex
    scene.render.bake.target='IMAGE_TEXTURES'; scene.cycles.samples=128
    bpy.ops.object.bake(type='AO')
    soften_contact_atlas(image)
    image.filepath_raw=str(TEX/(name+'-ao.png')); image.file_format='PNG'; image.save()
    for m in used:
        nt=m.node_tree; tex=nt.nodes.get('Baked contact AO')
        uvnode=nt.nodes.new('ShaderNodeUVMap'); uvnode.uv_map='ContactAO'; nt.links.new(uvnode.outputs[0],tex.inputs[0])
        group=bpy.data.node_groups.get('glTF Material Output')
        if group is None:
            group=bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree')
            group.interface.new_socket(name='Occlusion',in_out='INPUT',socket_type='NodeSocketFloat')
        node=nt.nodes.new('ShaderNodeGroup'); node.node_tree=group
        nt.links.new(tex.outputs['Color'],node.inputs['Occlusion'])
    obj.data.uv_layers.active_index=0
    obj.data.uv_layers[0].active_render=True
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')),compress=True)
    report=export_static(obj,name)
    report['ao_resolution']=ao_size
    print('ASSET_REPORT',json.dumps(report),flush=True)
    # Disconnect atlas nodes before reusing materials in the next independently baked asset.
    for m in used:
        for node in list(m.node_tree.nodes):
            if node.name=='Baked contact AO' or node.type=='UVMAP' or node.type=='GROUP':m.node_tree.nodes.remove(node)
    return report

if __name__ == '__main__':
    clear(); interior(); reports=[bake_export('hospital-interior')]
    clear(); floor_room(10,3,'mint',2.15); linac((10,0,3)); plant((12,0,4.8),1)
    box('Annex connection',(7,.015,5.2),(2.5,.06,1.2),M['floor'],.02)
    reports.append(bake_export('treatment-annex',1024))
    (OUT/'asset-report.json').write_text(json.dumps(reports,indent=2))
    print('STATIC ASSETS COMPLETE',flush=True)
