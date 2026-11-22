"""Save the authored mesh, material slots, joint hierarchy and shape keys as Blender data.

Run with Blender's --background --factory-startup --python-exit-code 1 flags.
"""
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
GLB = ROOT / 'unity/Assets/Resources/HospitalArt/minji-v2.glb'
SOURCE = ROOT / 'art/source/minji-v2.blend'
FACE_KEYS = {'Blink', 'OpenSmile', 'Explain', 'Joy', 'Worry', 'Relief'}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(GLB))
    scene = bpy.context.scene
    scene.name = '햇살병원 · 민지 v2'
    scene.unit_settings.system = 'METRIC'
    expected = {'Minji_v2', 'Head', 'Torso', 'Forearm_L', 'Hand_L', 'Leg_L', 'Leg_R'}
    joints = {obj.name for obj in scene.objects if obj.type == 'EMPTY'}
    shapes = {
        block.name for obj in scene.objects
        if obj.type == 'MESH' and obj.data.shape_keys
        for block in obj.data.shape_keys.key_blocks
    }
    if not expected <= joints or not FACE_KEYS <= shapes:
        raise RuntimeError(f'Missing pivots {expected - joints} or shape keys {FACE_KEYS - shapes}')
    model = scene.objects['Minji_v2']
    model['unity_glb'] = str(GLB.relative_to(ROOT))
    model['unit'] = 'metres'
    bpy.ops.object.select_all(action='DESELECT')
    model.select_set(True)
    bpy.context.view_layer.objects.active = model
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))


if __name__ == '__main__':
    main()
