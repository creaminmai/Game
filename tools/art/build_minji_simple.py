"""Author the original Minji simple model in Blender's interactive app.

Run the module's build("draft") or build("final") from an application timer.
The draft only renders. Final generates a separate .blend and GLB once.
"""
from math import cos, exp, sin, pi, tau, sqrt
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "art/source/minji-simple-v1.blend"
EXPORT = ROOT / "unity/Assets/Editor/HospitalArt/minji-simple-v1.glb"
ARTIFACTS = ROOT / "artifacts/minji-simple-v1"
VOLUME_OUTPUT = ROOT / "art/source/minji-simple-volume.blend"
VOLUME_EXPORT = ROOT / "unity/Assets/Editor/HospitalArt/minji-simple-volume.glb"
VOLUME_ARTIFACTS = ROOT / "artifacts/minji-simple-volume"

FACE = (
    (1.010,.003,.003,.090), (1.027,.118,.090,.076), (1.052,.218,.162,.052),
    (1.090,.310,.230,.027), (1.140,.389,.286,.013), (1.193,.427,.312,.005),
    (1.247,.451,.327,.002), (1.404,.462,.347,-.006),
    (1.552,.449,.341,-.015), (1.713,.407,.303,-.032), (1.845,.320,.240,-.040),
    (1.946,.206,.144,-.048), (1.995,.004,.003,-.049),
)
HAIR = (
    (.970,.275,.226,-.040), (1.010,.385,.275,-.046), (1.073,.502,.326,-.049),
    (1.171,.565,.360,-.047), (1.309,.557,.367,-.048), (1.465,.529,.367,-.033),
    (1.625,.521,.365,-.040), (1.782,.471,.342,-.052), (1.925,.357,.275,-.056),
    (2.009,.197,.162,-.055), (2.029,.111,.097,-.054),
    (2.038,.039,.034,-.054), (2.040,.003,.003,-.054),
)
HAIRLINE = (
    (-180,1.003), (-132,1.002), (-103,1.023), (-83,1.049), (-70,1.074), (-58,1.262),
    (-50,1.499), (-42,1.541), (-29,1.573), (-14,1.590), (2,1.646),
    (16,1.739), (24,1.846), (32,1.773), (43,1.596), (54,1.315),
    (66,1.093), (82,1.050), (103,1.024), (132,1.002), (180,1.003),
)

# Independent sections measured across the front and side. Most of the extra
# head depth is behind the existing face so the expression keeps its projection.
VOLUMETRIC_FACE = (
    (1.010,.003,.003,-.029), (1.027,.118,.105,-.041), (1.052,.217,.182,-.052),
    (1.090,.310,.254,-.064), (1.140,.389,.331,-.074), (1.193,.427,.380,-.084),
    (1.247,.451,.423,-.095), (1.404,.462,.468,-.104),
    (1.552,.449,.449,-.108), (1.713,.407,.396,-.109), (1.845,.320,.328,-.110),
    (1.946,.206,.212,-.113), (1.983,.089,.099,-.115), (1.995,.004,.004,-.115),
)
VOLUMETRIC_HAIR = (
    (.970,.276,.242,-.101), (1.010,.386,.331,-.115), (1.073,.500,.438,-.125),
    (1.171,.566,.482,-.135), (1.309,.560,.490,-.129), (1.465,.536,.513,-.126),
    (1.625,.523,.503,-.134), (1.782,.473,.447,-.132), (1.925,.359,.348,-.127),
    (2.009,.198,.205,-.121), (2.029,.112,.115,-.118),
    (2.038,.038,.044,-.116), (2.040,.003,.004,-.116),
)
TUNIC = (
    (.412,.235,.148,-.005), (.427,.311,.174,-.008), (.472,.324,.182,-.009),
    (.639,.282,.164,-.004), (.796,.260,.148,0), (.885,.246,.142,-.002),
    (.968,.184,.105,-.003), (1.001,.110,.081,-.002), (1.015,.002,.002,0),
)
VOLUMETRIC_TUNIC = (
    (.412,.224,.181,-.017), (.426,.290,.234,-.019), (.464,.311,.260,-.021),
    (.540,.320,.283,-.023), (.643,.312,.288,-.024), (.749,.291,.268,-.025),
    (.851,.258,.228,-.026), (.913,.228,.186,-.025), (.966,.180,.135,-.022),
    (1.002,.095,.074,-.017), (1.015,.003,.005,-.015),
)
SKIN_A, SKIN_B = "F7DDCF", "F5D5C5"


