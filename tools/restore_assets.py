#!/usr/bin/env python3
"""Restore only the three fixed, verified native assets from the v9 release ZIP."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import tempfile
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / 'game'
MANIFEST = GAME / 'assets-manifest.json'


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    choice = parser.add_mutually_exclusive_group(required=True)
    choice.add_argument('--archive', type=Path, help='Path to the original v9 release ZIP')
    choice.add_argument('--download', action='store_true', help='Download the fixed v9 ZIP from GitHub Releases')
    parser.add_argument('--force', action='store_true', help='Replace locally modified native assets; back them up first')
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    with tempfile.TemporaryDirectory(prefix='dragonstory-') as directory:
        temp = Path(directory)
        archive = args.archive.expanduser().resolve() if args.archive else temp / 'v9.zip'
        if args.download:
            print('Downloading:', manifest['archive']['url'], flush=True)
            request = urllib.request.Request(manifest['archive']['url'], headers={'User-Agent': 'DragonStory-Asset-Restore/1.0'})
            with urllib.request.urlopen(request, timeout=120) as response, archive.open('wb') as output:
                shutil.copyfileobj(response, output)
        expected = manifest['archive']
        if not archive.is_file():
            raise SystemExit(f'Archive not found: {archive}')
        print('Verifying release archive...', flush=True)
        if archive.stat().st_size != expected['bytes'] or digest(archive) != expected['sha256']:
            raise SystemExit('Archive verification failed. Use the original DragonAwakening-Atelier-v9.zip release asset.')

        verified = []
        with zipfile.ZipFile(archive) as source:
            # Extract by fixed manifest names, never extractall() or accept arbitrary paths.
            for index, record in enumerate(manifest['files']):
                relative = Path(record['path'])
                if relative.is_absolute() or '..' in relative.parts:
                    raise SystemExit('Invalid asset manifest path.')
                target = GAME / relative
                if target.exists():
                    if target.stat().st_size == record['bytes'] and digest(target) == record['sha256']:
                        print('Already verified:', record['path'])
                        continue
                    if not args.force:
                        raise SystemExit(f'Local asset differs: {target}\nBack it up, then pass --force to replace it.')
                staged = temp / f'asset-{index}'
                member = manifest['archive_root'] + '/' + relative.as_posix()
                with source.open(member) as entry, staged.open('wb') as output:
                    shutil.copyfileobj(entry, output)
                if staged.stat().st_size != record['bytes'] or digest(staged) != record['sha256']:
                    raise SystemExit(f'Asset verification failed: {relative}')
                verified.append((staged, target))
        # Verify all inputs before replacing any file. Final writes are atomic per file.
        for staged, target in verified:
            target.parent.mkdir(parents=True, exist_ok=True)
            descriptor, pending = tempfile.mkstemp(prefix='.restore-', dir=target.parent)
            try:
                with os.fdopen(descriptor, 'wb') as output, staged.open('rb') as source:
                    shutil.copyfileobj(source, output)
                os.replace(pending, target)
            finally:
                Path(pending).unlink(missing_ok=True)
            print('Restored:', target.relative_to(ROOT))
    print('Ready. Open game/DragonAwakening-Atelier-v9.rbxl, or rebuild after editing source.')


if __name__ == '__main__':
    main()
