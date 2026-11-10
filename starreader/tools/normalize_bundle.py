#!/usr/bin/env python3
"""Put the signed JAR manifest first for both JarFile and JarInputStream readers.

AGP can put META-INF/MANIFEST.MF after module entries. JAR signatures cover
entry contents, not ZIP order; preserve every entry and verify content identity
before atomically replacing the bundle. Run jarsigner -verify afterward.
"""

import argparse
import hashlib
import os
from pathlib import Path
import tempfile
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle', type=Path)
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    descriptor, temporary = tempfile.mkstemp(suffix='.aab', dir=bundle.parent)
    os.close(descriptor)
    try:
        with zipfile.ZipFile(bundle) as source:
            entries = source.infolist()
            names = [entry.filename for entry in entries]
            if len(names) != len(set(names)):
                raise ValueError('Duplicate bundle entries')
            if 'META-INF/MANIFEST.MF' not in names:
                raise ValueError('Bundle has no JAR manifest')
            if not any(name.startswith('META-INF/') and name.endswith(('.RSA', '.DSA', '.EC')) for name in names):
                raise ValueError('Bundle is not signed')
            entries.sort(key=lambda entry: (
                0 if entry.filename == 'META-INF/MANIFEST.MF' else
                1 if entry.filename.startswith('META-INF/') else 2,
                entry.filename,
            ))
            digests = {}
            with zipfile.ZipFile(temporary, 'w', allowZip64=True) as target:
                target.comment = source.comment
                for entry in entries:
                    data = source.read(entry)
                    digests[entry.filename] = hashlib.sha256(data).digest()
                    target.writestr(entry, data)
        with zipfile.ZipFile(temporary) as result:
            if result.namelist()[0] != 'META-INF/MANIFEST.MF':
                raise ValueError('Manifest ordering failed')
            if {name: hashlib.sha256(result.read(name)).digest() for name in result.namelist()} != digests:
                raise ValueError('Bundle contents changed')
        os.chmod(temporary, bundle.stat().st_mode & 0o777)
        os.replace(temporary, bundle)
        print(f'Normalized {len(digests)} bundle entries; all content SHA-256 values preserved.')
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    main()