def sample(sections, value):
    if value <= sections[0][0]:
        return sections[0][1:]
    for i, (lo, hi) in enumerate(zip(sections, sections[1:])):
        if value > hi[0]:
            continue
        prev = sections[max(0,i-1)]
        following = sections[min(len(sections)-1,i+2)]
        length = hi[0]-lo[0]
        t = (value-lo[0])/length
        values = []
        for a,b,p,n in zip(lo[1:],hi[1:],prev[1:],following[1:]):
            da = length*(b-p)/(hi[0]-prev[0])
            db = length*(n-a)/(following[0]-lo[0])
            lerp = (2*t**3-3*t*t+1)*a + (-2*t**3+3*t*t)*b
            values.append(min(max(a,b),max(min(a,b),lerp+(t**3-2*t*t+t)*da+(t**3-t*t)*db)))
        return tuple(values)
    return sections[-1][1:]


def at(x, z, depth):
    return Vector((x,-depth,z))


def linear(hex_color):
    rgb = [int(hex_color[i:i+2],16)/255 for i in (0,2,4)]
    return [c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in rgb]


def paint(name, hex_color, roughness=.82, unlit=False):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    color = (*linear(hex_color),1)
    material.diffuse_color = color
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Specular IOR Level"].default_value = .24
    if unlit:
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        emission = nodes.new("ShaderNodeEmission")
        emission.inputs["Color"].default_value = color
        # Blender's glTF exporter recognizes the camera-ray mix as KHR_materials_unlit.
        light_path = nodes.new("ShaderNodeLightPath")
        mix = nodes.new("ShaderNodeMixShader")
        links.new(light_path.outputs["Is Camera Ray"],mix.inputs[0])
        links.new(shader.outputs[0],mix.inputs[1])
        links.new(emission.outputs[0],mix.inputs[2])
        links.new(mix.outputs[0],nodes.get("Material Output").inputs["Surface"])
    return material


def origin(obj):
    result = Vector((0,0,0))
    while obj:
        result += obj.location
        obj = obj.parent
    return result


def node(name, parent=None, location=(0,0,0)):
    obj = bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = Vector(location)-origin(parent)
    obj.empty_display_size = .035
    return obj


def mesh(name, coords, faces, mat, parent):
    data = bpy.data.meshes.new(name)
    anchor = origin(parent)
    data.from_pydata([Vector(v)-anchor for v in coords],[],faces)
    data.update()
    obj = bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    data.materials.append(mat)
    for polygon in data.polygons:
        polygon.use_smooth = True
    return obj


def rings(rows, count, reverse=False, caps=True):
    faces = []
    for row in range(rows-1):
        for i in range(count):
            a = row*count+i
            b = row*count+(i+1)%count
            quad = (a,b,b+count,a+count)
            faces.append(quad[::-1] if reverse else quad)
    if caps:
        bottom = tuple(range(count))[::-1]
        top = tuple(range((rows-1)*count,rows*count))
        faces.extend((bottom[::-1],top[::-1]) if reverse else (bottom,top))
    return faces


def profile(name, points, mat, parent, cx=0, rows=28, count=48):
    coords = []
    for row in range(rows):
        z = points[0][0] + (points[-1][0]-points[0][0])*row/(rows-1)
        half,depth,center = sample(points,z)
        for i in range(count):
            angle = tau*i/count
            coords.append(at(cx+half*sin(angle),z,center+depth*cos(angle)))
    return mesh(name,coords,rings(rows,count),mat,parent)


