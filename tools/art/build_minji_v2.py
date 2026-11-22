"""Author Minji's connected surfaces and facial poses, exporting an editable glTF.

Coordinates are metres, Y up, +Z toward the face. Each named joint owns its
meshes in joint-local coordinates. Blender can import the hierarchy and shape
keys without baking or access to the previous character.
"""
import argparse
import json
import math as m
import struct
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPORT = ROOT / 'unity/Assets/Resources/HospitalArt/minji-v2.glb'
POSES = ('Blink', 'OpenSmile', 'Explain', 'Joy', 'Worry', 'Relief')
PALETTE = {
    'Peach skin': ('F5BE9D', .68), 'Chestnut': ('6A3D2A', .58),
    'Chestnut raised': ('754630', .61), 'Brows': ('553121', .79),
    'Ivory white': ('FFF1DF', .66), 'Iris rim': ('51291B', .43),
    'Iris amber': ('9B5831', .49), 'Pupil': ('301E19', .42),
    'Eye glint': ('FFF8E9', .25), 'Lip': ('B97166', .73),
    'Mouth shadow': ('633530', .88), 'Mint twill': ('78B09A', .82),
    'Mint trim': ('538E79', .76), 'Trousers': ('75A894', .86),
    'Cream leather': ('F5E8CC', .67), 'Shoe soles': ('70A18B', .85),
    'Gold petal': ('F5C652', .64), 'Sunflower centre': ('A76A38', .81),
    'Badge clip': ('BC9252', .46), 'Cuff seam': ('DDE8D6', .84),
}


def add(a, b): return tuple(x + y for x, y in zip(a, b))
def sub(a, b): return tuple(x - y for x, y in zip(a, b))
def mul(a, k): return tuple(x * k for x in a)
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def dot(a, b): return sum(x*y for x, y in zip(a, b))


def normal(a):
    length = m.sqrt(dot(a, a))
    return mul(a, 1 / length) if length > 1e-9 else (0, 1, 0)


def interpolate(rows, y):
    for i, (start, end) in enumerate(zip(rows, rows[1:])):
        if y <= end[0]:
            previous = rows[max(0, i-1)]
            following = rows[min(i+2, len(rows)-1)]
            interval = end[0] - start[0]
            t = min(1, max(0, (y - start[0]) / interval))
            result = []
            for a, b, p, q in zip(start[1:], end[1:], previous[1:], following[1:]):
                left = (b-p) * interval / (end[0]-previous[0])
                right = (q-a) * interval / (following[0]-start[0])
                value = (2*t**3 - 3*t**2 + 1)*a + (t**3 - 2*t**2 + t)*left
                value += (-2*t**3 + 3*t**2)*b + (t**3 - t**2)*right
                result.append(min(max(a,b), max(min(a,b),value)))
            return tuple(result)
    return rows[-1][1:]


def grid(vertices, u, v, *, closed=True, invert=False):
    faces = []
    for row in range(v - 1):
        for col in range(u if closed else u - 1):
            a, b = row*u+col, row*u+(col+1)%u
            faces.extend(((a,b,a+u),(b,b+u,a+u)))
    if invert:
        faces = [(a,c,b) for a,b,c in faces]
    return vertices, faces


def rings(profile, radial=32, vertical=32, sculpt=None):
    vertices = []
    for row in range(vertical):
        y = profile[0][0] + (profile[-1][0]-profile[0][0])*row/(vertical-1)
        width, depth, cx, cz = interpolate(profile, y)
        for i in range(radial):
            t = i * m.tau/radial
            x, z = cx + width*m.cos(t), cz + depth*m.sin(t)
            if sculpt and m.sin(t)>0:
                z += sculpt(x,y) * m.sin(t)**3
            vertices.append((x,y,z))
    return grid(vertices,radial,vertical,invert=True)


def bubble(center, size, sectors=20, layers=13):
    vertices = []
    for j in range(layers):
        pitch = m.pi*j/(layers-1)
        for i in range(sectors):
            t = m.tau*i/sectors
            vertices.append(add(center,(size[0]*m.cos(t)*m.sin(pitch),size[1]*m.cos(pitch),size[2]*m.sin(t)*m.sin(pitch))))
    return grid(vertices,sectors,layers)


