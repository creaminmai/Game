"""Add an editable review camera/light rig to packed sources; never export it."""
import bpy
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
def C(p):return Vector((p[0],-p[2],p[1]))
for name in ['hospital-interior','treatment-annex','patient','nurse']:
    path=root/'art/source'/(name+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(path))
    for collection in bpy.data.collections:
        if 'editable parts' in collection.name:
            collection.hide_viewport=True; collection.hide_render=True
            for part in collection.objects:
                part.hide_set(False); part.hide_render=False
    # Migrate the garden's base from the leaf palette to its own quieter color.
    # The builder authors this directly; this also updates earlier saved sources.
    if name=='hospital-interior':
        obj=bpy.data.objects[name]
        if not any(m.name=='garden' for m in obj.data.materials):
            old=next(m for m in obj.data.materials if m.name=='leaf')
            material=old.copy(); material.name='garden'
            c=[int('b7c9aa'[i:i+2],16)/255 for i in (0,2,4)]
            color=tuple(((v+.055)/1.055)**2.4 for v in c)+(1,)
            material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color
            material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
            obj.data.materials.append(material); index=len(obj.data.materials)-1
            for polygon in obj.data.polygons:
                if obj.data.materials[polygon.material_index]==old and (obj.matrix_world@polygon.center).z<-.5:
                    polygon.material_index=index
        for source in bpy.context.scene.objects:
            if source.name.startswith('Source · Garden soil'):
                material=source.data.materials[0].copy(); material.name='garden source'
                material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.4735315,.5840784,.4019778,1)
                material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
                source.data.materials[0]=material
            elif source.name.startswith('Source ·') and source.type=='MESH':
                for material in source.data.materials:
                    if material.name.split('.')[0]=='leaf':
                        c=[int('a7c77e'[i:i+2],16)/255 for i in (0,2,4)]
                        material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=tuple(((v+.055)/1.055)**2.4 for v in c)+(1,)
    for o in list(bpy.context.scene.objects):
        if o.type in ['CAMERA','LIGHT']:bpy.data.objects.remove(o,do_unlink=True)
    character=name in ['patient','nurse']
    center=C((0,1,0) if character else ((10,.5,3) if name=='treatment-annex' else (-3.3,.4,-.1)))
    cam=bpy.data.cameras.new('Review camera');cam.type='ORTHO';cam.ortho_scale=3 if character else 17
    obj=bpy.data.objects.new('Review camera',cam);bpy.context.collection.objects.link(obj)
    obj.location=center+C((1.5,2.5,7) if character else (6,19,28));obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
    scene=bpy.context.scene;scene.camera=obj
    for title,power,size,position in [('Window daylight',1100,8,(-7,10,4)),('Neutral fill',500,10,(6,8,5))]:
        data=bpy.data.lights.new(title,'AREA');data.energy=power;data.shape='DISK';data.size=size
        data.color=(1,.94,.86) if title=='Window daylight' else (.94,.97,1)
        light=bpy.data.objects.new(title,data);bpy.context.collection.objects.link(light)
        light.location=center+C(position);light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0
    scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
    print('EDITABLE SOURCE',name,flush=True)
