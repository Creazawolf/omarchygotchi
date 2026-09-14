#!/usr/bin/env python3
"""Render real components with explicitly synthetic test profiles in a private HOME."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

project=Path(__file__).resolve().parents[1]
output=Path(sys.argv[1] if len(sys.argv)>1 else '/tmp/tamagotchi-visual-check').resolve()
output.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='tamagotchi-qml-') as temporary:
    temp=Path(temporary)
    env=dict(os.environ,TAMA_QML_FIXTURE=str(temp/'fixture.json'))
    subprocess.run(['npm','test'],cwd=project/'cloudflare',env=env,check=True)
    for name in ['Commons','Ui','services']:
        (temp/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (temp/'plugin').symlink_to(project)
    shutil.copy(Path(__file__).parent/'qml/smoke.qml',temp/'shell.qml')
    (temp/'home/.local/state/omarchy/tamagotchi-community').mkdir(parents=True)
    env.update(HOME=str(temp/'home'),TAMA_FIXTURE=str(temp/'fixture.json'),TAMA_OUTPUT=str(output))
    result=subprocess.run(['quickshell','--path',str(temp/'shell.qml'),'--no-color'],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=20)
    print(result.stdout)
    if result.returncode or 'EXPORT_SAVED true' not in result.stdout or 'FAMILY_SAVED true' not in result.stdout or 'VISITOR_LIFECYCLE_OK' not in result.stdout or any(s in result.stdout for s in ['ERROR:', 'WARN scene:', 'ReferenceError:', 'TypeError:']):
        raise SystemExit('QML runtime or scene export failed.')
print('Verified visit and family PNG exports in '+str(output))