def sweep(points, radii, depth=1., sectors=10):
    vertices=[]
    for i, p in enumerate(points):
        tangent=normal(sub(points[min(i+1,len(points)-1)],points[max(0,i-1)]))
        right=normal(cross(tangent,(0,0,1) if abs(tangent[2])<.95 else (0,1,0)))
        front=normal(cross(tangent,right))
        for s in range(sectors):
            angle=m.tau*s/sectors
            vertices.append(add(p,add(mul(right,radii[i]*m.cos(angle)),mul(front,radii[i]*depth*m.sin(angle)))))
    return grid(vertices,sectors,len(points))


HEAD = [
    (1.435,.005,.005,0,.063),(1.459,.080,.088,0,.044),(1.500,.151,.133,0,.027),
    (1.557,.204,.167,0,.008),(1.628,.243,.183,0,.001),(1.695,.245,.180,0,-.002),
    (1.758,.225,.165,0,-.010),(1.822,.208,.153,0,-.015),(1.878,.180,.130,0,-.023),
    (1.928,.119,.090,0,-.024),(1.957,.006,.009,0,-.026),
]


def relief(x,y):
    def lump(cx,cy,wx,wy):
        return m.exp(-((x-cx)/wx)**2-((y-cy)/wy)**2)
    return (.049*lump(0,1.603,.033,.027)+.024*lump(0,1.640,.024,.059)
            +.014*lump(0,1.535,.078,.038)-.011*(lump(.116,1.676,.060,.046)+lump(-.116,1.676,.060,.046)))


def face(x,y):
    width, depth, cx, cz = interpolate(HEAD,y)
    s = m.sqrt(max(.002,1-((x-cx)/width)**2))
    return cz+depth*s+relief(x,y)*s**3


def facial_disc(cx,cy,rx,ry,lift, almond=0., dome=.004):
    # Radial topology follows the sculpted cheek rather than forming a flat badge.
    vertices=[]
    sectors=28
    for ring in range(5):
        radius=ring/4
        for step in range(sectors):
            t=m.tau*step/sectors
            x=cx+rx*radius*m.cos(t)
            y=cy+ry*radius*m.sin(t)*(1-almond*abs(m.cos(t)))
            vertices.append((x,y,face(x,y)+lift+dome*(1-radius*radius)))
    return grid(vertices,sectors,5,invert=True)


def hair():
    # A continuous asymmetrical scalp with a sweep across the forehead and a
    # longer back. Cosine grooves continue from the part toward the curled ends.
    segments, rows=88,31
    vertices=[]
    for row in range(rows):
        u=row/(rows-1)
        for step in range(segments):
            t=m.tau*step/segments
            front=max(0,m.cos(t))
            part=.21*m.sin(t+.2)*front**3
            bottom=2.49-1.22*front**1.65+part
            a=.01+bottom*u
            turn=t+.33*m.sin(m.pi*u)*front
            groove=(.008*m.cos(5.0*t-1.0*u)+.004*m.cos(9*t+.8*u))*m.sin(a)**1.5
            curl=.022*max(0,(u-.78)/.22)**2
            x=m.sin(turn)*m.sin(a)*(.275+groove-curl)+.032*(1-u)**2
            z=m.cos(turn)*m.sin(a)*(.235+groove-curl)-.031
            y=1.738+.294*m.cos(a)+.008*m.cos(3*t)*m.sin(a)**2
            vertices.append((x,y,z))
    return grid(vertices,segments,rows,invert=True)


def hair_ribbon(points,radii):
    """One continuous taper from the part to a rounded end at the temple."""
    profile = [(i, *p, radius) for i, (p,radius) in enumerate(zip(points,radii))]
    samples = [interpolate(profile, i/4) for i in range((len(points)-1)*4+1)]
    return sweep([sample[:3] for sample in samples], [sample[3] for sample in samples], .17, 16)


