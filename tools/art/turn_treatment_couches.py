"""One-time migration of the packed 3119d2f sources; build_assets.py also authors this angle.
Rotates whole connected furniture components, their custom normals, and editable parts.
Does not move rooms, doors, patient routes or occupancy anchors. Re-bake AO afterwards.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[2]
for name,x in [('hospital-interior',4),('treatment-annex',10)]:
    path=ROOT/'art/source'/f'{name}.blend'
    bpy.ops.wm.open_mainfile(filepath=str(path))
    editable=[c for c in bpy.data.collections if 'editable parts' in c.name]
    for c in editable: c.hide_viewport=False
    bpy.context.view_layer.update()
    obj=bpy.data.objects[name]
    if obj.get('couch_yaw_degrees') == -35:
        print('ALREADY_TURNED',name); continue
    pivot=Vector((x,-3,0))
    rotation=Matrix.Rotation(math.radians(-35),4,'Z')
    turn=Matrix.Translation(pivot)@rotation@Matrix.Translation(-pivot)
    def equipment(coords):
        return all(x-1.5 < v.x < x+1.5 and -4.5 < v.y < -.4 and -.005 < v.z < 3.2 for v in coords)
    mesh=obj.data
    parents=list(range(len(mesh.vertices)))
    def find(i):
        while parents[i]!=i:
            parents[i]=parents[parents[i]]; i=parents[i]
        return i
    for edge in mesh.edges:
        a,b=edge.vertices; parents[find(a)]=find(b)
    groups={}
    for v in mesh.vertices: groups.setdefault(find(v.index),[]).append(v.index)
    selected=set()
    for ids in groups.values():
        if equipment([obj.matrix_world@mesh.vertices[i].co for i in ids]): selected.update(ids)
    assert len(selected)>2000,(name,len(selected))
    normals=[n.vector.copy() for n in mesh.corner_normals]
    local_turn=obj.matrix_world.inverted()@turn@obj.matrix_world
    for i in selected: mesh.vertices[i].co=local_turn@mesh.vertices[i].co
    for i,loop in enumerate(mesh.loops):
        if loop.vertex_index in selected: normals[i]=local_turn.to_3x3()@normals[i]
    mesh.update()
    mesh.normals_split_custom_set(normals)
    source_parts=0
    for collection in bpy.data.collections:
        if 'editable parts' not in collection.name: continue
        for part in collection.objects:
            if equipment([part.matrix_world@vertex.co for vertex in part.data.vertices]):
                part.matrix_world=turn@part.matrix_world; source_parts+=1
    assert source_parts>=15,(name,source_parts)
    for c in editable: c.hide_viewport=True
    obj['couch_yaw_degrees']=-35
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
    print('TURNED',name,'game vertices',len(selected),'editable parts',source_parts,flush=True)
