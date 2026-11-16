"""Run pure Luau rules and actual travel-service logic with small engine doubles."""
from pathlib import Path
import shutil,subprocess,sys
P=Path(__file__).resolve().parents[1]
exe=shutil.which('luau')
if not exe:raise SystemExit('Install the official Luau CLI, then run this script again.')
subprocess.run([exe,str(P/'tests/run.luau')],cwd=P,check=True)
template=(P/'tests/travel_harness.luau').read_text()
source=(P/'src/ServerScriptService/DragonServer/TravelService.luau').read_text()
generated=P/'tests/.travel-run.luau'
try:
 generated.write_text(template.replace('-- TRAVEL_SOURCE',source))
 subprocess.run([exe,str(generated)],cwd=P,check=True)
finally:
 generated.unlink(missing_ok=True)