def bulb(name, center, size, mat, parent):
    x,z,d = center
    w,h,r = size
    points = []
    for i in range(17):
        a = pi*(i+.0001)/16.0002-pi/2
        points.append((z+h*sin(a),w*cos(a),r*cos(a),d))
    return profile(name,points,mat,parent,cx=x,rows=15,count=24)


def tube(name, path, mat, parent):
    # Stations are a world-space center and the radius perpendicular to the arm.
    centers = [Vector(center) for center,radius in path]
    points = []
    count = 28
    for i, (center,(_,radius)) in enumerate(zip(centers,path)):
        axis = (centers[min(i+1,len(centers)-1)]-centers[max(i-1,0)]).normalized()
        width = axis.cross(Vector((0,-1,0))).normalized()
        depth = axis.cross(width)
        for j in range(count):
            angle = tau*j/count
            points.append(center + radius*(width*cos(angle)+depth*sin(angle)))
    return mesh(name,points,rings(len(path),count),mat,parent)


def front_surface(profile_points,x,z):
    width,depth,offset = sample(profile_points,z)
    return offset+depth*sqrt(max(0,1-(x/width)**2))


def decal(name, x, z, w, h, mat, parent, lift=.0018, mound=0, triangle=False, shape=FACE):
    rows,count = 7,48
    coords = []
    for j in range(rows):
        radius = (j+.0005)/(rows-1+.0005)
        for i in range(count):
            angle = tau*i/count
            outline = radius*(1+.117*cos(3*(angle-pi/2))) if triangle else radius
            vx,vz = x+w*cos(angle)*outline,z+h*sin(angle)*outline
            depth = front_surface(shape,vx,vz)+lift+mound*(1-radius**2)**1.3
            coords.append(at(vx,vz,depth))
    faces = rings(rows,count,reverse=True,caps=False)
    faces.append(tuple(range(count)))
    return mesh(name,coords,faces,mat,parent)


def line(name, cx, cz, half, curve, width, mat, parent, lift=.0025, shape=FACE):
    coords = []
    rows = 33
    for i in range(rows):
        t = 2*i/(rows-1)-1
        x = cx+half*t
        height = cz+curve*t*t
        radius = max(.012,sqrt(max(0,1-((max(0,abs(t)-.82))/.18)**2)))*width
        coords.extend(at(x,z,front_surface(shape,x,z)+lift) for z in (height-radius,height+radius))
    return mesh(name,coords,[(2*i,2*i+2,2*i+3,2*i+1) for i in range(rows-1)],mat,parent)


def bob(parent, hair, lining, shape=HAIR):
    rows,count = 40,84
    coords = []
    for row in range(rows):
        u = row/(rows-1)
        for col in range(count):
            degree = 360*col/count-180
            angle = degree*pi/180
            floor, = sample(HAIRLINE,degree)
            z = 2.04-(2.04-floor)*(1-cos(u*pi/2))
            w,d,c = sample(shape,z)
            # Broad swept panels share the same smooth cap and turned lower edge.
            side = angle+.105*sin(u*pi)*max(0,cos(angle))
            sweep = -.39+.82*(1-u)
            crest = .041*exp(-((angle-sweep)/.44)**2)*sin(pi*u*.70)
            part = .015*exp(-((degree-25)/9)**2)*sin(pi*u*.68)
            ridge = crest-part
            low = min(1,max(0,(1.22-z)/.19))
            tuck = .026*low*low*exp(-((abs(degree)-77)/37)**2)
            coords.append(at(.036*(1-u)**2+(w+ridge-tuck)*sin(side),z,c+(d+ridge-tuck)*cos(side)))

    def inner(point):
        x,y,z = point
        bottom = min(1,max(0,(1.22-z)/.19))
        return Vector((x*(.950-.036*bottom),y*(.924-.020*bottom),z-.018+.056*bottom))

    # Two connecting rings roll the brown outer surface underneath before the
    # dark lining starts. This keeps the underside from reading as a flat shelf.
    for bend in (.33,.67):
        for col in range(count):
            rim = coords[(rows-1)*count+col]
            rolled = rim.lerp(inner(rim),bend)
            rolled.z -= min(.021,.075*max(0,1.32-rim.z))*sin(pi*bend)
            coords.append(rolled)
    for row in range(rows-1,-1,-1):
        for col in range(count):
            coords.append(inner(coords[row*count+col]))
    faces = rings(rows*2+2,count,reverse=True)
    cap = mesh("Rounded bob with swept fringe",coords,faces,hair,parent)
    cap.data.materials.append(lining)
    for face in cap.data.polygons[(rows+1)*count:-2]:
        face.material_index = 1


