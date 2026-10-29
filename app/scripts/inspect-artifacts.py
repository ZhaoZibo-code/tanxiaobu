"""Inspect the actual M00 HAPs; this is artifact inspection, not an ArkTS test."""
import hashlib
import json
from pathlib import Path
import zipfile

app = Path(__file__).resolve().parents[1]
for target, module in [('default', 'entry'), ('ohosTest', 'entry_test')]:
    hap = app / f'entry/build/default/outputs/{target}/entry-{target}-unsigned.hap'
    with zipfile.ZipFile(hap) as archive:
        manifest = json.loads(archive.read('module.json'))
        assert manifest['app']['compileSdkType'] == 'OpenHarmony'
        assert manifest['app']['compileSdkVersion'] == '5.0.0.71'
        assert manifest['app']['minAPIVersion'] == 12
        assert manifest['app']['targetAPIVersion'] == 12
        assert manifest['app']['bundleName'] == 'com.carbonfootprint.app'
        assert manifest['module']['name'] == module
        abc_size = len(archive.read('ets/modules.abc'))
        assert abc_size > 0
    print(hap)
    print(f'SHA-256: {hashlib.sha256(hap.read_bytes()).hexdigest()}')
    print(f'bytes: {hap.stat().st_size}')
    print(f'bundle: com.carbonfootprint.app; module: {module}; SDK: OpenHarmony 5.0.0.71; min/target API: 12/12')
    print(f'ets/modules.abc bytes: {abc_size}')
    print('Signing: unsigned; runtime validation is recorded separately.\n')
