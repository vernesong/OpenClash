"""Run from repository root: python3 tests/oix_provider_sanitize_test.py.

Execute the production embedded Ruby transform using only temporary fixture files.
"""
import json
import re
import shutil
import stat
import subprocess
import tempfile
from pathlib import Path

module = Path('luci-app-openclash/luasrc/openclash_oix.lua').read_text()
match = re.search(r'local ruby = \[\[(.*?)\]\]', module, re.S)
assert match, 'embedded YAML transform was not found'
ruby = shutil.which('ruby')
assert ruby, 'Ruby with YAML support is required'
transform = match.group(1)
fixture = '''mixed-port: 7890
dns:
  enable: true
  nameserver: [https://dns.example.invalid/dns-query]
proxy-providers:
  oixCloud:
    type: http
    url: https://subscription.example.invalid/private-fixture
    path: ./proxy_provider/legacy
    interval: 3600
    header:
      Authorization: [Bearer fixture-only]
proxy-groups:
  - name: MAIN
    type: select
    use: [oixCloud]
rules: [MATCH,MAIN]
'''
count = 0
with tempfile.TemporaryDirectory(prefix='oix-yaml-test-') as directory:
    path = Path(directory) / 'fixture.yaml'
    path.touch(mode=0o600)
    path.write_text(fixture)
    result = subprocess.run([ruby, '-e', transform, str(path)], capture_output=True, text=True)
    assert result.returncode == 0, 'valid routing fixture was rejected'
    read = subprocess.run([ruby, '-ryaml', '-rjson', '-e', 'puts JSON.generate(YAML.load_file(ARGV[0]))', str(path)], capture_output=True, text=True, check=True)
    parsed = json.loads(read.stdout)
    assert parsed['proxy-providers']['oixCloud'] == {'type': 'file', 'path': './proxy_provider/oixCloud'}
    assert parsed['proxy-groups'][0]['use'] == ['oixCloud']
    assert parsed['mixed-port'] == 7890 and parsed['dns']['enable'] is True
    assert parsed['dns']['nameserver'] == ['https://dns.example.invalid/dns-query']
    assert 'subscription.example.invalid' not in path.read_text() and 'Authorization' not in path.read_text()
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    count += 1
    print('PASS real Ruby transform retains routing and removes ordinary provider credentials')
    invalid = {
        'non-mapping document': '- invalid\n',
        'missing managed provider': fixture.replace('  oixCloud:\n', '  other:\n'),
        'missing provider map': 'proxy-groups: [{name: MAIN, use: [oixCloud]}]\n',
        'missing groups': 'proxy-providers: {oixCloud: {type: http}}\n',
        'unreferenced managed provider': fixture.replace('use: [oixCloud]', 'use: [other]'),
        'malformed YAML': 'proxy-providers: [',
    }
    for name, source in invalid.items():
        path.write_text(source)
        result = subprocess.run([ruby, '-e', transform, str(path)], capture_output=True, text=True)
        assert result.returncode != 0, 'invalid fixture accepted: ' + name
        count += 1
        print('PASS rejects ' + name)
print(f'{count} real Ruby YAML cases passed')
