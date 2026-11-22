"""Build the connected review model in the Blender application.

Run build(publish=False) for neutral renders without replacing any source.
Run build(publish=True) to write the separate native model and Unity export.
"""
from array import array
from collections import Counter
import json
from math import atan2, cos, pi, sin, sqrt, tan, tau
from pathlib import Path
import runpy
from struct import pack
from tempfile import TemporaryDirectory
import zlib

import bmesh
import bpy
from mathutils import Quaternion, Vector

BASE = runpy.run_path(str(Path(__file__).with_name("build_minji_simple.py")))
ROOT = BASE["ROOT"]
SOURCE = ROOT / "art/source/minji-simple-connected.blend"
EXPORT = ROOT / "unity/Assets/Editor/HospitalArt/minji-simple-connected.glb"
REVIEW = ROOT / "artifacts/minji-simple-connected"
TUNIC = BASE["VOLUMETRIC_TUNIC"]
FACE = BASE["VOLUMETRIC_FACE"]
at, mesh, rings, sample = (BASE[name] for name in ("at", "mesh", "rings", "sample"))
FRONT = Vector((0, -1, 0))
SIDES = ((-1, "L"), (1, "R"))


def smooth(value):
    t = max(0, min(1, value))
    return t * t * (3 - 2 * t)


def angles(index, count):
    return tau * index / count


def shape_nose(x, z):
    u, v = x / .037, (z - 1.337) / .033
    theta = atan2(v, u)
    radius = sqrt(u*u + v*v) / (1 + .117 * cos(3 * (theta - pi / 2)))
    return max(0, 1 - radius*radius)**2


def skin_texture(head, material):
    # Front-projected pigment packed into the .blend and the GLB as sRGB.
    size = 384
    skin = BASE["linear"](BASE["SKIN_B"])
    coral = BASE["linear"]("ECA08F")
    nose = BASE["linear"]("EAB4A1")
    pixels = bytearray()

    def channel(value):
        encoded = 12.92*value if value <= .0031308 else 1.055*value**(1/2.4)-.055
        return round(encoded * 255)

    for row in range(size):
        z = 2 - row/(size-1)
        pixels.append(0)
        for column in range(size):
            x = column/(size-1) - .5
            cheek = sqrt(((abs(x)-.304)/.063)**2 + ((z-1.270)/.043)**2)
            blush = .77 * smooth((1.05-cheek)/.27)
            warmth = .46 * shape_nose(x, z)
            pixels.extend(channel(base+(pink-base)*blush+(warm-base)*warmth)
                          for base,pink,warm in zip(skin,coral,nose))

    def chunk(tag, data):
        payload = tag + data
        return pack(">I",len(data)) + payload + pack(">I",zlib.crc32(payload))

    image_bytes = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR",pack(">IIBBBBB",size,size,8,2,0,0,0))
                   + chunk(b"IDAT",zlib.compress(pixels,9)) + chunk(b"IEND",b""))
    with TemporaryDirectory() as directory:
        path = Path(directory) / "Minji-skin-peach-and-pigment.png"
        path.write_bytes(image_bytes)
        image = bpy.data.images.load(str(path))
        image.pack()
        image.filepath = "//Minji-skin-peach-and-pigment.png"
    layers = head.data.uv_layers.new(name="Skin pigment")
    coords = array("f")
    for corner in head.data.loops:
        x,y,z = head.data.vertices[corner.vertex_index].co
        z += 1.046
        center = sample(FACE,z)[2]
        # The rear maps to an untouched strip of the peach texture.
        coords.extend((x+.5 if -y >= center else .5, z-1))
    layers.data.foreach_set("uv", coords)

    pigment = material.copy()
    pigment.name = "Warm soft peach · embedded blush"
    shader = pigment.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (1,1,1,1)
    texture = pigment.node_tree.nodes.new("ShaderNodeTexImage")
    texture.label = "sRGB • skin, cheeks and nose"
    texture.image = image
    pigment.node_tree.links.new(texture.outputs["Color"],shader.inputs["Base Color"])
    head.data.materials[0] = pigment


