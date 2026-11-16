import bpy,json,math,itertools
from pathlib import Path
from mathutils import Vector,Matrix
P=Path(__file__).resolve().parents[1]
recipes=json.loads((P/'art/visual-recipes.json').read_text());env=json.loads((P/'art/scenery-recipes.json').read_text());world=json.loads((P/'art/world-scenes.json').read_text())
OUT=P/'previews';OUT.mkdir(exist_ok=True);T=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def shade(h,k):return ''.join(f'{min(255,int(int(h[i:i+2],16)*k)):02X}' for i in (0,2,4))
def poly(planes):
 verts=[]
 for combo in itertools.combinations(planes,3):
  m=Matrix([x[0] for x in combo]);d=Vector([x[1] for x in combo])
  if abs(m.determinant())<1e-7:continue
  v=m.inverted()@d
  if all(Vector(n).dot(v)<=q+1e-5 for n,q in planes) and not any((v-p).length<1e-4 for p in verts):verts.append(v)
 faces=[]
 for normal,d in planes:
  normal=Vector(normal);indices=[i for i,v in enumerate(verts) if abs(normal.dot(v)-d)<1e-4]
  if len(indices)<3:continue
  center=sum((verts[i] for i in indices),Vector())/len(indices)
  ref=Vector((0,0,1)) if abs(normal.z)<.9 else Vector((0,1,0));u=normal.cross(ref).normalized();v=normal.cross(u).normalized()
  indices.sort(key=lambda i:math.atan2((verts[i]-center).dot(v),(verts[i]-center).dot(u)))
  faces.append(indices)
 return verts,faces
