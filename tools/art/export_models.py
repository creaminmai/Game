"""Export packed Blender sources with a bounded static-mesh triangle budget."""
import bpy, json, sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]

def soften_contact_atlas(image):
    """Linear occlusion data limited to 16% ambient attenuation.

    Full-range tiny chart/bake differences previously looked like dirt.
    Directional shadows supply large-scale form instead.
    """
    import numpy as np
    pixels=np.empty(len(image.pixels),dtype=np.float32)
    image.pixels.foreach_get(pixels)
    rgba=pixels.reshape(-1,4)
    rgba[:,:3]=.84+.16*np.clip(rgba[:,:3],0,1)
    rgba[:,3]=1
    image.pixels.foreach_set(pixels)
    image.update()

def export_static(obj,name):
    source_triangles=sum(len(p.vertices)-2 for p in obj.data.polygons)
    if source_triangles>300000:
        bpy.context.view_layer.objects.active=obj
        decimate=obj.modifiers.new('Game mesh budget','DECIMATE')
        decimate.ratio=300000/source_triangles
        decimate.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    # Collapse can interpolate custom normals from a bevel into a large wall
    # or floor triangle. Keep genuinely planar axis-aligned panels planar;
    # rounded silhouettes and their small bevel faces retain smooth normals.
    for polygon in obj.data.polygons:
        if polygon.area > .025 and max(abs(v) for v in polygon.normal) > .9995:
            polygon.use_smooth=False
    if name=='hospital-interior':
        # Check actual final geometry along the simulation's four door routes,
        # including shoulder clearance and several heights. This catches a
        # decorative partition being placed across an existing patient path.
        bpy.context.view_layer.update()
        tree=BVHTree.FromObject(obj,bpy.context.evaluated_depsgraph_get())
        inverse=obj.matrix_world.inverted()
        for x,z in [(-1,3),(-1,-2.8),(1,-1),(1,3)]:
            for h in [.4,1.1,1.8]:
                for dz in [-.35,0,.35]:
                    start=inverse@Vector((x-.55,-z-dz,h))
                    end=inverse@Vector((x+.55,-z-dz,h))
                    direction=end-start
                    hit=tree.ray_cast(start,direction.normalized(),direction.length)
                    assert hit[0] is None, f'Patient doorway blocked at x={x}, z={z}, height={h}, offset={dz}'
        print('DOORWAYS: 36 final-mesh clearance rays passed',flush=True)
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models'/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_image_format='AUTO')
    return {'asset':name,'authoring_triangles':obj.get('authoring_triangles',source_triangles),'game_triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'vertices':len(obj.data.vertices),'material_surfaces':len(set(obj.data.materials))}

if __name__=='__main__':
    reports=[]
    for name in ['hospital-interior','treatment-annex']:
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source'/(name+'.blend')))
        if '--rebake' in sys.argv:
            obj=bpy.data.objects[name]
            bpy.context.view_layer.objects.active=obj
            bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
            uv=obj.data.uv_layers['ContactAO']; obj.data.uv_layers.active=uv; uv.active_render=True
            for material in obj.data.materials:
                material.node_tree.nodes.active=material.node_tree.nodes['Baked contact AO']
            scene=bpy.context.scene; scene.render.bake.target='IMAGE_TEXTURES'; scene.cycles.samples=128
            bpy.ops.object.bake(type='AO')
            image=obj.data.materials[0].node_tree.nodes['Baked contact AO'].image
            soften_contact_atlas(image)
            image.filepath_raw=str(ROOT/'godot/assets/textures'/(name+'-ao.png')); image.save(); image.pack()
            obj.data.uv_layers.active_index=0; obj.data.uv_layers[0].active_render=True
            bpy.context.preferences.filepaths.save_version=0
            bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/source'/(name+'.blend')),compress=True)
        reports.append(export_static(bpy.data.objects[name],name))
    (ROOT/'godot/assets/models/asset-report.json').write_text(json.dumps(reports,indent=2))
    print('GAME_ASSETS',json.dumps(reports),flush=True)
