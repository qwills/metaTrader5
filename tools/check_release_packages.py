#!/usr/bin/env python3
"""Check local release archives for example programs and development fixtures."""
import io
from pathlib import Path, PurePosixPath
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def forbidden(name):
    parts = PurePosixPath(name.replace('\\', '/')).parts
    base = parts[-1].lower() if parts else ''
    return (any(p.lower() in ('examples', 'samples', 'tests', 'fixtures', 'scripts') for p in parts)
            or ('example' in base or 'demo' in base or 'sample' in base)
            and base.endswith(('.mq5', '.mqh', '.ex5', '.mq4', '.ex4')))


def inspect_zip(data, label):
    with zipfile.ZipFile(data) as archive:
        if archive.testzip():
            raise ValueError(f'Corrupt ZIP: {label}')
        for name in archive.namelist():
            if forbidden(name):
                raise ValueError(f'Unwanted package entry: {label}: {name}')
            if name.lower().endswith('.zip'):
                inspect_zip(io.BytesIO(archive.read(name)), f'{label}!{name}')


def main():
    count = 0
    for folder in ('distribution', 'archive'):
        for path in sorted((ROOT/folder).rglob('*')):
            if path.suffix.lower() == '.zip':
                inspect_zip(path, path.relative_to(ROOT))
                count += 1
            elif path.name.endswith('.tar.gz'):
                with tarfile.open(path, 'r:gz') as archive:
                    for member in archive:
                        if forbidden(member.name):
                            raise ValueError(f'Unwanted archive entry: {path}: {member.name}')
                        if member.isfile() and member.name.lower().endswith('.zip'):
                            inspect_zip(io.BytesIO(archive.extractfile(member).read()), member.name)
                count += 1
    print(f'{count} local archives verified: no example programs, Scripts or test fixtures.')


if __name__ == '__main__':
    main()