def joy_smile(parent, material, shape):
    columns, rows = 41, 7
    coords = []
    for col in range(columns):
        unit = 2*col/(columns-1)-1
        x = .099*unit
        upper = 1.242+.023*unit**2
        lower = 1.159+.101*unit**2
        mid = (upper+lower)/2
        radius = (upper-lower)/2*sqrt(max(.0001,1-unit**10))
        for row in range(rows):
            z = mid+radius*(2*row/(rows-1)-1)
            coords.append(at(x,z,front_surface(shape,x,z)+.0025))
    faces = []
    for col in range(columns-1):
        for row in range(rows-1):
            a = col*rows+row
            faces.append((a,a+rows,a+rows+1,a+1))
    mesh("Joy mouth",coords,faces,material,parent)


def face_parts(head, mat, shape):
    normal = node("FaceSmile",head,origin(head))
    joy = node("FaceJoy",head,origin(head))
    explain = node("FaceExplain",head,origin(head))
    for side in (-1,1):
        x = .201*side
        decal("Coral cheek",.304*side,1.270,.063,.043,mat["blush"],head,.002,shape=shape)
        for expression in (normal,explain):
            decal("Oval eye",x,1.426,.051,.104,mat["ink"],expression,shape=shape)
            decal("Single cream catchlight",x-.010,1.470,.013,.017,mat["light"],expression,.0035,shape=shape)
        line("Closed smiling eye",x,1.448,.059,-.047,.013,mat["ink"],joy,shape=shape)
    nose_depth = .023 if shape is VOLUMETRIC_FACE else .030
    decal("Soft triangular nose",0,1.337,.037,.033,mat["nose"],head,.0015,mound=nose_depth,triangle=True,shape=shape)
    line("Small smile",0,1.201,.084,.044,.012,mat["ink"],normal,shape=shape)
    line("Explain smile",0,1.211,.074,.031,.011,mat["ink"],explain,shape=shape)
    line("Raised brow",.204,1.583,.047,-.017,.008,mat["ink"],explain,shape=shape)
    joy_smile(joy,mat["mouth"],shape)
    for expression in (joy,explain):
        expression.hide_set(True)


def cloth_panel(name,parent,material,points,center,bounds,depth,rounded=1):
    rows,segments = 8,40
    coords = []
    for i in range(rows):
        r = (i+.001)/(rows-1+.001)
        for j in range(segments):
            a = tau*j/segments
            x = center[0]+bounds[0]*r*(1 if cos(a)>=0 else -1)*abs(cos(a))**rounded
            z = center[1]+bounds[1]*r*(1 if sin(a)>=0 else -1)*abs(sin(a))**rounded
            d = front_surface(points,x,z)+.001+depth*sqrt(max(0,1-r**4))
            coords.append(at(x,z,d))
    faces = rings(rows,segments,reverse=True,caps=False)
    faces.append(tuple(range(segments)))
    mesh(name,coords,faces,material,parent)