def build_head(old):
    head, skin = old.parent, old.data.materials[0]
    rows, count = 129, 152
    coords = []
    for row in range(rows):
        z = FACE[0][0] + (FACE[-1][0]-FACE[0][0])*row/(rows-1)
        width, depth, center = sample(FACE,z)
        for column in range(count):
            angle = angles(column,count)
            x, d = width*sin(angle), center+depth*cos(angle)
            if cos(angle) > 0:
                ear_angle = abs(atan2(sin(angle),cos(angle)))
                ear = smooth(1 - ((ear_angle-1.25)/.31)**2 - ((z-1.274)/.073)**2)
                d += .023*shape_nose(x,z) + .018*ear
                x += (.052 if x > 0 else -.052)*ear
            coords.append(at(x,z,d))
    bpy.data.objects.remove(old,do_unlink=True)
    for item in tuple(head.children):
        if item.name.startswith(("Small round ear","Soft triangular nose","Coral cheek")):
            bpy.data.objects.remove(item,do_unlink=True)
    surface = mesh("Round head",coords,rings(rows,count),skin,head)
    skin_texture(surface,skin)
    return surface


def rest_joints():
    return {prefix+label: Vector(BASE["origin"](bpy.data.objects[prefix+label]))
            for _,label in SIDES for prefix in ("Shoulder","Elbow","Wrist")}


def armature(root, joints):
    data = bpy.data.armatures.new("Minji arm skeleton")
    rig = bpy.data.objects.new("ArmRig",data)
    bpy.context.collection.objects.link(rig)
    rig.parent = root
    rig.show_in_front = True
    window = bpy.context.window_manager.windows[0]
    area = next(area for area in window.screen.areas if area.type == "VIEW_3D")
    with bpy.context.temp_override(window=window,area=area,active_object=rig,object=rig):
        bpy.context.view_layer.objects.active = rig
        rig.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        torso = data.edit_bones.new("Tunic")
        torso.head,torso.tail = (0,0,.48),(0,0,.91)
        for _,label in SIDES:
            parent = torso
            shoulder,elbow,wrist = [joints[prefix+label] for prefix in ("Shoulder","Elbow","Wrist")]
            palm = wrist + (wrist-elbow).normalized() * .102
            for name,head,tail in zip(("Shoulder","Elbow","Wrist"),(shoulder,elbow,wrist),(elbow,wrist,palm)):
                bone = data.edit_bones.new(name+label)
                bone.head,bone.tail = head,tail
                bone.parent = parent
                bone.use_connect = parent != torso
                parent = bone
        bpy.ops.object.mode_set(mode="OBJECT")
    rig.select_set(False)
    return rig


def binding(obj, rig, weights):
    for name in sorted({name for row in weights for name in row}):
        obj.vertex_groups.new(name=name)
    for index,row in enumerate(weights):
        for name,value in row.items():
            if value > 1e-5:
                obj.vertex_groups[name].add([index],value,"REPLACE")
    modifier = obj.modifiers.new("Armature · weighted joints","ARMATURE")
    modifier.object = rig


