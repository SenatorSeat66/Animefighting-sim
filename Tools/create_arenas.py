"""Original layered landscape art, rendered by Blender (no downloaded asset packs)."""
import bpy,math,random,sys,os
root=sys.argv[sys.argv.index('--')+1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=1
s.render.resolution_x=2560;s.render.resolution_y=1440;s.render.resolution_percentage=100
s.view_settings.view_transform='Standard';s.render.image_settings.file_format='PNG'
def material(name,c):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(*c,1);o=n.new('ShaderNodeOutputMaterial');m.node_tree.links.new(e.outputs[0],o.inputs[0]);return m
def poly(name,pts,mat,z):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([(x,y,z) for x,y in pts],[],[list(range(len(pts)))]);mesh.update();o=bpy.data.objects.new(name,mesh);s.collection.objects.link(o);o.data.materials.append(mat);return o
def rect(x,y,w,h,m,z):return poly('beam',[(x,y),(x+w,y),(x+w,y+h),(x,y+h)],m,z)
def branch(x,y,angle,length,width,m,z,depth):
 nx=x+math.cos(angle)*length;ny=y+math.sin(angle)*length
 ox=math.sin(angle)*width;oy=-math.cos(angle)*width
 poly('pine limb',[(x-ox,y-oy),(x+ox,y+oy),(nx+ox*.3,ny+oy*.3),(nx-ox*.3,ny-oy*.3)],m,z)
 if depth>0:
  branch(nx,ny,angle+.45,length*.7,width*.65,m,z,depth-1);branch(nx,ny,angle-.55,length*.65,width*.6,m,z,depth-1)
 else:
  for j in range(3):
   poly('pine foliage',[(nx-.8+j*.2,ny-.2),(nx-.1,ny+.3),(nx+.8-j*.15,ny-.18)],m,z+.001)
bpy.ops.object.camera_add(location=(0,0,20));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=20;s.camera=cam
palettes=[((.49,.34,.23),(.82,.57,.3),(.22,.23,.23)),((.15,.23,.28),(.5,.62,.6),(.1,.16,.19)),((.21,.25,.19),(.62,.65,.43),(.11,.15,.12)),((.36,.22,.23),(.85,.48,.31),(.16,.14,.18))]
for v,(sky,light,dark) in enumerate(palettes):
 random.seed(114+v);before=set(bpy.data.objects)
 back=material('haze',sky);sun=material('sun',light);near=material('foreground',(.025,.032,.035))
 rect(-12,-7,24,14,back,-8)
 # Horizontal atmospheric layers, blended through closely spaced bands.
 for band in range(90):
  t=band/90; c=tuple(sky[i]*(1-t*.45)+light[i]*t*.45 for i in range(3));rect(-12,5.625-band*.125,24,.14,material('atmosphere',c),-7.9)
 poly('sun disk',[(-4+math.cos(i*math.tau/128)*1.16,2.3+math.sin(i*math.tau/128)*1.16) for i in range(128)],sun,-7.5)
 for layer in range(4):
  c=tuple(sky[i]*(1-(layer+1)*.18)+dark[i]*(layer+1)*.18 for i in range(3));m=material('ridge',c)
  points=[(-12,-5)]
  for i in range(45):
   x=-12+i*.55; y=math.sin(i*.43+layer)*.7+random.uniform(-.2,.25)+.8-layer*.7;points.append((x,y))
  points.append((13,-5));poly('mountain ridge',points,m,-7+layer*.4)
 # Distant rooflines with curved tips and many roof tiles.
 architecture=material('temple stone',tuple(c*.75 for c in dark))
 for tower in range(5):
  x=-8+tower*3.8;base=-1.8;levels=2+(tower%2)
  for level in range(levels):
   y=base+level*.65;w=1.5-level*.24
   rect(x-w*.62,y,w*1.24,.5,architecture,-3)
   poly('curved roof',[(x-w,y+.5),(x-w*1.2,y+.78),(x-w*.5,y+.64),(x,y+.96),(x+w*.5,y+.64),(x+w*1.2,y+.78),(x+w,y+.5)],architecture,-2.9)
   for tile in range(12):rect(x-w+tile*w/6,y+.5,.018,.08,near,-2.8)
  for window in range(3):rect(x-.5+window*.4,base+.13,.12,.22,sun,-2.7)
 # Stage and ceremonial gate.
 rect(-12,-5.625,24,3.1,near,0)
 for x in [-7.7,7.7]:
  rect(x-.13,-2.6,.26,5.4,near,1)
  for i in range(5):rect(x-.24,-2.3+i*1.04,.48,.08,architecture,1.1)
 poly('gate lintel',[(-8.7,2.7),(-8.9,3.14),(-7,2.96),(7,2.96),(8.9,3.14),(8.7,2.7)],near,1.2)
 rect(-8.3,2.16,16.6,.18,near,1.1)
 for x in [-8.6,8.6]: branch(x,-2.5,math.pi*.5,1.6,.16,near,2,4)
 # Stone seams, grass tufts, drifting petals.
 for i in range(35):
  x=random.uniform(-10,10);y=random.uniform(-5.6,-2.7);rect(x,y,random.uniform(.3,1),.012,architecture,1)
 for i in range(150):
  x=random.uniform(-10,10);y=-2.55;h=random.uniform(.07,.28)
  poly('grass',[(x,y),(x+.025,y+h),(x+.08,y)],near,2)
 for i in range(55):
  x=random.uniform(-10,10);y=random.uniform(-2,4);poly('petal',[(x,y),(x+.035,y+.02),(x+.09,y),(x+.025,y-.02)],sun,2)
 s.render.filepath=os.path.join(root,f'Assets/Resources/Art/arena-{v}.png');bpy.ops.render.render(write_still=True)
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root,f'Tools/arena-{v}.blend'))
 for o in set(bpy.data.objects)-before:bpy.data.objects.remove(o,do_unlink=True)