def body(root, mat, volumetric):
    tunic = VOLUMETRIC_TUNIC if volumetric else TUNIC
    profile("Rounded A-line mint tunic",tunic,mat["mint"],root,rows=42 if volumetric else 28)
    bulb("Almost hidden neck",(0,1.014,-.013 if volumetric else 0),
         (.105,.046,.102) if volumetric else (.107,.053,.085), mat["skin"],root)
    for side in (-1,1):
        cloth_panel("Round ivory collar",root,mat["ivory"],tunic,
                    (side*.077,.946),(.085,.060),.023)
        cloth_panel("Rounded pocket",root,mat["seam"],tunic,
                    (side*.179,.545),(.062,.059),.017,.50)
    def surface_depth(x,z,original,offset):
        return front_surface(tunic,x,z)+offset if volumetric else original

    for z in (.822,.711):
        bulb("Cream button",(0,z,surface_depth(0,z,.150,.009)),(.031,.031,.018),mat["ivory"],root)
    flower_depth = surface_depth(.129,.824,.163,.016)
    for i in range(8):
        angle = tau*i/8
        x, z = .129+.045*cos(angle), .824+.045*sin(angle)
        bulb("Sunflower petal",(x,z,surface_depth(x,z,flower_depth,.017)),
             (.028,.028,.014),mat["yellow"],root)
    bulb("Sunflower centre",(.129,.824,flower_depth+.024),(.032,.032,.018),mat["seed"],root)
    bulb("Name badge clip",(.128,.757,surface_depth(.128,.757,.163,.013)),(.013,.025,.012),mat["seed"],root)
    cloth_panel("Ivory name badge",root,mat["ivory"],tunic,(.129,.712),(.065,.041),.035,.36)
    cloth_panel("Name badge inset",root,mat["badge"],tunic,(.128,.716),(.044,.011),.036,.43)
    for side,label in ((-1,"L"),(1,"R")):
        leg = node("Leg"+label,root,at(side*.112,.466,0))
        x = side*.114
        trousers = ((.098,.061,.075,0),(.115,.101,.101,0),(.202,.105,.118,-.005),
                    (.355,.111,.126,-.009),(.456,.103,.114,-.012),(.486,.086,.080,-.010)) if volumetric else (
                    (.098,.061,.063,0),(.112,.103,.087,0),(.192,.105,.096,-.002),
                    (.388,.112,.104,-.009),(.486,.086,.080,-.010))
        profile("Cream trouser leg",trousers,mat["linen"],leg,cx=x,rows=28)
        shoe = ((0,.068,.087,.024),(.010,.098,.132,.032),(.049,.104,.150,.040),
                (.084,.102,.141,.041),(.117,.076,.109,.021),
                (.142,.027,.050,.002),(.149,.004,.004,0)) if volumetric else (
                (0,.068,.078,.024),(.010,.098,.121,.030),
                (.047,.103,.137,.036),(.088,.094,.129,.031),(.119,.060,.072,.006),
                (.130,.005,.005,0))
        profile("Rounded teal shoe",shoe,mat["teal"],leg,cx=x,rows=25)
        profile("Teal outsole", ((.009,.070,.100,.032),(.016,.099,.128,.032),
                (.032,.103,.134,.035),(.042,.096,.119,.034)),
                mat["sole"],leg,cx=x,rows=13)


def arms(root, mat, volumetric):
    for side,label in ((-1,"L"),(1,"R")):
        side_offset = .014 if volumetric else 0
        front_offset = .017 if volumetric else 0

        def arm_point(x,z,d):
            return at(side*(x+side_offset),z,d+front_offset)

        shoulder_pos = arm_point(.222,.895,-.006)
        elbow_pos = arm_point(.319,.739,.002)
        wrist_pos = arm_point(.381,.609,.019)
        shoulder = node("Shoulder"+label,root,shoulder_pos)
        elbow = node("Elbow"+label,shoulder,elbow_pos)
        wrist = node("Wrist"+label,elbow,wrist_pos)
        sleeve_start = .082 if volumetric else .064
        tube("Rounded mint sleeve",[(shoulder_pos,sleeve_start),(arm_point(.252,.856,-.002),.094),
             (arm_point(.288,.796,.001),.089),(arm_point(.303,.767,.002),.079),
             (arm_point(.305,.759,.002),.073)],mat["mint"],shoulder)
        tube("Rounded short forearm",[(arm_point(.293,.795,.003),.012),
             (arm_point(.303,.777,.004),.043),(arm_point(.311,.755,.004),.057),(elbow_pos,.066),
             (arm_point(.351,.676,.009),.064),(wrist_pos,.049),
             (arm_point(.390,.589,.024),.034),(arm_point(.398,.578,.026),.009)],mat["skin"],elbow)
        bulb("Mitten palm",(side*(.394+side_offset),.565,.035+front_offset),
             (.090,.088,.081) if volumetric else (.089,.086,.065),mat["skin"],wrist)
        bulb("Rounded mitten thumb",(side*(.345+side_offset),.588,.060+front_offset),
             (.035,.041,.040) if volumetric else (.034,.041,.033),mat["skin"],wrist)


