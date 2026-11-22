"""Build the separate Minji v3 sculpt in Blender. Run in the open app with runpy.

`run("draft")` renders neutral studies under artifacts. `run("final")` reads
the v2 work file, saves a new editable study, and exports its review GLB.
The final entry point refuses to overwrite an existing sculpt or export.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
INPUT = ROOT / "art/source/minji-v2.blend"
STUDY = ROOT / "art/source/minji-v3-face-study.blend"
GLB = ROOT / "unity/Assets/Editor/HospitalArt/minji-v3-face-study.glb"
RENDERS = ROOT / "artifacts/minji-face-study"

# Heights, half-widths, anterior depths and anterior offsets, in model units.
FACE = [
    (1.407, .001, .002, .077), (1.420, .077, .060, .060),
    (1.450, .142, .110, .040), (1.487, .187, .145, .022),
    (1.531, .222, .171, .009), (1.578, .246, .186, .001),
    (1.631, .246, .184, -.002), (1.688, .237, .170, -.007),
    (1.748, .219, .161, -.013), (1.812, .213, .155, -.019),
    (1.867, .192, .132, -.026), (1.925, .143, .095, -.031),
    (1.966, .002, .003, -.033),
]

CAP = [
    (1.343, .236, .201, -.036), (1.379, .281, .223, -.041),
    (1.440, .316, .247, -.044), (1.524, .325, .263, -.048),
    (1.615, .316, .260, -.045), (1.711, .298, .247, -.040),
    (1.792, .273, .230, -.040), (1.873, .239, .204, -.044),
    (1.934, .181, .154, -.045), (1.977, .119, .108, -.048),
    (1.993, .074, .067, -.046), (2.004, .039, .035, -.044),
    (2.009, .003, .004, -.044),
]

# The lower contour passes over the forehead, down along the cheek and around the nape.
HAIRLINE = [
    (-180, 1.357), (-140, 1.351), (-96, 1.352), (-70, 1.375), (-55, 1.451),
    (-46, 1.602), (-35, 1.708), (-21, 1.735), (-6, 1.771), (8, 1.842),
    (16, 1.883), (28, 1.820), (41, 1.732), (55, 1.544),
    (69, 1.431), (88, 1.361), (131, 1.348), (180, 1.357),
]


def sample(rows, x):
    """Clamped cubic interpolation, so profiles stay within their control sections."""
    if x <= rows[0][0]:
        return rows[0][1:]
    for i, (a, b) in enumerate(zip(rows, rows[1:])):
        if x > b[0]:
            continue
        before = rows[max(0, i - 1)]
        after = rows[min(len(rows) - 1, i + 2)]
        width = b[0] - a[0]
        t = (x - a[0]) / width
        result = []
        for va, vb, vp, vn in zip(a[1:], b[1:], before[1:], after[1:]):
            da = (vb - vp) * width / (b[0] - before[0])
            db = (vn - va) * width / (after[0] - a[0])
            v = (2*t**3-3*t**2+1)*va + (t**3-2*t**2+t)*da + (-2*t**3+3*t**2)*vb + (t**3-t**2)*db
            result.append(min(max(va, vb), max(min(va, vb), v)))
        return tuple(result)
    return rows[-1][1:]


def srgb(hex_color):
    channels = [int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + .055) / 1.055)**2.4 if x > .04045 else x / 12.92 for x in channels)


def material(name, hex_color, roughness, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*srgb(hex_color), 1)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = mat.diffuse_color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return mat


def painted_material(name, hex_color, roughness, attribute):
    mat = material(name, hex_color, roughness)
    color_node = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    color_node.layer_name = attribute
    mat.node_tree.links.new(color_node.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    return mat


def point(x, height, front):
    """The art coordinates use a positive anterior depth; Blender views from -Y."""
    return x, -front, height


def mesh_object(name, vertices, faces, mat, parent, color=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    obj.data.materials.append(mat)
    for face in mesh.polygons:
        face.use_smooth = True
    if color:
        attr = mesh.color_attributes.new(name=color[0], type="FLOAT_COLOR", domain="POINT")
        for index, vertex in enumerate(vertices):
            attr.data[index].color = (*color[1](vertex), 1)
    return obj


def rings(rows, columns, bottom_to_top=True):
    """Faces around successive rings with outward normals."""
    faces = []
    for row in range(rows-1):
        for i in range(columns):
            a = row*columns+i
            b = row*columns+(i+1)%columns
            face = (a,b,b+columns,a+columns)
            faces.append(face if bottom_to_top else tuple(reversed(face)))
    return faces


def gaussian(x, z, cx, cz, dx, dz):
    return math.exp(-((x-cx)/dx)**2-((z-cz)/dz)**2)


def sculpt(x, z):
    # The bridge, tip and cheek fat are part of the same continuous mesh.
    return (
        .022*gaussian(x,z,0,1.629,.029,.047)
        + .038*gaussian(x,z,0,1.591,.040,.027)
        + .013*gaussian(x,z,0,1.526,.073,.032)
        + .025*gaussian(abs(x),z,.160,1.570,.065,.049)
        - .029*gaussian(abs(x),z,.108,1.642,.077,.054)
        + .014*gaussian(abs(x),z,.115,1.710,.073,.037)
    )


def skin_front(x, z):
    width, depth, center = sample(FACE,z)
    near = math.sqrt(max(.0, 1-(x/max(width,.001))**2))
    return center + depth*near + near**3*sculpt(x,z)


def head(parent, skin, tone):
    vertices = []
    rows, columns = 91, 120
    for row in range(rows):
        z = FACE[0][0] + (FACE[-1][0]-FACE[0][0]) * row/(rows-1)
        w, d, c = sample(FACE,z)
        for i in range(columns):
            phi = math.tau*i/columns
            x = math.sin(phi)*w
            anterior = math.cos(phi)
            y = c+d*anterior+max(0,anterior)**3*sculpt(x,z)
            vertices.append(point(x,z,y))
    faces = rings(rows, columns)
    faces.extend((tuple(reversed(range(columns))), tuple(range((rows-1)*columns,rows*columns))))
    return mesh_object("Face · cheeks, short jaw and nose", vertices, faces, skin, parent, ("Skin tone", tone))


def cap(parent, hair, tone):
    rows, columns = 66, 144
    vertices = []
    for row in range(rows+3):
        u = min(1, row/(rows-1))
        for i in range(columns):
            angle = -180 + 360*i/columns
            t = math.radians(angle)
            floor, = sample(HAIRLINE, angle)
            z = 2.009-(2.009-floor)*(1-math.cos(u*math.pi*.5))
            w, d, c = sample(CAP,z)
            phase = t + .13*math.sin(u*math.pi)*max(0,math.cos(t))
            # Swept volumes and the part are cut into one scalp surface.
            sweep = -.58 + .83*(1-u)
            part = .27 + .11*(1-u)
            fringe = .031*gaussian(t,u,sweep,.72,.30,.36)
            crown = .022*gaussian(t,u,.63,.54,.47,.29)
            furrow = .012*gaussian(t,u,part,.57,.082,.32)
            flow = .005*math.cos(9*t+2.2*u)+.0022*math.cos(17*t+3.6*u)
            ridge = (fringe+crown-furrow+flow)*math.sin(u*math.pi*.66)
            curl = .021*gaussian(abs(t),z,1.43,.20,.68,.065)
            inward = max(0,row-rows+1)
            x = (.045*(1-u)**2) + math.sin(phase)*(w+ridge-curl-.014*inward)
            anterior = c + math.cos(phase)*(d+ridge-.012*inward) - curl
            vertices.append(point(x,z-.003*inward,anterior))
    faces = rings(rows+3, columns, bottom_to_top=False)
    faces.append(tuple(range(columns)))
    bob = mesh_object("Bob · continuous scalp and turned hem", vertices, faces, hair, parent, ("Hair tone", tone))
    line_bob(bob)
    return bob


def line_bob(bob):
    """Give the open underside a shaded lining independent of the scalp shader."""
    columns = 144
    row_ids = (*range(0,66,2), 65, 68)
    vertices = []
    for row in row_ids:
        for i in range(0,columns,2):
            x,y,z = bob.data.vertices[row*columns+i].co
            vertices.append((x*.965,y*.952,z-.005))
    faces = rings(len(row_ids),columns//2)
    faces.append(tuple(reversed(range(columns//2))))
    lining = material("Minji v3 · underside of the bob", "382319", .72)
    lining.use_backface_culling = True
    lining.node_tree.nodes.get("Principled BSDF").inputs["Specular IOR Level"].default_value = .24
    mesh_object("Bob · dark inner lining",vertices,faces,lining,bob.parent)
    bob.data.materials[0].use_backface_culling = True


def strand(parent, name, controls, mat, colors=None, sections=10, detail=5):
    """Closed curved volumes oriented to the face. Each end tapers into the adjoining surface."""
    path = [(i, *p) for i,p in enumerate(controls)]
    samples = [sample(path,i/detail) for i in range((len(controls)-1)*detail+1)]
    vertices = []
    for i,(x,z,d,half_width,thickness) in enumerate(samples):
        a, b = samples[max(0,i-1)], samples[min(i+1,len(samples)-1)]
        axis = Vector(point(b[0]-a[0],b[1]-a[1],b[2]-a[2])).normalized()
        across = axis.cross(Vector((0,-1,0))).normalized()
        outward = across.cross(axis).normalized()
        center = Vector(point(x,z,d))
        for j in range(sections):
            phi = math.tau*j/sections
            vertices.append(tuple(center + across*(math.cos(phi)*half_width) + outward*(math.sin(phi)*thickness)))
    faces = rings(len(samples), sections, bottom_to_top=False)
    faces.extend((tuple(range(sections)),tuple(reversed(range(len(vertices)-sections,len(vertices))))))
    return mesh_object(name,vertices,faces,mat,parent,colors)


def eyeball(parent, side, white, iris, lid, brow, highlight):
    center = side*.107
    height = 1.649
    half_width = .068
    reach = .045

    def rim(x, upper):
        s = max(-1,min(1,(x-center)/half_width))
        return height + .005*side*s + (.052 if upper else -.042)*(max(0,1-s*s)**.54)

    def front(x, z):
        v = (x-center)/half_width
        baseline = height + .005*side*v
        h = .052 if z >= baseline else .042
        dome = max(0,1-v**2-((z-baseline)/h)**2)**.58
        return skin_front(x,z)+.0022+.015*dome

    def disc(name, cx, cz, radial_x, radial_z, mat, lift, tone=None, aperture=False):
        columns, rows = 72, 12
        vertices = []
        for row in range(rows):
            radius = (row+.002)/(rows-1+.002)
            for i in range(columns):
                theta = math.tau*i/columns
                x = cx+radial_x*radius*math.cos(theta)
                z = cz+radial_z*radius*math.sin(theta)
                if aperture:
                    outer_z = rim(cx+radial_x*math.cos(theta), math.sin(theta)>=0)
                    z = cz+(outer_z-cz)*radius
                vertices.append(point(x,z,front(x,z)+lift))
        faces = rings(rows, columns, bottom_to_top=False)
        faces.append(tuple(range(columns)))
        return mesh_object(name,vertices,faces,mat,parent,tone)

    label = "left" if side < 0 else "right"
    disc("Rounded sclera · "+label,center,height,half_width,.052,white,0,aperture=True)
    iris_x = center-side*.004
    iris_z = height+.002

    def color(v):
        x,_,z = v
        radius = min(1,math.hypot((x-iris_x)/reach,(z-iris_z)/reach))
        ang = math.atan2(z-iris_z, x-iris_x)
        pupil = srgb("241711")
        amber = srgb("79431F")
        edge = srgb("402419")
        if radius < .50:
            f = max(0, (radius-.40)/.10)
            return tuple(a*(1-f)+b*f for a,b in zip(pupil,amber))
        f = max(0, (radius-.74)/.26)
        brightness = (.83-.15*math.sin(ang)+.072*math.sin(ang*23+radius*11))
        return tuple(a*brightness*(1-f)+b*f for a,b in zip(amber,edge))

    disc("Shared gaze iris and pupil · "+label,iris_x,iris_z,reach,reach,iris,.0006,("Iris tone",color))
    disc("Soft catchlight · "+label,iris_x-.012,iris_z+.017,.0067,.0071,highlight,.0011)
    for upper in (True,False):
        samples = []
        for i in range(17):
            t = i/16
            x = center+half_width*(2*t-1)
            z = rim(x, upper)
            width = (.0051 if upper else .0013)*math.sin(math.pi*t)**.68+.0009
            samples.append((x,z,skin_front(x,z)+.0043,width,width*.75))
        strand(parent, ("Upper" if upper else "Lower")+" lid · "+label,samples,lid if upper else brow,detail=2)
    guides = []
    for i in range(12):
        t = i/11
        x = center + side*(.116*t-.059)
        z = 1.724 + .025*math.sin(math.pi*t)**.86-.005*t
        width = .0015+.0082*math.sin(math.pi*t)**.73*(1-.30*t)
        guides.append((x,z,skin_front(x,z)+.002,width,width*.54))
    strand(parent,"Curved brow · "+label,guides,brow,detail=2)


def smile(parent, lip, seam):
    width = .063
    samples = []
    lower = []
    for i in range(25):
        t = 2*i/24-1
        x = width*t
        z = 1.504+.016*abs(t)**1.9
        depth = skin_front(x,z)
        taper = max(0, 1-t*t)**1.25
        samples.append((x,z,depth+.0024,.0003+.0020*taper,.0018))
        lower.append((x,z-.0031*taper,depth+.0011,.0004+.0035*taper,.0015*taper))
    strand(parent,"Small closed smile",samples,seam,detail=2)
    strand(parent,"Lower lip · soft volume",lower,lip,detail=2)


def remove_old_head():
    head_joint = bpy.data.objects["Head"]
    for obj in tuple(head_joint.children_recursive):
        bpy.data.objects.remove(obj,do_unlink=True)
    torso = bpy.data.objects["Torso_Surface"]
    # Cut only the original neck from the torso mesh. Retain every uniform polygon.
    import bmesh
    mesh = bmesh.new()
    mesh.from_mesh(torso.data)
    neck_slots = {i for i, mat in enumerate(torso.data.materials) if mat and mat.name.startswith("Peach skin")}
    neck_vertices = {v for face in mesh.faces if face.material_index in neck_slots for v in face.verts}
    bmesh.ops.delete(mesh,geom=list(neck_vertices),context="VERTS")
    mesh.to_mesh(torso.data)
    mesh.free()
    return head_joint


def short_neck(parent, mat):
    profile = [(1.276,.103,.085,.000),(1.351,.101,.079,.002),(1.400,.088,.076,.008),
               (1.431,.077,.072,.021),(1.456,.062,.061,.025)]
    vertices = []
    for i in range(24):
        z = 1.276+(1.456-1.276)*i/23
        w,d,c = sample(profile,z)
        for j in range(60):
            phi = math.tau*j/60
            vertices.append(point(w*math.sin(phi),z,c+d*math.cos(phi)))
    mesh_object("Short neck · collar to jaw",vertices,rings(24,60),mat,parent)


def build_face():
    joint = remove_old_head()
    shade = painted_material("Minji v3 · skin", "F4AE83", .47, "Skin tone")
    hair = painted_material("Minji v3 · chestnut", "673721", .46, "Hair tone")
    scalp = srgb("623422")
    blush = srgb("EC8D72")
    skin = srgb("F3B28D")

    def face_color(v):
        x,y,z = v
        f = .52*gaussian(abs(x),z,.163,1.574,.091,.047) if y < -.055 else 0
        return tuple(a*(1-f)+b*f for a,b in zip(skin,blush))

    def hair_color(v):
        x,y,z = v
        f = .86 + .20*gaussian(x,z,-.13,1.90,.23,.155)
        f += .065*math.cos(x*70+z*16+y*28)
        return tuple(x*f for x in scalp)

    head(joint,shade,face_color)
    cap(joint,hair,hair_color)
    neck = material("Minji v3 · neck and ears", "F3B28D", .47)
    short_neck(bpy.data.objects["Torso"],neck)
    for side in (-1,1):
        ear_vertices = []
        for row in range(19):
            latitude = -math.pi/2 + math.pi*(row+.001)/18.002
            for i in range(28):
                angle = math.tau*i/28
                ear_vertices.append(point(
                    side*.228 + .027*math.cos(latitude)*math.sin(angle),
                    1.556 + .043*math.sin(latitude),
                    .067 + .026*math.cos(latitude)*math.cos(angle),
                ))
        mesh_object("Partially covered ear", ear_vertices, rings(19,28), neck, joint)

    white = material("Minji v3 · warm sclera","F3E0CE",.37)
    iris = painted_material("Minji v3 · brown irises","744322",.44,"Iris tone")
    lid = material("Minji v3 · upper lash line","543225",.56)
    brow = material("Minji v3 · brows and lower lids","75432C",.58)
    highlight = material("Minji v3 · small catchlights","FFF2DC",.31)
    for side in (-1,1):
        eyeball(joint,side,white,iris,lid,brow,highlight)
    smile(joint,material("Minji v3 · lip","D8927B",.60),material("Minji v3 · closed smile seam","9D6053",.61))


def configure_view():
    view = Vector((.10,-1,.06)).to_track_quat("Z","Y")
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type != "VIEW_3D":
                continue
            space = area.spaces.active
            space.shading.color_type = "MATERIAL"
            space.region_3d.view_rotation = view
            space.region_3d.view_location = (0,0,1.57)
            space.region_3d.view_distance = 1.62
            space.region_3d.view_perspective = "ORTHO"


def studio():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 25
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 6
    scene.render.resolution_x = scene.render.resolution_y = 544
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("Studio · warm grey")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (.28,.25,.22,1)
    bg.inputs[1].default_value = .62
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    focus = Vector((0,-.02,1.60))
    for label,position,power,size,tint in (
        ("Key",(-1.5,-2.0,3.25),290,2.1,(1,.91,.81)),
        ("Fill",(1.35,-1.8,2.45),110,2.2,(.85,.91,1)),
        ("Hair rim",(-.6,1.10,2.55),125,1.75,(1,.81,.64)),
    ):
        lights = bpy.data.lights.new(label,type="AREA")
        lights.energy = power
        lights.shape = "DISK"
        lights.size = size
        lights.color = tint
        obj = bpy.data.objects.new(label,lights)
        scene.collection.objects.link(obj)
        obj.location = position
        obj.rotation_euler = (focus-obj.location).to_track_quat("-Z","Y").to_euler()
    data = bpy.data.cameras.new("Matched portrait camera")
    data.type = "ORTHO"
    data.ortho_scale = .96
    camera = bpy.data.objects.new(data.name,data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return scene, camera, focus


def render_views(prefix, angles, neutral=False):
    scene,camera,target = studio()
    override = scene.view_layers[0]
    if neutral:
        override.material_override = material("Study neutral grey","BFBDB9",.63)
    for label,yaw in angles:
        a = math.radians(yaw)
        camera.location = target + Vector((math.sin(a)*2.7,-math.cos(a)*2.7,.10))
        camera.rotation_euler = (target-camera.location).to_track_quat("-Z","Y").to_euler()
        path = RENDERS / f"{prefix}-{label}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        if not path.is_file():
            raise RuntimeError(f"Missing rendered image {path}")


def load_baseline():
    bpy.ops.wm.open_mainfile(filepath=str(INPUT),load_ui=True,use_scripts=False)


def run(mode):
    RENDERS.mkdir(parents=True,exist_ok=True)
    angles = (("front",0),("45",45),("side",90))
    if mode == "baseline":
        load_baseline()
        render_views("v2-grey",angles[:2],neutral=True)
        bpy.context.view_layer.material_override = None
        # Reuse the same camera/rig colors on a clean scene.
        load_baseline()
        render_views("v2", (("reference",12),))
        return
    if mode in ("draft", "refined"):
        load_baseline()
        build_face()
        render_views(mode+"-grey",angles[:2],neutral=True)
        return
    if mode == "color-preview":
        load_baseline()
        build_face()
        render_views("draft-color", (("reference",12),("side",90)))
        return
    if mode == "export-review":
        load_study()
        export_review(angles)
        return
    if mode != "final":
        raise ValueError(mode)
    if STUDY.exists() or GLB.exists():
        raise FileExistsError("Keep the existing reviewed sculpt and export.")
    load_baseline()
    build_face()
    configure_view()
    scene = bpy.context.scene
    scene.name = "햇살병원 · 민지 얼굴 검토 v3"
    bpy.data.objects["Minji_v2"]["study_only"] = "Minji v3 face comparison"
    bpy.ops.wm.save_as_mainfile(filepath=str(STUDY),compress=True)
    export_review(angles)


def export_review(angles):
    if GLB.exists():
        raise FileExistsError("Keep the existing review export.")
    GLB.parent.mkdir(parents=True,exist_ok=True)
    window = bpy.context.window_manager.windows[0]
    area = next(area for area in window.screen.areas if area.type == "VIEW_3D")
    with bpy.context.temp_override(window=window, area=area):
        bpy.ops.export_scene.gltf(
            filepath=str(GLB),export_format="GLB",export_animations=False,
            export_morph=False,export_extras=False,
        )
    render_views("v3-grey", (*angles, ("back",180)), neutral=True)
    load_study()
    render_views("v3", (("reference",12), *angles))
    # Reopen the studio-free modeling file when the review finishes.
    load_study()


def load_study():
    bpy.ops.wm.open_mainfile(filepath=str(STUDY),load_ui=True,use_scripts=False)