class Character:
    def __init__(self):
        self.buffer=bytearray()
        self.nodes=[]
        self.meshes=[]
        self.views=[]
        self.accessors=[]
        self.pivots={}
        self.parts=defaultdict(list)
        self.triangles=0
        self.joint('Minji_v2',(0,0,0))

    def joint(self,name,position,parent=None):
        index=len(self.nodes)
        self.nodes.append({'name':name,'translation':sub(position,self.pivots[parent][1]) if parent else position,'children':[]})
        self.pivots[name]=index,position
        if parent: self.nodes[self.pivots[parent][0]]['children'].append(index)

    def mesh(self,joint,material,shape,name=None,morph=None):
        if morph:
            self.emit(joint,name,[(material,*shape,morph)])
        else:
            self.parts[joint].append((material,*shape,None))

    def accessor(self,values,kind,code):
        offset=len(self.buffer)
        if code=='H': self.buffer.extend(struct.pack(f'<{len(values)}H',*values))
        else:
            for point in values: self.buffer.extend(struct.pack('<3f',*point))
        self.views.append({'buffer':0,'byteOffset':offset,'byteLength':len(self.buffer)-offset})
        while len(self.buffer)%4: self.buffer.append(0)
        record={'bufferView':len(self.views)-1,'componentType':5123 if code=='H' else 5126,'count':len(values),'type':kind}
        if kind=='VEC3':
            record.update(min=[min(column) for column in zip(*values)],max=[max(column) for column in zip(*values)])
        self.accessors.append(record)
        return len(self.accessors)-1

    def emit(self,joint,name,shapes):
        parent,pivot=self.pivots[joint]
        grouped=defaultdict(lambda: ([],[],None))
        for mat,vertices,faces,morph in shapes:
            previous,indices,_=grouped[mat]
            offset=len(previous)
            previous.extend(vertices)
            indices.extend(tuple(offset+i for i in face) for face in faces)
            if morph: grouped[mat]=(previous,indices,morph)
        primitives=[]
        for mat,(vertices,faces,morph) in grouped.items():
            # Merge the duplicate pole vertices and discard zero-area faces
            # before generating area-weighted normals.
            accum=[(0.,0.,0.) for _ in vertices]
            faces_out=[]
            equivalent={}
            for a,b,c in faces:
                n=cross(sub(vertices[b],vertices[a]),sub(vertices[c],vertices[a]))
                if dot(n,n)<1e-16: continue
                for i in (a,b,c):
                    key=tuple(round(v,7) for v in vertices[i])
                    j=equivalent.setdefault(key,i)
                    accum[j]=add(accum[j],n)
                faces_out.extend((a,b,c))
            normals=[normal(accum[equivalent.get(tuple(round(v,7) for v in pt),i)]) for i,pt in enumerate(vertices)]
            self.triangles+=len(faces_out)//3
            attrs={'POSITION':self.accessor([sub(v,pivot) for v in vertices],'VEC3','f'),
                   'NORMAL':self.accessor(normals,'VEC3','f')}
            if joint == 'Head' and mat == 'Peach skin':
                def blush(point):
                    x,y,z = point
                    strength = m.exp(-((abs(x)-.148)/.057)**2 - ((y-1.599)/.045)**2) if z > .09 else 0
                    return 1., 1.-.22*strength, 1.-.16*strength
                attrs['COLOR_0'] = self.accessor([blush(v) for v in vertices],'VEC3','f')
            primitive={'attributes':attrs,'indices':self.accessor(faces_out,'SCALAR','H'),
                       'material':list(PALETTE).index(mat)}
            if morph:
                primitive['targets']=[{'POSITION':self.accessor([sub(morph(key,v),v) for v in vertices],'VEC3','f')} for key in POSES]
            primitives.append(primitive)
        mesh={'name':name,'primitives':primitives}
        if shapes[0][-1]: mesh.update(weights=[0]*len(POSES),extras={'targetNames':POSES})
        self.meshes.append(mesh)
        self.nodes[parent]['children'].append(len(self.nodes))
        self.nodes.append({'name':name,'mesh':len(self.meshes)-1})

    def save(self,file):
        for part,shapes in self.parts.items(): self.emit(part,part+'_Surface',shapes)
        materials=[]
        for name,(srgb,rough) in PALETTE.items():
            rgb=[int(srgb[i:i+2],16)/255 for i in (0,2,4)]
            linear=[((v+.055)/1.055)**2.4 if v>.04045 else v/12.92 for v in rgb]
            materials.append({'name':name,'pbrMetallicRoughness':{'baseColorFactor':linear+[1.],
                              'metallicFactor':0,'roughnessFactor':rough}})
        doc={'asset':{'version':'2.0','generator':'Sunshine Hospital Minji surfaces'},
             'scene':0,'scenes':[{'nodes':[0]}],'nodes':self.nodes,'meshes':self.meshes,'materials':materials,
             'accessors':self.accessors,'buffers':[{'byteLength':len(self.buffer)}],'bufferViews':self.views}
        meta=json.dumps(doc,separators=(',',':')).encode()
        meta+=b' '*(-len(meta)%4)
        file.parent.mkdir(parents=True,exist_ok=True)
        file.write_bytes(struct.pack('<III',0x46546C67,2,28+len(meta)+len(self.buffer))+
                         struct.pack('<I4s',len(meta),b'JSON')+meta+
                         struct.pack('<I4s',len(self.buffer),b'BIN\0')+self.buffer)
        print(f'{file}: {self.triangles:,} triangles, {len(materials)} materials, 0 textures')


