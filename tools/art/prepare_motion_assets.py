"""Keep movable linac parts and clear the existing seated/corridor routes.

Works on packed sources without changing UVs, material calibration or routes.
Run once on current sources; build_assets also calls prepare before saving.
"""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]

def components(obj):
    mesh=obj.data; parent=list(range(len(mesh.vertices)))
    def find(i):
        while parent[i]!=i:
            parent[i]=parent[parent[i]]; i=parent[i]
        return i
    for e in mesh.edges:
        a,b=e.vertices; parent[find(a)]=find(b)
    groups={}
    for v in mesh.vertices: groups.setdefault(find(v.index),[]).append(v.index)
    return list(groups.values())

def split(obj, selected, name):
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.context.tool_settings.mesh_select_mode=(True,False,False)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='DESELECT'); bpy.ops.object.mode_set(mode='OBJECT')
    for v in obj.data.vertices: v.select=v.index in selected
    before=set(bpy.context.scene.objects)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.separate(type='SELECTED'); bpy.ops.object.mode_set(mode='OBJECT')
    parts=list(set(bpy.context.scene.objects)-before)
    assert len(parts)==1,(name,len(parts))
    parts[0].name=name
    return parts[0]

def prepare(obj,name):
    if name=='hospital-interior' and not obj.get('reception_face_clearance'):
        def monitor(vs): return all(abs(v.x+5.75)<.68 and abs(v.y+5.0)<.72 and 1.33<v.z<2.7 for v in vs)
        for ids in components(obj):
            if monitor([obj.matrix_world@obj.data.vertices[i].co for i in ids]):
                for i in ids: obj.data.vertices[i].co.x-=.25
        for c in bpy.data.collections:
            if 'editable parts' in c.name:
                for part in c.objects:
                    if part.type=='MESH' and monitor([part.matrix_world@v.co for v in part.data.vertices]): part.location.x-=.25
        obj['reception_face_clearance']=True
    if name=='hospital-interior' and not obj.get('connector_plant_clearance'):
        def plant(vs): return all(abs(v.x-6.4)<.75 and abs(v.y+4.8)<.75 and -.01<v.z<1.8 for v in vs)
        for ids in components(obj):
            if plant([obj.matrix_world@obj.data.vertices[i].co for i in ids]):
                for i in ids: obj.data.vertices[i].co.y+=.45
        for c in bpy.data.collections:
            if 'editable parts' in c.name:
                for part in c.objects:
                    if part.type=='MESH' and plant([part.matrix_world@v.co for v in part.data.vertices]): part.location.y+=.45
        obj['connector_plant_clearance']=True
    if obj.get('motion_clearance_v1'): return
    def coords(ids): return [obj.matrix_world@obj.data.vertices[i].co for i in ids]
    if name=='hospital-interior':
        # Front/back row clearances: preserve seat IDs and logical waiting
        # anchors; the actor's seated offset follows the actual furniture.
        for ids in components(obj):
            vs=coords(ids)
            for x in [-4.5,-3.2]:
                for z,shift in [(1.85,.5),(3.35,.15)]:
                    if all(abs(v.x-x)<.64 and abs(v.y+z)<.65 and -.01<v.z<1.65 for v in vs):
                        for i in ids: obj.data.vertices[i].co.y += shift
        for collection in bpy.data.collections:
            if 'editable parts' not in collection.name: continue
            for part in list(collection.objects):
                if part.type!='MESH': continue
                vs=[part.matrix_world@v.co for v in part.data.vertices]
                for x in [-4.5,-3.2]:
                    for z,shift in [(1.85,.5),(3.35,.15)]:
                        if all(abs(v.x-x)<.64 and abs(v.y+z)<.65 and -.01<v.z<1.65 for v in vs): part.location.y+=shift
                if all(.77<v.x<.87 and .54<v.y<1.66 and .80<v.z<.92 for v in vs): bpy.data.objects.remove(part,do_unlink=True)
        rails=set()
        for ids in components(obj):
            if all(.77<v.x<.87 and .54<v.y<1.66 and .80<v.z<.92 for v in coords(ids)): rails.update(ids)
        assert rails,'Expected original handrail across planning doorway'
        rail=split(obj,rails,'Removed doorway handrail'); bpy.data.objects.remove(rail,do_unlink=True)
    pivot=Vector((4 if name=='hospital-interior' else 10,-3,0))
    inverse=Matrix.Rotation(math.radians(35),4,'Z') @ Matrix.Translation(-pivot)
    selected=set()
    for ids in components(obj):
        vs=[inverse@v for v in coords(ids)]
        if all(abs(v.x)<.57 and -.51<v.y<2.31 and 1.30<v.z<3.16 for v in vs): selected.update(ids)
    assert len(selected)>500,(name,len(selected))
    head=split(obj,selected,'TreatmentHead')
    head['motion_part']='Lift 0.55 game units during patient transfer; retain rest transform'
    obj['motion_clearance_v1']=True
    print('MOTION_ASSET',name,'head vertices',len(head.data.vertices),flush=True)

if __name__=='__main__':
    sys.path.insert(0,str(Path(__file__).resolve().parent))
    from export_models import export_static
    reports=[]
    for name in ['hospital-interior','treatment-annex']:
        path=ROOT/'art/source'/(name+'.blend')
        bpy.ops.wm.open_mainfile(filepath=str(path))
        obj=bpy.data.objects[name]; prepare(obj,name)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
        reports.append(export_static(obj,name))
    import json
    (ROOT/'godot/assets/models/asset-report.json').write_text(json.dumps(reports,indent=2)+'\n')