cubeplanes=[((x,y,z),.5)for x,y,z in [(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)]]
geometry={}
def shape(name,seed=0):
 key=name+str(seed)
 if key in geometry:return geometry[key]
 smooth=False
 if name in ['Bevel','Rock']:
  if name=='Bevel':planes=cubeplanes+[(Vector((x,y,z)).normalized(),.61)for x,y,z in itertools.product([-1,1],repeat=3)]
  else:
   planes=cubeplanes+[(Vector((math.cos(n*math.pi/4+seed*.13),.2*math.sin(n*2),math.sin(n*math.pi/4+seed*.13))).normalized(),.48)for n in range(8)]+[(Vector((.25,1,-.25)).normalized(),.42)]
  vs,fs=poly(planes)
 elif name in ['Taper','GentleTaper']:
  vs=[(x*s,y,z*s)for y,s in [(-.5,1),(.5,.86 if name=='GentleTaper' else .5)]for x,z in [(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]];fs=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
 elif name=='Crystal':
  vs=[(0,.5,0),(0,-.5,0),(-.5,0,-.5),(.5,0,-.5),(.5,0,.5),(-.5,0,.5)];fs=[(0,3,2),(0,4,3),(0,5,4),(0,2,5),(1,2,3),(1,3,4),(1,4,5),(1,5,2)]
 elif name=='Wedge':
  vs=[(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)];fs=[(0,1,3,2),(2,3,5,4),(0,4,5,1),(0,2,4),(1,5,3)]
 elif name=='Ball':
  vs=[(0,.5,0),(0,-.5,0)];fs=[];segments=16;rings=8
  for j in range(1,rings):
   a=j*math.pi/rings
   for n in range(segments):t=n*math.tau/segments;vs.append((math.cos(t)*math.sin(a)*.5,math.cos(a)*.5,math.sin(t)*math.sin(a)*.5))
  for n in range(segments):fs.append((0,2+(n+1)%segments,2+n));fs.append((1,2+(rings-2)*segments+n,2+(rings-2)*segments+(n+1)%segments))
  for j in range(rings-2):
   for n in range(segments):a=2+j*segments+n;b=2+j*segments+(n+1)%segments;fs.append((a,b,b+segments,a+segments))
  smooth=True
 elif name=='Cylinder':
  vs=[(x,math.cos(n*math.tau/24)*.5,math.sin(n*math.tau/24)*.5)for x in [-.5,.5]for n in range(24)]
  fs=[tuple(range(23,-1,-1)),tuple(range(24,48))]+[(n,(n+1)%24,(n+1)%24+24,n+24)for n in range(24)]
 else:vs,fs=poly(cubeplanes)
 geometry[key]=(vs,fs,smooth);return geometry[key]
materials={}
def material(h,glow=False,kind='',alpha=0,reflect=0):
 key=(h,glow,kind,alpha,reflect)
 if key in materials:return materials[key]
 m=bpy.data.materials.new(h+kind);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF')
 def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
 color=tuple(linear(int(h[k:k+2],16)/255)for k in (0,2,4))+(1,)
 b.inputs['Base Color'].default_value=color;b.inputs['Alpha'].default_value=1-alpha
 if alpha:b.inputs['Transmission Weight'].default_value=.12
 b.inputs['Roughness'].default_value=.65 if kind in ['Bark','Leaves'] else .45
 if glow:b.inputs['Emission Color'].default_value=color;b.inputs['Emission Strength'].default_value=.8
 if kind=='Metal':b.inputs['Metallic'].default_value=.65
 materials[key]=m;return m
# Merge authoring primitives by material, retaining genuine pointed-leaf geometry.
def build(name,parts):
 groups={}
 for p in parts:
  if p.get('Transparency',0)>=.98:continue
  if p.get('Prefab'):continue
  key=(p['Color'],p.get('Neon',False)or p.get('Material')=='Neon',p.get('Material',p.get('Group','')),p.get('Transparency',0),p.get('Reflectance',0))
  dest=groups.setdefault(key,{'v':[],'f':[],'smooth':[]});vs,fs,smooth=shape(p['Shape'],p.get('Seed',0))
  r=Matrix(p['Basis']).transposed()if p.get('Basis')else Matrix.Rotation(math.radians(p.get('Rotation',[0,0,0])[0]),3,'X')@Matrix.Rotation(math.radians(p.get('Rotation',[0,0,0])[1]),3,'Y')@Matrix.Rotation(math.radians(p.get('Rotation',[0,0,0])[2]),3,'Z')
  offset=len(dest['v']);pos=Vector(p['Position']);size=p['Size']
  dest['v'] += [T@(r@Vector([v[k]*size[k] for k in range(3)])+pos)for v in vs]
  dest['f'] += [tuple(i+offset for i in f)for f in fs];dest['smooth'] += [smooth]*len(fs)
 result=[]
 for key,d in groups.items():
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(d['v'],[],d['f']);mesh.materials.append(material(*key));mesh.update()
  for f,s in zip(mesh.polygons,d['smooth']):f.use_smooth=s
  ob=bpy.data.objects.new(name,mesh);result.append(ob)
 return result
cache={}
def model(id):
 if id not in cache:cache[id]=build(id,(env.get(id)or recipes[id])['Parts'])
 return cache[id]
def place(id,pos=(0,0,0),scale=1,yaw=0):
 objects=[]
 for src in model(id):
  o=src.copy();o.data=src.data;bpy.context.collection.objects.link(o);o.location=T@Vector(pos);o.scale=(scale,)*3;o.rotation_euler[2]=math.radians(yaw);objects.append(o)
 return objects
def clear():
 for o in list(bpy.context.scene.objects):bpy.data.objects.remove(o,do_unlink=True)
def light(pos,power,size,target=(0,0,10)):
 data=bpy.data.lights.new('Softbox','AREA');data.energy=power;data.shape='DISK';data.size=size;o=bpy.data.objects.new('Softbox',data);bpy.context.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
def render(name,objects,view=None,target=None,span=None):
 s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True;s.render.resolution_x=1400;s.render.resolution_y=1000;s.render.resolution_percentage=100
 s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.16,.22,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.65;s.view_settings.view_transform='AgX';s.render.image_settings.file_format='PNG'
 bpy.context.view_layer.update();points=[o.matrix_world@Vector(v)for o in objects for v in o.bound_box];lo=Vector([min(v[k]for v in points)for k in range(3)]);hi=Vector([max(v[k]for v in points)for k in range(3)])
 target=Vector(target)if target else (lo+hi)/2;span=span or max(hi-lo)
 light(target+Vector((span*.6,-span*.6,span)),span*span*26,span*.65,target);light(target+Vector((-span*.7,span*.2,span*.6)),span*span*17,span*.6,target)
 camera=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera'));bpy.context.collection.objects.link(camera);s.camera=camera
 camera.location=target+Vector(view or (.85,1.55,.7)).normalized()*span*2.5;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=span*1.68;camera.data.clip_end=30000
 s.render.filepath=str(OUT/name);bpy.ops.render.render(write_still=True);print('V9_RENDER',name,flush=True)

content=json.loads((P/'art/content-data.json').read_text());catalog=content['Catalog'];thumb=OUT/'catalog';thumb.mkdir(exist_ok=True)
ids=list(catalog['Monsters'])+list(catalog['Items'])
import os
selected=os.environ.get('V9_RENDER_IDS','')
if selected:ids=selected.split(',')
for index,id in enumerate(ids):
 clear();objects=place(id);bpy.context.view_layer.update()
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=18;scene.cycles.use_denoising=True
 scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
 scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.08,.12,.17,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6;scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
 points=[o.matrix_world@Vector(v)for o in objects for v in o.bound_box]
 lo=Vector([min(v[k]for v in points)for k in range(3)]);hi=Vector([max(v[k]for v in points)for k in range(3)]);target=(lo+hi)/2;span=max(hi-lo)
 light(target+Vector((span*.7,span*.4,span*.9)),span*span*22,span*.6,target);light(target+Vector((-span*.6,-span*.2,span*.5)),span*span*14,span*.6,target)
 camera=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera'));bpy.context.collection.objects.link(camera);scene.camera=camera
 direction=Vector((.65,1.6,.6)).normalized();camera.location=target+direction*span*2.5;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.clip_end=30000
 inv=camera.rotation_euler.to_matrix().transposed();projected=[inv@(v-target)for v in points]
 width=max(v.x for v in projected)-min(v.x for v in projected);height=max(v.y for v in projected)-min(v.y for v in projected)
 camera.data.ortho_scale=max(width,height)*1.18;scene.render.filepath=str(thumb/(id+'.png'));bpy.ops.render.render(write_still=True)
 print('V9_THUMB',index+1,len(ids),id,flush=True)
clear();objects=place('gale_wolf');render('v9-Gale-Wolf.png',objects)
clear();objects=place('sky_guard_sword',(-3,0,0))+place('sky_guard_helmet',(0,2,0))+place('sky_guard_armor',(3,0,0))+place('sky_guard_boots',(0,-2.3,0));render('v9-Sky-Equipment.png',objects)