def cleanup_winding(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()


def tuned_tunic(root, rig, joints, old):
    material = old.data.materials[0]
    bpy.data.objects.remove(old,do_unlink=True)
    z = sorted(set([v[0] for v in TUNIC] +
                   [.778 + i*.025 for i in range(9)] +
                   [.412 + i*(1.015-.412)/40 for i in range(41)]))
    low,high = z.index(.778),z.index(.778+8*.025)
    # Use regular rows and columns at the two side openings so the sleeve rings
    # share their vertices with the chest and back.
    count, spread = 64, 4
    coords, weights, faces = [],[],[]
    windows = [(side,label,count//4 if side>0 else 3*count//4) for side,label in SIDES]
    for i,row_z in enumerate(z):
        half,depth,center = sample(TUNIC,row_z)
        for j in range(count):
            theta = angles(j,count)
            coords.append(at(half*sin(theta),row_z,center+depth*cos(theta)))
            row = {}
            for _,label,column in windows:
                near_axis = 1-smooth((abs(j-column)-spread)/5)
                near_shoulder = smooth((row_z-.714)/.13)*(1-smooth((row_z-.943)/.070))
                row["Shoulder"+label] = .30*near_axis*near_shoulder
            row["Tunic"] = 1-sum(row.values())
            weights.append(row)
    for i in range(len(z)-1):
        for j in range(count):
            if low <= i < high and any(col-spread <= j < col+spread for _,_,col in windows):
                continue
            k = (j+1)%count
            faces.append((i*count+j,i*count+k,(i+1)*count+k,(i+1)*count+j))
    faces.extend((tuple(reversed(range(count))),tuple(range((len(z)-1)*count,len(z)*count))))

    transition = {}
    for _,label,column in windows:
        left,right = column-spread,column+spread
        border = ([low*count+j for j in range(left,right)] +
                  [i*count+right for i in range(low,high)] +
                  [high*count+j for j in range(right,left,-1)] +
                  [i*count+left for i in range(high,low,-1)])
        shoulder, elbow = [joints[name+label] for name in ("Shoulder","Elbow")]
        axis = (elbow-shoulder).normalized()
        cross = axis.cross(FRONT).normalized()
        depth = axis.cross(cross)
        # Ease the corners of the side opening, taper into the existing cuff,
        # and finish with a turned lining instead of a closed sleeve cap.
        for index in border:
            _,j = divmod(index,count)
            v = (coords[index].z-.878)/.100
            u = (j-column)/spread
            factor = min(1,1/sqrt(max(1e-6,u*u+v*v)))
            new_z = .878+.100*v*factor
            theta = angles(column+spread*u*factor,count)
            half,depth_at_z,center = sample(TUNIC,new_z)
            coords[index] = at(half*sin(theta),new_z,center+depth_at_z*cos(theta))
            transition[index] = 1
            shoulder_blend = .31 + .08 * (1-smooth((new_z-.805)/.145))
            weights[index] = {"Tunic":1-shoulder_blend,"Shoulder"+label:shoulder_blend}
        loop_count = len(border)
        end = shoulder.lerp(elbow,.88)
        circle = [cross*cos(angles(j,loop_count))+depth*sin(angles(j,loop_count))
                  for j in range(loop_count)]
        order = min(([(start+direction*j)%loop_count for j in range(loop_count)]
                     for start in range(loop_count) for direction in (-1,1)),
                    key=lambda ordering: sum((coords[v]-end-circle[k]*.076).length_squared
                                             for v,k in zip(border,ordering)))
        previous = border
        for blend,travel,radius,weight in ((.25,.17,.100,.45),(.55,.33,.098,.69),
                                           (.84,.57,.090,.94),(1,.75,.084,1),
                                           (1,.88,.076,1),(1,.90,.071,1),
                                           (1,.88,.066,1),(1,.81,.065,1)):
            center = shoulder.lerp(elbow,travel)
            current = []
            for idx,circle_index in zip(border,order):
                current.append(len(coords))
                coords.append(coords[idx].lerp(center + radius*circle[circle_index],blend))
                weights.append({"Tunic":1-weight,"Shoulder"+label:weight})
                if travel < .76:
                    transition[current[-1]] = 1-smooth((travel-.50)/.30)
            faces.extend((a,b,c,d) for a,b,c,d in zip(
                previous,previous[1:]+previous[:1],current[1:]+current[:1],current))
            previous = current
    # Discard the original surface inside each hole, including its unused vertices.
    used = sorted({v for face in faces for v in face})
    remap = {v:i for i,v in enumerate(used)}
    for index in used:
        if index >= len(z)*count or index in transition:
            continue
        i,j = divmod(index,count)
        distance = min(max(abs(j-column)-spread,low-i,i-high,0) for _,_,column in windows)
        if distance <= 3 and .736 < z[i] < 1.002:
            transition[index] = .88 * (1-distance/4)
    obj = mesh("Connected mint tunic and sleeves",[coords[v] for v in used],
               [tuple(remap[v] for v in face) for face in faces],material,root)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    shapers = {bm.verts[remap[v]]:strength for v,strength in transition.items()}
    for factor in (.47,-.43)*10:
        positions = {}
        for vertex,strength in shapers.items():
            around = [edge.other_vert(vertex).co for edge in vertex.link_edges]
            average = sum(around,Vector())/len(around)
            positions[vertex] = vertex.co.lerp(average,factor*strength)
        for vertex,position in positions.items():
            vertex.co = position
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    binding(obj,rig,[weights[v] for v in used])
    return obj


def connected_arm(root, rig, joints, side, label, material):
    shoulder,elbow,wrist = [joints[name+label] for name in ("Shoulder","Elbow","Wrist")]
    palm = at(side*.408,.565,.052)
    thumb = at(side*.359,.588,.077)
    # Axis centers and perpendicular radii. Extra stations straddle each pivot
    # so elbow flex and wrist rotation are distributed over a length of skin.
    sections = [
        (shoulder.lerp(elbow,.55),.011,.011,1,0),
        (shoulder.lerp(elbow,.66),.045,.043,1,0),
        (shoulder.lerp(elbow,.75),.054,.052,.97,0),
        (shoulder.lerp(elbow,.86),.060,.057,.91,0),
        (shoulder.lerp(elbow,.94),.064,.061,.72,0),
        (elbow,.066,.064,.51,0),
        (elbow.lerp(wrist,.12),.066,.064,.25,0),
        (elbow.lerp(wrist,.25),.065,.063,.06,0),
        (elbow.lerp(wrist,.48),.063,.061,0,0),
        (elbow.lerp(wrist,.68),.058,.056,0,.04),
        (elbow.lerp(wrist,.82),.052,.050,0,.17),
        (elbow.lerp(wrist,.93),.049,.048,0,.39),
        (wrist,.051,.050,0,.60),
        (wrist.lerp(palm,.19),.056,.054,0,.81),
        (wrist.lerp(palm,.43),.068,.062,0,.95),
        (wrist.lerp(palm,.70),.083,.074,0,1),
        (palm,.086,.080,0,1),
        (at(side*.417,.545,.055),.081,.076,0,1),
        (at(side*.421,.524,.056),.069,.064,0,1),
        (at(side*.421,.505,.056),.052,.048,0,1),
        (at(side*.420,.490,.056),.030,.029,0,1),
        (at(side*.419,.484,.056),.017,.017,0,1),
        (at(side*.418,.481,.056),.004,.004,0,1),
    ]
    coords,weights = [],[]
    count = 40
    for i,(center,w,d,upper,hand) in enumerate(sections):
        axis = (sections[min(i+1,len(sections)-1)][0]-sections[max(i-1,0)][0]).normalized()
        cross = axis.cross(FRONT).normalized()
        depth = axis.cross(cross)
        guide = thumb-center
        direction = (cross*cross.dot(guide)+depth*depth.dot(guide)).normalized()
        thumb_height = .046 * smooth(1-((center.z-.583)/.049)**2)
        for j in range(count):
            angle = angles(j,count)
            radial = cross*cos(angle)+depth*sin(angle)
            lobe = thumb_height*max(0,radial.dot(direction))**5
            coords.append(center+cross*w*cos(angle)+depth*d*sin(angle)+radial*lobe)
            weights.append({"Shoulder"+label:upper,"Elbow"+label:1-upper-hand,"Wrist"+label:hand})
    arm = mesh("Continuous skin arm "+label,coords,rings(len(sections),count),material,root)
    cleanup_winding(arm)
    binding(arm,rig,weights)
    return arm


def pose_bone(rig, name, rotation):
    bone = rig.pose.bones[name]
    axes = bone.bone.matrix_local.to_quaternion()
    bone.rotation_mode = "QUATERNION"
    bone.rotation_quaternion = axes.inverted() @ rotation @ axes


def transfer_greeting(rig, old):
    scene = bpy.context.scene
    for frame in range(scene.frame_start,scene.frame_end+1):
        scene.frame_set(frame)
        for name in ("ShoulderR","ElbowR","WristR"):
            pose_bone(rig,name,old[name].rotation_euler.to_quaternion())
            rig.pose.bones[name].keyframe_insert(data_path="rotation_quaternion",frame=frame,group=name)
    rig.animation_data.action.name = "Greeting · weighted shoulder, elbow and wrist"
    scene.frame_set(1)
    for _,label in SIDES:
        for joint in ("Wrist","Elbow","Shoulder"):
            bpy.data.objects.remove(old[joint+label],do_unlink=True)


def chest_details(root):
    # Keep the flower on the same side and conform each outline to the chest.
    for obj in tuple(root.children):
        if obj.name.startswith(("Sunflower petal","Sunflower centre","Name badge clip",
                                "Ivory name badge","Name badge inset","Cream button","Rounded pocket")):
            bpy.data.objects.remove(obj,do_unlink=True)
    paint = bpy.data.materials
    surface = BASE["front_surface"]
    panel = BASE["cloth_panel"]
    fabric = paint["Warm white collar and buttons"]
    flower_x, flower_z = .134,.832
    count = 24
    for petal in range(10):
        angle = angles(petal,10)
        points = []
        for row in range(15):
            t = row/14
            radius = .019+.043*t
            width = .016*(.56+.68*t)*max(.014,sin(pi*t))**.59
            h = .0046*max(.04,sin(pi*t))**.63
            for col in range(count):
                a = angles(col,count)
                offset = width*cos(a)
                x = flower_x+radius*cos(angle)-offset*sin(angle)
                z = flower_z+radius*sin(angle)+offset*cos(angle)
                points.append(at(x,z,surface(TUNIC,x,z)+.0032+h*sin(a)))
        obj = mesh("Flat sunflower teardrop",points,rings(15,count),paint["Golden sunflower"],root)
        cleanup_winding(obj)
    coords = []
    count = 56
    layers = ((.023,-.0015),(.026,.0030),(.0255,.0080),(.0225,.012),(.014,.013),(.001,.0133))
    for radius,height in layers:
        for col in range(count):
            a = angles(col,count)
            x,z = flower_x+radius*cos(a),flower_z+radius*sin(a)
            coords.append(at(x,z,surface(TUNIC,x,z)+height))
    center = mesh("Thin beveled sunflower center",coords,rings(len(layers),count),paint["Sunflower centre"],root)
    cleanup_winding(center)
    panel("Low ivory nameplate",root,fabric,TUNIC,(.134,.714),(.052,.027),.009,.32)
    panel("Nameplate inset",root,paint["Light linen card"],TUNIC,(.134,.716),(.035,.008),.010,.41)
    for z in (.822,.711):
        panel("Shallow cream button",root,fabric,TUNIC,(0,z),(.025,.025),.012)
    for side,_ in SIDES:
        panel("Low mint pocket",root,paint["Pocket mint"],TUNIC,(side*.179,.545),(.062,.059),.010,.50)


def author():
    root = BASE["author"](volumetric=True)
    scene = bpy.context.scene
    BASE["animation"](scene)
    head = build_head(bpy.data.objects["Round head"])
    skin = bpy.data.materials["Warm soft peach"]
    joints = rest_joints()
    old = {name:bpy.data.objects[name] for name in joints}
    for obj in tuple(bpy.data.objects):
        if obj.name.startswith(("Rounded mint sleeve","Rounded short forearm","Mitten palm","Rounded mitten thumb")):
            bpy.data.objects.remove(obj,do_unlink=True)
    rig = armature(root,joints)
    tunic = tuned_tunic(root,rig,joints,bpy.data.objects["Rounded A-line mint tunic"])
    arms = [connected_arm(root,rig,joints,side,label,skin) for side,label in SIDES]
    chest_details(root)
    transfer_greeting(rig,old)
    return root, [tunic,*arms,head]


def topology(objects):
    result = {}
    for obj in objects:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        remaining, components = set(bm.verts), 0
        while remaining:
            components += 1
            stack = [remaining.pop()]
            while stack:
                vert = stack.pop()
                for edge in vert.link_edges:
                    other = edge.other_vert(vert)
                    if other in remaining:
                        remaining.remove(other)
                        stack.append(other)
        links = Counter(len(edge.link_faces) for edge in bm.edges)
        assert components == 1 and set(links) <= {1,2},(obj.name,components,links)
        assert (links[1] > 0) == obj.name.startswith("Connected mint")
        groups = [sum(group.weight for group in vertex.groups) for vertex in obj.data.vertices]
        if obj.modifiers:
            assert all(abs(total-1)<.0001 for total in groups),obj.name
        result[obj.name] = dict(vertices=len(bm.verts),faces=len(bm.faces),components=components,
                                boundary_edges=links[1],nonmanifold_edges=sum(n for k,n in links.items() if k not in (1,2)))
        bm.free()
    return result


def render_views(prefix, detail_only=False):
    scene,camera = BASE["review_studio"](neutral=True)
    scene.cycles.samples = 16
    BASE["expression"]("FaceSmile")

    def capture(label, frame, focus, yaw, scale, elevation=0, abduction=0):
        scene.frame_set(frame)
        controller = None
        saved_action = None
        try:
            if abduction:
                rotation = Quaternion((0,1,0),-abduction*pi/180)
                rig = bpy.data.objects.get("ArmRig")
                controller = rig or bpy.data.objects["ShoulderR"]
                saved_action = controller.animation_data.action
                controller.animation_data.action = None
                if rig:
                    pose_bone(rig,"ShoulderR",rotation)
                else:
                    controller.rotation_euler.y = -abduction*pi/180
            BASE["view_camera"](camera, focus, yaw, scale, elevation)
            scene.render.filepath = str(REVIEW/f"{prefix}-{label}.png")
            bpy.ops.render.render(write_still=True)
        finally:
            if controller:
                controller.animation_data.action = saved_action

    capture("badge",1,(.106,-.22,.777),-17,.47,1.15)
    if detail_only:
        return
    capture("face",1,(0,-.22,1.375),18,1.02,.04)
    capture("shoulder",1,(.13,0,.81),44,.97,-1.1)
    capture("hand",34,(.46,-.10,.99),18,.72,-.22)
    capture("lift45",1,(.17,0,.86),35,1.33,-.8,45)
    capture("lift90",1,(.22,0,.87),35,1.48,-1.05,90)
    capture("wave",38,(.10,0,1.12),8,1.5,-.29)
    capture("back",1,(0,0,1.02),180,2.19)
    if prefix == "after":
        scene.render.resolution_x = scene.render.resolution_y = 432
        scene.cycles.samples = 12
        views = [(yaw,0) for yaw in (0,45,90,135,180,-135,-90,-45)]
        views.extend(((0,42),(45,42),(0,-25),(-135,42)))
        for i,(yaw,elevation) in enumerate(views,1):
            capture(f"view-{i:02}",1,(0,0,1.018),yaw,2.37,2.95*tan(elevation*pi/180))


def build(publish=False):
    REVIEW.mkdir(parents=True,exist_ok=True)
    if publish and (SOURCE.exists() or EXPORT.exists()):
        raise FileExistsError("Keep the existing source and GLB.")
    if not (REVIEW/"before-back.png").exists():
        bpy.ops.wm.open_mainfile(filepath=str(BASE["VOLUME_OUTPUT"]),load_ui=True,use_scripts=False)
        render_views("before")
    elif not (REVIEW/"before-badge.png").exists():
        bpy.ops.wm.open_mainfile(filepath=str(BASE["VOLUME_OUTPUT"]),load_ui=True,use_scripts=False)
        render_views("before",detail_only=True)
    root, objects = author()
    (REVIEW/"topology.json").write_text(json.dumps(topology(objects),indent=2))
    if publish:
        window = bpy.context.window_manager.windows[0]
        with bpy.context.temp_override(window=window):
            BASE["modeling_view"](root)
            bpy.context.scene.name = "Minji simple · continuous skin and uniform"
            for screen in bpy.data.screens:
                for area in screen.areas:
                    if area.type == "VIEW_3D":
                        area.spaces.active.shading.show_cavity = False
                        area.spaces.active.shading.show_object_outline = False
            bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE),compress=True)
        BASE["export_model"](EXPORT)
    render_views("after")
    if publish:
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=True,use_scripts=False)