def author(volumetric=False, skin=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    skin = skin or (SKIN_B if volumetric else "FFC89D")
    p = {
        "skin":paint("Warm soft peach",skin,.91 if volumetric else .82),
        "nose":paint("Soft peach nose" if volumetric else "Peach orange nose",
                     "EAB4A1" if volumetric else "F39B64"),
        "hair":paint("Matte warm chestnut","6B422D"), "lining":paint("Shadow inside bob","69422E",.88),
        "ink":paint("Graphic dark umber","382217",unlit=True),
        "light":paint("One eye highlight","FFF6E8",unlit=True),
        "blush":paint("Soft apricot cheeks","ECA08F" if volumetric else "FFA36E",unlit=True),
        "mouth":paint("Joy warm auburn","9D4836",unlit=True),
        "mint":paint("Mint fabric","9DC7A4"), "seam":paint("Pocket mint","93BC9D"),
        "ivory":paint("Warm white collar and buttons","FFF3D8"),
        "linen":paint("Cream trousers","FFF1D4"),
        "teal":paint("Muted teal shoes","376B63"), "sole":paint("Soft teal soles","325C55"),
        "yellow":paint("Golden sunflower","F9B940"), "seed":paint("Sunflower centre","7C4B2B"),
        "badge":paint("Light linen card","DCD1BA"),
    }
    if volumetric:
        skin_shader = p["skin"].node_tree.nodes.get("Principled BSDF")
        skin_shader.inputs["Specular IOR Level"].default_value = .16
    root = node("MinjiSimple")
    head = node("HeadPivot",root,at(0,1.046,0))
    face = VOLUMETRIC_FACE if volumetric else FACE
    profile("Round head",face,p["skin"],head,rows=72 if volumetric else 64,count=84)
    for side in (-1,1):
        bulb("Small round ear",(side*.431,1.274,.116),(.042,.066,.051),p["skin"],head)
    bob(head,p["hair"],p["lining"],VOLUMETRIC_HAIR if volumetric else HAIR)
    face_parts(head,p,face)
    body(root,p,volumetric)
    arms(root,p,volumetric)
    return root


def expression(scene_face):
    for label in ("FaceSmile","FaceJoy","FaceExplain"):
        group = bpy.data.objects[label]
        show = label == scene_face
        for feature in group.children:
            feature.hide_render = not show
            feature.hide_set(not show)


def animation(scene):
    # The shoulder settles outside the cheek while the wrist makes two sweeps.
    # Angles are shoulder Y/X/Z, elbow Y, wrist Y, and head Y.
    keyframes = (
        (1,0,0,0,0,0,0), (10,0,0,0,0,0,0), (26,-74,-30,16,-16,0,-4),
        (34,-76,-31,17,-17,-21,-5), (42,-75,-31,17,-15,21,-5),
        (50,-76,-31,17,-17,-21,-5), (58,-75,-31,17,-15,21,-4),
        (68,-73,-30,16,-16,0,-4), (78,-70,-28,15,-14,0,-3),
        (101,0,0,0,0,0,0), (121,0,0,0,0,0,0),
    )
    scene.render.fps = 30
    scene.frame_start = 1
    scene.frame_end = 121
    parts = [(bpy.data.objects[name],axis) for name,axis in
             (("ShoulderR",1),("ShoulderR",0),("ShoulderR",2),("ElbowR",1),("WristR",1),("HeadPivot",1))]
    for frame,*angles in keyframes:
        for (part,axis),angle in zip(parts,angles):
            part.rotation_euler[axis] = angle*pi/180
            part.keyframe_insert(data_path="rotation_euler",index=axis,frame=frame)
    for name,frame in (("Rest",1),("Lift",10),("Wave",26),("Settle",78)):
        scene.timeline_markers.new(name,frame=frame)
    scene.frame_set(1)


def view_camera(camera, focus, yaw, scale, elevation=.115):
    angle = yaw*pi/180
    target = Vector(focus)
    camera.location = target+Vector((2.95*sin(angle),-2.95*cos(angle),elevation))
    camera.rotation_euler = (target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.ortho_scale = scale


def review_studio(clay=False, neutral=False):
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new("Warm cream studio")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (.36,.36,.36,1) if neutral else (.52,.44,.36,1)
    bg.inputs[1].default_value = .57 if neutral else .78
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 6
    scene.render.resolution_x = scene.render.resolution_y = 576
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard" if neutral else "AgX"
    scene.view_settings.look = "None" if neutral else "AgX - Medium High Contrast"
    if clay:
        scene.view_layers[0].material_override = paint("Neutral clay", "D5C6B4")
    data = bpy.data.cameras.new("Orthographic review")
    data.type = "ORTHO"
    camera = bpy.data.objects.new(data.name,data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    for title,where,power,size in (
        ("Broad key",(-2.1,-3.2,4.6),205 if neutral else 480,4.0),
        ("Soft fill",(1.8,-2.8,2.6),112 if neutral else 175,3.2),
        ("Shoulder rim",(1.6,1.2,3.5),100 if neutral else 160,2.8),
    ):
        data = bpy.data.lights.new(title,type="AREA")
        data.energy = power
        data.shape = "DISK"
        data.size = size
        obj = bpy.data.objects.new(title,data)
        scene.collection.objects.link(obj)
        obj.location = where
        obj.rotation_euler = (Vector((0,0,1.2))-obj.location).to_track_quat("-Z","Y").to_euler()
    return scene, camera


def renders(prefix, second_pass=False, clay=False):
    scene, camera = review_studio(clay=clay)
    expression("FaceSmile")
    views = [
        ("front",0,(0,0,1.025),2.24), ("face-45",45,(0,-.025,1.51),1.28),
    ]
    if second_pass or clay:
        views.extend((("45",45,(0,0,1.025),2.24),("back",180,(0,0,1.025),2.24)))
    for label,yaw,target,scale in views:
        view_camera(camera,target,yaw,scale)
        scene.render.filepath = str(ARTIFACTS/f"{prefix}-{label}.png")
        bpy.ops.render.render(write_still=True)
    if not second_pass:
        return
    samples = (
        ("greet","FaceSmile",34), ("wave-out","FaceSmile",42),
        ("settle","FaceSmile",88), ("joy","FaceJoy",1), ("explain","FaceExplain",1),
    )
    for label,face,frame in samples:
        scene.frame_set(frame)
        expression(face)
        view_camera(camera,(.065,0,1.427),11,1.42)
        scene.render.filepath = str(ARTIFACTS/f"{prefix}-{label}.png")
        bpy.ops.render.render(write_still=True)


def volume_diagnostics(prefix, full_model):
    import json

    scene, camera = review_studio(neutral=True)
    scene.frame_set(1)
    expression("FaceSmile")
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    names = ("Round head","Rounded A-line mint tunic")
    sizes = {name: tuple(bpy.data.objects[name].dimensions) for name in names}
    (VOLUME_ARTIFACTS/f"{prefix}-bounds.json").write_text(json.dumps(sizes))
    if full_model:
        for angle,label in ((0,"front"),(90,"side"),(45,"45"),(180,"back")):
            view_camera(camera,(0,.07,1.025),angle,2.25,elevation=0)
            scene.render.filepath = str(VOLUME_ARTIFACTS/f"{prefix}-{label}.png")
            bpy.ops.render.render(write_still=True)

    head_name, tunic_name = names
    for obj in meshes:
        obj.hide_render = obj.name != head_name
    view_camera(camera,(0,.11,1.50),90,1.22,elevation=0)
    scene.render.filepath = str(VOLUME_ARTIFACTS/f"{prefix}-bare-side.png")
    bpy.ops.render.render(write_still=True)

    for obj in meshes:
        obj.hide_render = obj.name != tunic_name
    camera.location = (0,.025,3)
    camera.rotation_euler = (0,0,0)
    camera.data.ortho_scale = .80
    scene.render.filepath = str(VOLUME_ARTIFACTS/f"{prefix}-tunic-top.png")
    bpy.ops.render.render(write_still=True)


def volume_skin_trials():
    author(volumetric=True)
    scene,camera = review_studio(neutral=True)
    expression("FaceSmile")
    view_camera(camera,(.015,.08,1.39),7,1.46,elevation=0)
    material = bpy.data.materials["Warm soft peach"]
    shader_color = material.node_tree.nodes["Principled BSDF"].inputs["Base Color"]
    for label,tone in (("A",SKIN_A),("B",SKIN_B)):
        shader_color.default_value = (*linear(tone),1)
        scene.render.filepath = str(VOLUME_ARTIFACTS/f"skin-{label}.png")
        bpy.ops.render.render(write_still=True)


def modeling_view(root):
    scene = bpy.context.scene
    scene.name = "Minji simple · editable character and greeting"
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.overlay.show_overlays = False
                space.shading.color_type = "MATERIAL"
                view = space.region_3d
                view.view_rotation = Vector((.13,-1,.07)).to_track_quat("Z","Y")
                view.view_location = (0,0,1.04)
                view.view_distance = 3
                view.view_perspective = "ORTHO"


def open_model():
    bpy.ops.wm.open_mainfile(filepath=str(OUTPUT),load_ui=True,use_scripts=False)


def export_model(path=EXPORT):
    if path.exists():
        raise FileExistsError(path)
    window = bpy.context.window_manager.windows[0]
    area = next(area for area in window.screen.areas if area.type == "VIEW_3D")
    with bpy.context.temp_override(window=window,area=area):
        bpy.ops.export_scene.gltf(
            filepath=str(path),export_format="GLB",export_animation_mode="ACTIVE_ACTIONS",
            export_nla_strips_merged_animation_name="MinjiWave",use_visible=False,
            export_apply=False,export_morph=False,export_extras=False,
        )


def build(stage):
    ARTIFACTS.mkdir(parents=True,exist_ok=True)
    if stage == "draft":
        author()
        renders("draft")
        return
    if stage == "refined":
        author()
        renders("refined")
        return
    if stage == "export":
        open_model()
        export_model()
        renders("blender",second_pass=True)
        open_model()
        return
    if stage != "final":
        raise ValueError(stage)
    if OUTPUT.exists() or EXPORT.exists():
        raise FileExistsError("Review model or GLB already exists.")
    root = author()
    expression("FaceSmile")
    animation(bpy.context.scene)
    window = bpy.context.window_manager.windows[0]
    with bpy.context.temp_override(window=window):
        modeling_view(root)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT),compress=True)
    export_model()
    renders("blender",second_pass=True)
    open_model()


def build_volume(stage):
    VOLUME_ARTIFACTS.mkdir(parents=True,exist_ok=True)
    if stage == "study":
        open_model()
        volume_diagnostics("before",full_model=True)
        author(volumetric=True)
        volume_diagnostics("draft",full_model=True)
        volume_skin_trials()
        return
    if stage != "final":
        raise ValueError(stage)
    if VOLUME_OUTPUT.exists() or VOLUME_EXPORT.exists():
        raise FileExistsError("Keep the existing volumetric review model and export.")
    root = author(volumetric=True)
    expression("FaceSmile")
    animation(bpy.context.scene)
    window = bpy.context.window_manager.windows[0]
    with bpy.context.temp_override(window=window):
        modeling_view(root)
        bpy.context.scene.name = "Minji simple · volume and neutral peach review"
        bpy.ops.wm.save_as_mainfile(filepath=str(VOLUME_OUTPUT),compress=True)
    export_model(VOLUME_EXPORT)
    volume_diagnostics("after",full_model=True)
    open_model()
    volume_diagnostics("before",full_model=True)
    volume_skin_trials()
    bpy.ops.wm.open_mainfile(filepath=str(VOLUME_OUTPUT),load_ui=True,use_scripts=False)
