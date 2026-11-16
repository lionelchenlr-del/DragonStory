"""Rebuild the delivered place using persistent artwork and the portable Rojo project."""
from pathlib import Path
import shutil,subprocess
root=Path(__file__).resolve().parents[1]
required=['src/ReplicatedStorage/DragonShared/BakedArt.rbxmx','src/Workspace/SkyIslands.rbxmx']
missing=[name for name in required if not (root/name).is_file()]
if missing:raise SystemExit('Missing native assets: '+', '.join(missing)+'\nFrom the repository root run: python3 tools/restore_assets.py --download')
rojo=shutil.which('rojo')
if not rojo:raise SystemExit('Please install Rojo, then rerun this script.')
subprocess.run([rojo,'build',str(root/'default.project.json'),'-o',str(root/'DragonAwakening-Atelier-v9.rbxl')],check=True)
