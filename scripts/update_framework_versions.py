#!/usr/bin/env python3
"""Select latest stable v1 tags; --check guards release publication, --update prepares a reviewable update."""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / 'src/azu_cli/templates/project/shard.yml.ecr'
RELEASE = re.compile(r'refs/tags/v?(1\.\d+\.\d+)$')


def latest(repo):
    output = subprocess.check_output(['git', 'ls-remote', '--tags', '--refs',
                                      f'https://github.com/azutoolkit/{repo}.git'], text=True, timeout=60)
    versions = [m.group(1) for line in output.splitlines() if (m := RELEASE.search(line))]
    if not versions:
        raise RuntimeError(f'No stable v1 tags found for {repo}')
    return max(versions, key=lambda v: tuple(map(int, v.split('.'))))


def replace_dependency(text, name, version):
    pattern = rf'(  {name}:\n    github: azutoolkit/{name}\n)    (?:version|commit|branch): [^\n]+\n'
    result, count = re.subn(pattern, lambda m: m[1] + f'    version: {version}\n', text)
    if count != 1:
        raise RuntimeError(f'Expected one {name} dependency declaration')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--update', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.update == args.check:
        parser.error('choose exactly one of --update or --check')
    versions = {name: latest(name) for name in ('azu', 'cql')}
    template = TEMPLATE.read_text()
    for name, version in versions.items():
        print(f'Latest stable {name}: {version}')
        if args.check:
            expected = rf'  {name}:\n    github: azutoolkit/{name}\n    version: {re.escape(version)}\n'
            if not re.search(expected, template):
                raise SystemExit(f'Release blocked: generated {name} must use tested stable {version}, not a canary or stale pin. Run the compatibility update workflow.')
        else:
            template = replace_dependency(template, name, version)
    if args.update:
        template = re.sub(r'  # Azu 1\.\d+\.\d+ plus.*?\n  azu:',
                          '  # Tested stable framework release; update through compatibility CI.\n  azu:', template, flags=re.S)
        TEMPLATE.write_text(template)
        manifest = ROOT / 'shard.yml'
        manifest.write_text(replace_dependency(manifest.read_text(), 'cql', versions['cql']))
    else:
        root_cql = re.search(r'  cql:\n    github: azutoolkit/cql\n    version: ([^\n]+)', (ROOT/'shard.yml').read_text())
        if not root_cql or root_cql[1] != versions['cql']:
            raise SystemExit('Release blocked: CLI and generated CQL versions differ')


if __name__ == '__main__':
    main()
