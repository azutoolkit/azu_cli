#!/usr/bin/env python3
import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('versions', Path(__file__).with_name('update_framework_versions.py'))
versions = importlib.util.module_from_spec(spec)
spec.loader.exec_module(versions)


class VersionGateTests(unittest.TestCase):
    def test_only_stable_v1_tags_are_selected(self):
        tags = '\n'.join('hash\trefs/tags/'+tag for tag in ['v1.0.1','v1.10.0','v1.9.0','v1.11.0-rc1','v2.0.0','v0.99.0'])
        with patch.object(versions.subprocess, 'check_output', return_value=tags):
            self.assertEqual(versions.latest('azu'), '1.10.0')

    def test_duplicate_declarations_are_rejected(self):
        entry = '  azu:\n    github: azutoolkit/azu\n    version: 1.0.0\n'
        with self.assertRaises(RuntimeError):
            versions.replace_dependency(entry+entry, 'azu', '1.0.1')

    def test_canary_blocks_release_and_update_aligns_cli_and_app(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            template = root/'project.yml'
            template.write_text('dependencies:\n  azu:\n    github: azutoolkit/azu\n    commit: abc123\n  cql:\n    github: azutoolkit/cql\n    version: 0.0.604\n')
            (root/'shard.yml').write_text('dependencies:\n  cql:\n    github: azutoolkit/cql\n    version: 0.0.604\n')
            with patch.object(versions, 'ROOT', root), patch.object(versions, 'TEMPLATE', template), patch.object(versions, 'latest', return_value='1.0.2'), contextlib.redirect_stdout(io.StringIO()):
                with patch.object(sys, 'argv', ['versions', '--check']), self.assertRaises(SystemExit):
                    versions.main()
                with patch.object(sys, 'argv', ['versions', '--update']):
                    versions.main()
                self.assertNotIn('commit:', template.read_text())
                self.assertIn('version: 1.0.2', (root/'shard.yml').read_text())
                with patch.object(sys, 'argv', ['versions', '--check']):
                    versions.main()


if __name__ == '__main__':
    unittest.main()
