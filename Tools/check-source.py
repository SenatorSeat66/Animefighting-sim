"""Compile against installed Unity assemblies and run engine-independent combat tests.
This does not replace importing the project or running it inside Unity/Android.
"""
from pathlib import Path
import os, subprocess, tempfile
base=Path(os.environ['UNITY_EDITOR']).resolve().parent/'Data'
mono=base/'MonoBleedingEdge/bin/mono'
csc=base/'MonoBleedingEdge/lib/mono/4.5/csc.exe'
refs=list((base/'NetStandard/ref/2.1.0').glob('*.dll'))
refs+=list((base/'Managed/UnityEngine').glob('*.dll'))

with tempfile.TemporaryDirectory(prefix='shadow-check-') as tmp:
 args=[str(mono),str(csc),'-nologo','-nostdlib+','-target:library','-out:'+tmp+'/ShadowFighting.dll']
 args+=['-r:'+str(p) for p in refs]
 args+=[str(p) for p in Path('Assets').rglob('*.cs')]
 subprocess.run(args,check=True)
 subprocess.run([str(mono),str(csc),'-nologo','-out:'+tmp+'/CombatTests.exe','Assets/Scripts/Combat.cs','Tests/CombatTests.cs'],check=True)
 subprocess.run([str(mono),tmp+'/CombatTests.exe'],check=True)
