"""Original articulated silhouette cutouts, authored and rendered in Blender.
Run: blender -b --python Tools/create_art.py -- <repository-root>
"""
import bpy, math, sys, os, random
from mathutils import Vector
root=sys.argv[sys.argv.index('--')+1]
out=os.path.join(root,'Assets/Resources/Art'); os.makedirs(out,exist_ok=True)
scratch='/tmp/shadow-art'; os.makedirs(scratch,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=1
scene.render.resolution_x=512; scene.render.resolution_y=512; scene.render.resolution_percentage=100
scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'
scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
def mat(name,color):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 n=m.node_tree.nodes; n.clear(); e=n.new('ShaderNodeEmission'); e.inputs[0].default_value=(*color,1)
 o=n.new('ShaderNodeOutputMaterial'); m.node_tree.links.new(e.outputs[0],o.inputs[0]); return m
ink=mat('Obsidian cloth',(0.009,0.013,0.018)); edge=mat('Armor',(0.025,0.032,0.038)); scarf=mat('Cinnabar',(0.48,0.06,0.035)); steel=mat('Moonlit steel',(.58,.69,.65)); eye=mat('Eyes',(.95,.58,.23))
def poly(name,points,material,z=0,parent=None,origin=(0,0)):
 mesh=bpy.data.meshes.new(name); mesh.from_pydata([(x,y,z) for x,y in points],[],[list(range(len(points)))]); mesh.update()
 obj=bpy.data.objects.new(name,mesh); scene.collection.objects.link(obj); obj.data.materials.append(material)
 if parent: obj.parent=parent
 obj.location=(origin[0],origin[1],0); return obj
def pivot(name,x,y,parent=None):
 p=bpy.data.objects.new(name,None); scene.collection.objects.link(p); p.location=(x,y,0); p.parent=parent; return p
bpy.ops.object.camera_add(location=(0,1.45,15)); camera=bpy.context.object; camera.data.type='ORTHO'; camera.data.ortho_scale=4.4; scene.camera=camera
poses=[(0,0,-15,-55,8,-12),(15,-18,20,-30,-18,20),(-15,18,-25,-60,20,-18),(0,0,125,65,-10,15),(-12,10,-65,-45,10,-15),(0,0,45,20,10,-12),(40,-50,-60,-100,35,-45),(20,-10,-55,-75,-25,25),(-10,15,65,40,-5,10),(5,-5,-25,-10,0,0),(80,-60,-80,-70,65,-35),(0,0,75,15,10,-5)]
for variant in range(5):
 before=set(bpy.data.objects)
 body=pivot('fighter',0,0)
 if variant==1: body.scale=(1.18,1.03,1)
 if variant==2: body.scale=(.92,.98,1)
 poly('tunic',[(-.35,1.95),(-.27,2.12),(.24,2.12),(.34,1.94),(.23,1.25),(-.26,1.25)],ink,.01,body)
 poly('hakama',[(-.27,1.42),(.25,1.42),(.43,.67),(.14,.61),(.01,.79),(-.13,.61),(-.43,.67)],ink,.015,body)
 for i in range(5):
  x=-.28+i*.13; poly('skirt pleat',[(x,1.26),(x+.018,1.24),(x+.06,.72)],edge,.02,body)
 poly('belt',[(-.29,1.42),(.29,1.42),(.29,1.31),(-.29,1.31)],edge,.03,body)
 poly('mask',[(-.2,2.5),(-.15,2.66),(.12,2.68),(.24,2.52),(.2,2.27),(.06,2.17),(-.16,2.24)],ink,.02,body)
 poly('brow',[(.06,2.48),(.2,2.5),(.18,2.47),(.06,2.45)],eye,.04,body)
 if variant in (0,2):
  poly('woven hat',[(-.64,2.57),(0,2.9),(.65,2.57),(.52,2.52),(-.5,2.52)],ink,.06,body)
  poly('hat rim',[(-.54,2.56),(.56,2.56),(.47,2.54),(-.46,2.54)],edge,.07,body)
 else:
  for i in range(7):
   a=i*.4; x=-.23+i*.07; poly('crest',[(x,2.57),(x-.1,2.98-.07*abs(i-3)),(x+.12,2.72)],ink,.06,body)
 poly('scarf',[(-.18,2.27),(.18,2.28),(.25,2.17),(-.17,2.13),(-.67,2.2),(-1.02,2.4),(-.64,2.32)],scarf,.07,body)
 legs=[]; arms=[]
 for side in [-1,1]:
  leg=pivot('hip',side*.16,1.02,body); legs.append(leg)
  poly('trouser',[(-.12,0),(.12,0),(.1,-.48),(.04,-.59),(-.13,-.53)],ink,-.01,leg)
  shin=pivot('knee',0,-.48,leg)
  poly('shin',[(-.09,0),(.1,0),(.11,-.37),(.26,-.42),(.24,-.49),(-.12,-.49)],ink,0,shin)
  arm=pivot('shoulder',side*.28,1.98,body); arms.append(arm)
  poly('sleeve',[(-.13,.07),(.15,.05),(.17,-.3),(.1,-.46),(-.13,-.4)],ink,.03,arm)
  poly('vambrace',[(-.1,-.28),(.13,-.28),(.12,-.52),(-.08,-.54)],edge,.05,arm)
  fore=pivot('elbow',0,-.45,arm)
  poly('forearm',[(-.08,.04),(.1,.03),(.09,-.38),(.03,-.44),(-.09,-.39)],ink,.04,fore)
  arms.append(fore)
 weapon=arms[3]
 if variant==4:
  poly('spear shaft',[(-.028,-.3),(.028,-.3),(.028,1.9),(-.028,1.9)],edge,.09,weapon)
  poly('spear blade',[(0,2.35),(.11,1.87),(0,1.96),(-.1,1.87)],steel,.1,weapon)
 else:
  poly('katana',[(-.03,-.32),(.01,-.32),(.04,.65),(.15,1.23),(.09,1.13),(-.015,.6)],steel,.09,weapon)
  poly('tsuba',[(-.14,-.12),(.13,-.12),(.13,-.07),(-.14,-.07)],edge,.1,weapon)
 for i,angles in enumerate(poses):
  for o in [*legs,*arms]: o.rotation_euler.z=0
  legs[0].rotation_euler.z=math.radians(angles[0]); legs[1].rotation_euler.z=math.radians(angles[1])
  for j,a in enumerate(angles[2:]): arms[j].rotation_euler.z=math.radians(a)
  body.rotation_euler.z=math.radians(-75 if i==10 else 0)
  body.location.y=.28 if i==6 else 0
  scene.render.filepath=f'{scratch}/fighter-{variant}-{i:02}.png'; bpy.ops.render.render(write_still=True)
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root,f'Tools/fighter-{variant}.blend'))
 for obj in set(bpy.data.objects)-before: bpy.data.objects.remove(obj,do_unlink=True)
print('Original silhouette frames rendered to',scratch)
