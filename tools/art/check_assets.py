#!/usr/bin/env python3
"""Check the GLB contract Godot relies on, without requiring Blender."""
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[2]
for name in ['hospital-interior', 'treatment-annex', 'patient', 'nurse']:
    data = (root / 'godot/assets/models' / (name + '.glb')).read_bytes()
    magic, version, total = struct.unpack_from('<III', data)
    assert (magic, version, total) == (0x46546C67, 2, len(data)), name + ': invalid GLB'
    length, kind = struct.unpack_from('<II', data, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(data[20:20 + length])
    assert all('bufferView' in image for image in doc.get('images', [])), name + ': missing packed image'
    triangles = surfaces = 0
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            surfaces += 1
            assert primitive.get('mode', 4) == 4
            triangles += doc['accessors'][primitive['indices']]['count'] // 3
            attributes = primitive['attributes']
            assert not any(key.startswith('TEXCOORD_') and int(key[9:]) > 1 for key in attributes), name + ': unsupported third UV channel'
            material = doc['materials'][primitive['material']]
            if name in ['hospital-interior', 'treatment-annex']:
                ao = material['occlusionTexture']
                assert ao.get('texCoord', 0) == 1 and 'TEXCOORD_1' in attributes, name + ': AO must use UV1'
            else:
                assert 'COLOR_0' in attributes, name + ': missing character contact shading'
    assert triangles <= (300000 if name == 'hospital-interior' else 65000), name + ': triangle budget exceeded'
    if name in ['hospital-interior','treatment-annex']:
        assert any(node.get('name')=='TreatmentHead' for node in doc['nodes']), name+': missing movable overhead assembly'
    if name in ['patient', 'nurse']:
        names = {node.get('name') for node in doc['nodes']}
        assert {'Head', 'Torso', 'Arm_L', 'Arm_R', 'Leg_L', 'Leg_R', 'SeatedLegs', 'Book', 'Glasses'} <= names
        assert len(doc['meshes']) <= 9, name + ': unbatched character details'
    print(f'ASSET {name}: {triangles:,} triangles, {surfaces} surfaces; packed textures and engine channels valid')