def build():
    model=Character()
    model.joint('Head',(0,1.477,0),'Minji_v2')
    model.joint('Torso',(0,.93,0),'Minji_v2')
    model.mesh('Head','Peach skin',rings(HEAD,64,60,relief))
    model.mesh('Head','Chestnut',hair())
    # Broad overlapping locks are swept along the scalp, with tapered tips.
    model.mesh('Head','Chestnut raised',hair_ribbon(
        [(.032,1.993,.090),(-.045,1.976,.131),(-.110,1.933,.164),(-.164,1.866,.181),
         (-.199,1.801,.158),(-.213,1.746,.130),(-.229,1.693,.094)],
        [.012,.055,.068,.069,.056,.039,.002]))
    model.mesh('Head','Chestnut',hair_ribbon(
        [(.041,1.991,.063),(.114,1.959,.121),(.166,1.907,.145),(.199,1.842,.139),
         (.225,1.772,.122),(.246,1.697,.076),(.245,1.644,.048)],
        [.012,.054,.060,.055,.052,.038,.003]))

    for side in (-1,1):
        model.mesh('Head','Peach skin',bubble((side*.228,1.600,-.010),(.040,.061,.038)))
        x=side*.105; y=1.674
        def move_eye(key,p):
            px,py,pz=p
            multiplier={'Blink':.04,'Joy':.61,'Worry':.89,'Relief':.76,'Explain':.90}.get(key,1.)
            return px, y+(py-y)*multiplier, pz
        for i,(mat,cx,cy,w,h,z) in enumerate((
            ('Ivory white',x,y,.070,.039,.008),
            ('Iris rim',x,y-.001,.037,.037,.016),
            ('Iris amber',x,y-.003,.031,.032,.022),
            ('Pupil',x+.002,y+.001,.019,.025,.027),
            ('Eye glint',x+.011,y+.016,.009,.009,.032),
        )):
            model.mesh('Head',mat,facial_disc(cx,cy,w,h,z,.37 if i==0 else .07),
                       f'Eye_{side}_{i}',move_eye)
        for top in (True,False):
            points=[]
            for i in range(13):
                s=i/6-1
                dy=(.038 if top else -.031)*m.sqrt(max(0,1-s*s))*(1-.18*abs(s))
                xx=x+.071*s; yy=y+dy
                points.append((xx,yy,face(xx,yy)+.010))
            model.mesh('Head','Brows' if top else 'Lip',sweep(points,[.001+.0045*m.sin(m.pi*j/12) for j in range(13)],.87),
                       f'Lid_{side}_{top}',move_eye)
        points=[]
        for i in range(11):
            s=i/5-1; xx=x+.063*s; yy=1.744+.014*(1-s*s)+.008*s*side
            points.append((xx,yy,face(xx,yy)+.008))
        def move_brow(key,p):
            px,py,pz=p
            lift={'OpenSmile':.011,'Explain':.007*side,'Joy':.015,'Worry':.008-.023*(px-x)*side/.063,'Relief':-.003}.get(key,0)
            return px,py+lift,pz
        model.mesh('Head','Brows',sweep(points,[.002+.010*m.sin(j*m.pi/10) for j in range(11)],.60),
                   f'Brow_{side}',move_brow)

    mouth_y=1.537
    def move_mouth(key,p):
        x,y,z=p
        openness={'OpenSmile':3.4,'Joy':2.8,'Explain':1.28,'Worry':.52,'Relief':.75}.get(key,1.)
        corner={'OpenSmile':.011,'Joy':.016,'Explain':.005,'Worry':-.014,'Relief':.006}.get(key,.004)
        return x,mouth_y+(y-mouth_y)*openness+corner*(x/.065)**2,z
    model.mesh('Head','Mouth shadow',facial_disc(0,mouth_y,.064,.007,.010,.37),'Mouth',move_mouth)
    points=[(x,mouth_y-.008+.009*(x/.064)**2,face(x,mouth_y-.008)+.014) for x in [-.064+i*.0128 for i in range(11)]]
    model.mesh('Head','Lip',sweep(points,[.0018+.0044*m.sin(i*m.pi/10) for i in range(11)],.55),'LowerLip',move_mouth)
    def move_teeth(key,p):
        x,y,z=p
        if key not in ('OpenSmile','Joy'): return x,mouth_y+.002, z-.023
        return x,mouth_y+.008 + (y-mouth_y)*.83,z+.002
    teeth,ti=facial_disc(0,mouth_y,.049,.005,.016,.3)
    def tooth_delta(key,p):
        if key not in ('OpenSmile','Joy'): return p
        return move_teeth(key,(p[0],p[1],p[2]+.023))
    # Teeth rest behind the face. Their shape keys reveal a single enamel strip.
    teeth_base=[(x,y,z-.023) for x,y,z in teeth]
    model.mesh('Head','Ivory white',(teeth_base,ti),'Teeth',tooth_delta)

    model.mesh('Torso','Peach skin',rings(
        [(1.270,.104,.086,0,0),(1.355,.104,.080,0,0),(1.452,.080,.074,0,.016),(1.482,.061,.062,0,.016)]))
    top=[(.711,.156,.113,0,0),(.745,.252,.144,0,0),(.800,.255,.145,0,0),
         (.92,.215,.127,0,-.003),(1.03,.204,.124,0,0),(1.155,.226,.142,0,0),
         (1.246,.240,.134,0,-.010),(1.307,.214,.108,0,-.014),(1.366,.114,.085,0,-.005),
         (1.391,.097,.076,0,0)]
    model.mesh('Torso','Mint twill',rings(top,48,38,lambda x,y:.006*m.cos(34*x)*m.exp(-((y-.91)/.095)**2)))
    model.mesh('Torso','Mint trim',sweep([(0,.742,.145),(0,.89,.134),(0,1.02,.132),(0,1.164,.147),(0,1.293,.117)],
                                        [.010,.012,.011,.010,.004],.5))
    for side in (-1,1):
        model.mesh('Torso','Ivory white',sweep([(side*.084,1.390,.037),(side*.117,1.353,.083),
                   (side*.110,1.302,.107),(side*.069,1.267,.129),(side*.023,1.288,.131)],
                   [.011,.027,.031,.035,.008],.49,16))
        model.mesh('Torso','Mint trim',bubble((side*.142,.855,.122),(.073,.072,.029),16,10))
        model.mesh('Torso','Cuff seam',sweep([(side*.077,.894,.146),(side*.128,.909,.154),(side*.201,.900,.138)], [.003,.009,.004],.48))
    for i in range(4):
        y=.835+.111*i
        _,depth,_,center=interpolate(top,y)
        model.mesh('Torso','Ivory white',bubble((0,y,depth+center+.015),(.019,.020,.010),14,9))
    for i in range(9):
        angle=m.tau*i/9
        p=(.145+.034*m.cos(angle),1.222+.034*m.sin(angle),.151)
        model.mesh('Torso','Gold petal',sweep([add(p,(-.018*m.cos(angle),-.018*m.sin(angle),-.002)),p,
                         add(p,(.017*m.cos(angle),.017*m.sin(angle),0))],[.003,.014,.004],.49))
    model.mesh('Torso','Sunflower centre',bubble((.145,1.222,.158),(.023,.023,.013)))
    model.mesh('Torso','Ivory white',rings([(1.102,.039,.009,-.139,.125),(1.109,.050,.012,-.139,.128),
                    (1.187,.050,.012,-.139,.146),(1.193,.037,.008,-.139,.147)],20,12))
    model.mesh('Torso','Badge clip',bubble((-.139,1.204,.153),(.025,.015,.009),16,10))

    for side,suffix in ((-1,'L'),(1,'R')):
        arm='Arm_'+suffix; fore='Forearm_'+suffix; hand='Hand_'+suffix; leg='Leg_'+suffix
        model.joint(arm,(side*.209,1.270,0),'Minji_v2')
        model.joint(fore,(side*.270,1.000,.004),arm)
        model.joint(hand,(side*.299,.757,.044),fore)
        model.joint(leg,(side*.117,.762,0),'Minji_v2')
        model.mesh(arm,'Mint twill',rings([(1.07,.079,.081,side*.263,-.003),(1.109,.093,.093,side*.252,-.008),
                 (1.233,.094,.100,side*.224,-.008),(1.306,.068,.080,side*.213,-.004),(1.333,.007,.007,side*.205,0)],24,20))
        model.mesh(arm,'Cuff seam',rings([(1.067,.078,.081,side*.263,0),(1.079,.083,.087,side*.260,0),(1.093,.083,.087,side*.258,0)],24,5))
        model.mesh(arm,'Peach skin',rings([( .972,.049,.049,side*.270,.004),(1.008,.054,.053,side*.271,.004),(1.09,.065,.065,side*.261,-.004),(1.126,.044,.043,side*.254,-.005)],22,15))
        model.mesh(fore,'Peach skin',rings([(.736,.025,.025,side*.299,.043),(.777,.031,.030,side*.298,.035),
                    (.856,.042,.041,side*.287,.016),(.957,.056,.049,side*.270,.004),(1.037,.026,.026,side*.270,.004)],22,19))
        palm=[(.639,.021,.021,side*.303,.056),(.666,.046,.034,side*.302,.063),(.711,.043,.034,side*.302,.059),(.760,.029,.025,side*.299,.043)]
        model.mesh(hand,'Peach skin',rings(palm,24,17))
        for n,(spread,length) in enumerate(zip((-.033,-.011,.013,.033),(.043,.066,.060,.048))):
            xx=side*(.303+spread)
            model.mesh(hand,'Peach skin',sweep([(xx,.672,.059),(xx+side*spread*.19,.643,.063),
                          (xx+side*spread*.37,.651-length,.068),(xx+side*spread*.39,.648-length,.069)],
                          [.012,.013,.009,.002],.90,10))
        model.mesh(hand,'Peach skin',sweep([(side*.281,.715,.078),(side*.254,.688,.081),(side*.247,.657,.087)],
                                          [.015,.016,.005],1.,12))
        model.mesh(leg,'Trousers',rings([(.109,.072,.073,side*.122,-.004),(.148,.078,.079,side*.121,-.010),
                     (.265,.077,.080,side*.116,-.003),(.406,.084,.085,side*.111,.005),
                     (.574,.089,.090,side*.111,-.004),(.717,.111,.115,side*.114,-.003),
                     (.805,.084,.088,side*.115,0)],27,25))
        shoe=[(.018,.078,.126,side*.122,.054),(.047,.088,.140,side*.122,.063),
              (.096,.088,.136,side*.122,.065),(.131,.069,.105,side*.122,.042),
              (.162,.049,.052,side*.122,.013),(.183,.005,.006,side*.122,.014)]
        model.mesh(leg,'Cream leather',rings(shoe,30,17))
        model.mesh(leg,'Shoe soles',rings([(.004,.083,.136,side*.122,.062),(.014,.094,.149,side*.122,.064),
                     (.042,.095,.147,side*.122,.063),(.052,.087,.137,side*.122,.061)],30,7))
        for z in (.073,.095,.117):
            x=side*.122
            model.mesh(leg,'Cuff seam',sweep([(x-.041,.121,z),(x,.134,z+.007),(x+.042,.121,z)],[.002,.005,.002],.70))
    return model


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=EXPORT)
    args=parser.parse_args()
    build().save(args.output)
